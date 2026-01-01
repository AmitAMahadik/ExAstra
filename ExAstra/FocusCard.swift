//
//  FocusCard.swift
//  ExAstra
//
//  Created by Assistant on 12/23/25.
//

import SwiftUI
import Combine

struct FocusCard: View {
    let area: FocusArea
    let isSelected: Bool
    let isFlipped: Bool
    let backText: String
    let isExpanded: Bool

    @State private var streamedBackText: String = ""
    @State private var hasStreamedBackText: Bool = false
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var ellipsisPhase: Int = 0
    private let ellipsisTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    init(
        area: FocusArea,
        isSelected: Bool,
        isFlipped: Bool = false,
        backText: String = "—",
        isExpanded: Bool = false
    ) {
        self.area = area
        self.isSelected = isSelected
        self.isFlipped = isFlipped
        self.backText = backText
        self.isExpanded = isExpanded
    }

    private func resetStreamingState() {
        streamTask?.cancel()
        streamTask = nil
        streamedBackText = ""
        hasStreamedBackText = false
    }

    private func startStreamingIfNeeded() {
        guard isFlipped else { return }

        // If we've already streamed once for this backText, show it immediately.
        if hasStreamedBackText {
            streamedBackText = backText
            return
        }

        // Cancel any prior stream and start a new one.
        streamTask?.cancel()
        streamedBackText = ""

        let fullText = backText
        streamTask = Task {
            // Small initial delay so the flip completes before typing begins.
            try? await Task.sleep(nanoseconds: 120_000_000)

            for ch in fullText {
                if Task.isCancelled { return }
                await MainActor.run {
                    streamedBackText.append(ch)
                }
                // Typing speed (tweak as desired)
                try? await Task.sleep(nanoseconds: 18_000_000)
            }

            await MainActor.run {
                hasStreamedBackText = true
                streamedBackText = fullText
            }
        }
    }

    private var animatedEllipsis: String {
        guard ellipsisPhase > 0 else { return "" }
        return " " + String(repeating: "·", count: ellipsisPhase) // " ·", " ··", " ···"
    }

    private var isWaitingPlaceholder: Bool {
        let normalized = backText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
        return normalized.hasPrefix("reaching for the stars")
    }

    private var visibleBackText: String {
        if isWaitingPlaceholder {
            return "Reaching for the stars" + animatedEllipsis
        }
        return hasStreamedBackText ? backText : streamedBackText
    }

    private var iconName: String {
        switch area {
        case .purpose: return "focus_purpose"
        case .career: return "focus_career"
        case .relationships: return "focus_relationships"
        case .wealth: return "focus_finances"
        case .health: return "focus_health"
        case .travel: return "focus_travel"
        case .education: return "focus_education"
        }
    }
    private struct CardChrome: ViewModifier {
        let isSelected: Bool

        func body(content: Content) -> some View {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

            return content
                .background(
                    ZStack {
                        // Base: deep, slightly translucent card surface
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.40),
                                Color.black.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(shape)

                        // Soft “glass” sheen
                        shape
                            .fill(.ultraThinMaterial)
                            .opacity(0.18)
                    }
                )
                .clipShape(shape)
                // Subtle border for all cards
                .overlay(
                    shape.stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                // Selected: sleek glow ring + slight lift (no chunky stroke)
                .overlay(
                    Group {
                        if isSelected {
                            shape
                                .stroke(Color.accentColor.opacity(0.95), lineWidth: 2)
                                .shadow(color: Color.accentColor.opacity(0.55), radius: 14, x: 0, y: 0)
                                .shadow(color: Color.accentColor.opacity(0.35), radius: 28, x: 0, y: 0)
                                .transition(.opacity)
                        }
                    }
                )
                // Halo-only selection: no scale, just a gentle lift via shadow
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.70 : 0.55),
                    radius: isSelected ? 22 : 18,
                    x: 0,
                    y: isSelected ? 14 : 10
                )
                .shadow(
                    color: Color.black.opacity(isSelected ? 0.42 : 0.35),
                    radius: isSelected ? 8 : 6,
                    x: 0,
                    y: isSelected ? 4 : 3
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSelected)
        }
    }
    var body: some View {
        ZStack {
            frontFace
                .opacity(isFlipped ? 0.0 : 1.0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            backFace
                .opacity(isFlipped ? 1.0 : 0.0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isFlipped)
        .onAppear {
            // If we appear already flipped, handle it.
            if isFlipped {
                startStreamingIfNeeded()
            }
        }
        .onReceive(ellipsisTimer) { _ in
            guard isFlipped, isWaitingPlaceholder else {
                ellipsisPhase = 0
                return
            }
            ellipsisPhase = (ellipsisPhase % 3) + 1 // cycles 1,2,3 -> "·", "··", "···"
        }
        .onChange(of: isFlipped) { _, newValue in
            if newValue {
                startStreamingIfNeeded()
            }
        }
        .onChange(of: backText) { _, _ in
            // New content should re-stream on next flip.
            resetStreamingState()
            if isFlipped {
                startStreamingIfNeeded()
            }
        }
        .onDisappear {
            streamTask?.cancel()
            streamTask = nil
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityLabel(Text(area.rawValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var frontFace: some View {
        Group {
            if isExpanded {
                VStack(spacing: 16) {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)

                    Text(area.rawValue)
                        .font(.title2).bold()
                        .foregroundStyle(.primary)

                    Text("Tap to reveal your haiku")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .padding(12)
            }
        }
        .modifier(CardChrome(isSelected: isSelected))
    }

    private var backFace: some View {
        Group {
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                            .padding(.top, 8)
                            .opacity(isFlipped ? 1.0 : 0.0)
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 0)
                            .animation(
                                .easeOut(duration: 0.35).delay(0.15),
                                value: isFlipped
                            )

                        Spacer()
                    }
                    .padding(.top, 8)

                    Text(visibleBackText)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.20), value: ellipsisPhase)

                    Spacer(minLength: 0)

                    Text("Tap again to close")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(area.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(visibleBackText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut(duration: 0.20), value: ellipsisPhase)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(width: 96, height: 96)
            }
        }
        .modifier(CardChrome(isSelected: isSelected))
    }
}

#Preview("FocusCard – Compact") {
    VStack {
        FocusCard(area: .health, isSelected: true, isFlipped: false, backText: "—", isExpanded: false)
        FocusCard(area: .travel, isSelected: false, isFlipped: true, backText: "A short haiku appears here.", isExpanded: false)
    }
    .padding()
}

#Preview("FocusCard – Expanded Back") {
    FocusCard(area: .career, isSelected: true, isFlipped: true, backText: "Overall theme\n\nHaiku line 1\nHaiku line 2\nHaiku line 3\n\nDo: ...\nAvoid: ...", isExpanded: true)
        .padding()
}
