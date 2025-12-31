//
//  FocusCard.swift
//  ExAstra
//
//  Created by Assistant on 12/23/25.
//

import SwiftUI

struct FocusCard: View {
    let area: FocusArea
    let isSelected: Bool
    let isFlipped: Bool
    let backText: String
    let isExpanded: Bool

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

    private var iconName: String {
        switch area {
        case .career: return "focus_career"
        case .relationships: return "focus_relationships"
        case .wealth: return "focus_finances"
        case .health: return "focus_health"
        case .travel: return "focus_travel"
        case .education: return "focus_education"
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(
            .spring(response: 0.30, dampingFraction: 0.75),
            value: isSelected
        )
    }

    private var backFace: some View {
        Group {
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(area.rawValue)
                            .font(.title2).bold()
                        Spacer()
                        Text("Haiku")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(backText)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

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

                    Text(backText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(width: 96, height: 96)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(
            .spring(response: 0.30, dampingFraction: 0.75),
            value: isSelected
        )
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
