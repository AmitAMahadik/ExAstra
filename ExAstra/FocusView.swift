//
//  FocusView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import SwiftOpenAI
import Combine
import UIKit

struct FocusView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = FocusSummaryViewModel()
    @Namespace private var cardNamespace
    @State private var expandedArea: FocusArea? = nil
    @State private var isExpandedFlipped: Bool = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("The Week Ahead")
                    .font(.title2).bold()
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FocusArea.allCases) { area in
                        ZStack {
                            FocusCard(
                                area: area,
                                isSelected: state.focusArea == area,
                                isFlipped: false,
                                backText: vm.haikuText(for: area),
                                isExpanded: false
                            )
                            .matchedGeometryEffect(
                                id: area.rawValue,
                                in: cardNamespace,
                                isSource: expandedArea != area
                            )
                            .opacity(expandedArea == area ? 0 : 1)
                        }
                        .onTapGesture {
                            lightHaptic()
                            if expandedArea == area {
                                collapseExpanded()
                            } else {
                                withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.92, blendDuration: 0.15)) {
                                    expand(area)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }

            if let expanded = expandedArea {
                Color.black
                    .opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        lightHaptic()
                        collapseExpanded()
                    }

                GeometryReader { geo in
                    FocusCard(
                        area: expanded,
                        isSelected: true,
                        isFlipped: isExpandedFlipped,
                        backText: vm.haikuText(for: expanded),
                        isExpanded: true
                    )
                    .matchedGeometryEffect(
                        id: expanded.rawValue,
                        in: cardNamespace,
                        isSource: true
                    )
                    .frame(
                        width: geo.size.width - 36,
                        height: geo.size.height * 0.70
                    )
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .zIndex(10)
                    .onTapGesture {
                        lightHaptic()
                        collapseExpanded()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onChange(of: state.focusArea) { _, newValue in
            guard let area = newValue else { return }
            vm.requestWeeklySummary(
                profile: state.profileSummary(),
                focusArea: area,
                lunarSign: state.lunarSignDeterministic,
                solarSign: state.solarSign,
                chineseSign: state.chineseSign
            )
        }
        .onChange(of: state.focusArea) { _, newValue in
            if newValue == nil {
                collapseExpanded()
            }
        }
    }

    private func expand(_ area: FocusArea) {
        state.focusArea = area
        expandedArea = area
        isExpandedFlipped = false

        Task { @MainActor in
            // Small delay so the matched-geometry expansion reads as a tap before the flip.
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                isExpandedFlipped = true
            }
        }
    }

    private func collapseExpanded() {
        // Flip back first, then collapse.
        withAnimation(.easeInOut(duration: 0.22)) {
            isExpandedFlipped = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.92, blendDuration: 0.15)) {
                expandedArea = nil
            }
        }
    }
    
    private func lightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct FocusSummaryCard: View {
    let selected: FocusArea?
    let summary: String?
    let isLoading: Bool
    let errorText: String?

    private var title: String {
        selected?.rawValue ?? "Select a focus area"
    }

    private var defaultSubtitle: String {
        "Pick one of the focus areas above to tailor your weekly predictions."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(defaultSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@MainActor
final class FocusSummaryViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var summaryText: String? = nil
    @Published var errorText: String? = nil
    @Published private(set) var currentArea: FocusArea? = nil

    private let service: OpenAIService

    private var cache: [FocusArea: String] = [:]
    private var inFlightTask: Task<Void, Never>? = nil

    private struct PendingRequest: Equatable {
        let profile: String
        let focusArea: FocusArea
        let lunarSign: String
        let solarSign: String
        let chineseSign: String
    }

    private let requestSubject = PassthroughSubject<PendingRequest, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init() {
        let key = Bundle.main.object(
            forInfoDictionaryKey: "OPENAI_API_KEY"
        ) as? String

        print("API Key exists:", !(key ?? "").isEmpty)

        guard let apiKey = key, !apiKey.isEmpty else {
            fatalError("❌ OPENAI_API_KEY missing. Check Secrets.xcconfig + Info.plist")
        }

        self.service = OpenAIServiceFactory.service(apiKey: apiKey)

        requestSubject
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] req in
                self?.runWeeklySummaryRequest(req)
            }
            .store(in: &cancellables)
    }

    func requestWeeklySummary(profile: String, focusArea: FocusArea, lunarSign: String, solarSign: String, chineseSign: String) {
        currentArea = focusArea
        if let cached = cache[focusArea], !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Cached → show immediately
            summaryText = cached
            errorText = nil
            isLoading = false
        } else {
            // Not cached → clear summary card while loading
            summaryText = nil
            errorText = nil
            isLoading = true
        }

        // Enqueue a debounced request
        requestSubject.send(.init(profile: profile, focusArea: focusArea, lunarSign: lunarSign, solarSign: solarSign, chineseSign: chineseSign))
    }

    func haikuText(for area: FocusArea) -> String {
        if area == currentArea {
            if isLoading { return "Loading…" }
            if let errorText, !errorText.isEmpty { return "Unable to load" }
            let t = (summaryText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "—" : t
        }
        let cached = (cache[area] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cached.isEmpty ? "—" : cached
    }

    private func runWeeklySummaryRequest(_ req: PendingRequest) {
        // If we already have cached content, we can skip a refresh when the user is tapping quickly.
        // However, if you want to always refresh, remove this early return.
        if let cached = cache[req.focusArea], !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summaryText = cached
            errorText = nil
            isLoading = false
            return
        }

        // Cancel any in-flight work
        inFlightTask?.cancel()

        isLoading = true
        errorText = nil
        summaryText = summaryText ?? cache[req.focusArea]

        inFlightTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if !Task.isCancelled {
                    self.isLoading = false
                }
            }

            print("Running weekly summary request for \(req.focusArea.rawValue)")
            print("Profile details: \(req.profile)")

            let system = """
            You are an astrologer assistant blending Western, Vedic, and Chinese astrology. Provide a short, practical weekly outlook based on the Lunar, Sun, and chinese signs provided.
            Requirements:
            - Return 3–5 short lines (not long paragraphs).
            - Keep it grounded and actionable (focus on themes, timing, and suggestions).
            - Do not ask questions.
            - Do not include disclaimers.
            - Do not mention that you are an AI.
            """

            let user = """
            Create a concise prediction, in the form of a haiku, for the next 7 days focused on: \(req.focusArea.rawValue).

            Signs:
            - Lunar (Ephemeris): \(req.lunarSign)
            - Sun: \(req.solarSign)
            - Chinese: \(req.chineseSign)

            Profile details:
            \(req.profile)

            Output format:
            - Line 1: Overall theme
            - Lines 2–4: Specific guidance for this week in the form of a haiku
            - Line 5: Specific one-liner guidance on what to do this week
            - Line 6: Specific one-liner guidance on what to avoid this week
            """

            do {
                let params = ChatCompletionParameters(
                    messages: [
                        .init(role: .system, content: .text(system)),
                        .init(role: .user, content: .text(user))
                    ],
                    model: .gpt4turbo
                )

                // Stream response
                self.summaryText = ""

                let stream = try await self.service.startStreamedChat(parameters: params)
                var lastUIUpdateTime = Date.distantPast
                var buffer = ""

                for try await chunk in stream {
                    if Task.isCancelled { return }

                    let delta = chunk.choices?.first?.delta?.content ?? ""
                    guard !delta.isEmpty else { continue }

                    buffer += delta

                    // Throttle UI updates to ~20 fps (every 50ms)
                    if Date().timeIntervalSince(lastUIUpdateTime) > 0.05 {
                        self.summaryText = (self.summaryText ?? "") + buffer
                        buffer.removeAll(keepingCapacity: true)
                        lastUIUpdateTime = Date()
                    }
                }

                // Flush any remaining buffered text
                if !buffer.isEmpty {
                    self.summaryText = (self.summaryText ?? "") + buffer
                }

                if Task.isCancelled { return }

                let finalText = (self.summaryText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if finalText.isEmpty {
                    self.summaryText = "No summary returned."
                } else {
                    self.summaryText = finalText
                    self.cache[req.focusArea] = finalText
                }
            } catch {
                if Task.isCancelled { return }

                if let apiError = error as? APIError {
                    switch apiError {
                    case .responseUnsuccessful(let description, let statusCode):
                        self.errorText = "Request failed (\(statusCode)): \(description)"
                    default:
                        self.errorText = error.localizedDescription
                    }
                } else {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    deinit {
        inFlightTask?.cancel()
    }
}

#Preview("FocusView – Empty") {
    NavigationStack {
        FocusView()
            .environmentObject(AppState())
    }
}

#Preview("FocusView – With Selection") {
    let state = AppState()
    state.focusArea = .health
    return NavigationStack {
        FocusView()
            .environmentObject(state)
    }
}
