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

    private var gridColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var gridAreas: [FocusArea] {
        FocusArea.allCases.filter { $0 != .purpose }
    }

    @ViewBuilder
    private func focusCardCell(_ area: FocusArea) -> some View {
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

    private var purposeTopCard: some View {
        HStack {
            Spacer()
            focusCardCell(.purpose)
                .frame(maxWidth: 220) // keep visual balance above grid
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var focusGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(gridAreas) { area in
                focusCardCell(area)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                purposeTopCard
                focusGrid
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

    private var service: OpenAIService?

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

        if let apiKey = key, !apiKey.isEmpty {
            self.service = OpenAIServiceFactory.service(apiKey: apiKey)
        } else if let stored = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !stored.isEmpty {
            self.service = OpenAIServiceFactory.service(apiKey: stored)
        } else {
            // No API key available; run in degraded mode.
            self.service = nil
            print("Warning: OPENAI_API_KEY not set — AI features disabled for this build.")
        }

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
            if isLoading { return "Reaching for the stars…" }
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

            let system = FocusViewPrompts.system

            let user = FocusViewPrompts.user(
                focusArea: req.focusArea.rawValue,
                lunarSign: req.lunarSign,
                solarSign: req.solarSign,
                chineseSign: req.chineseSign,
                profile: req.profile
            )

            do {
                let params = ChatCompletionParameters(
                    messages: [
                        .init(role: .system, content: .text(system)),
                        .init(role: .user, content: .text(user))
                    ],
                    model: .gpt4turbo
                )

                // Ensure service is present (runtime key may be stored in UserDefaults)
                self.ensureService()
                guard let service = self.service else {
                    if !Task.isCancelled {
                        self.errorText = "AI features are disabled for this build. No API key configured."
                        self.isLoading = false
                    }
                    return
                }

                let stream = try await service.startStreamedChat(parameters: params)
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

    private func ensureService() {
        if service != nil { return }
        if let apiKey = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !apiKey.isEmpty {
            service = OpenAIServiceFactory.service(apiKey: apiKey)
            return
        }
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !bundleKey.isEmpty {
            service = OpenAIServiceFactory.service(apiKey: bundleKey)
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
