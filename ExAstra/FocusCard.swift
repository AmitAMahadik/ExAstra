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

    private var iconName: String {
        switch area {
        case .career: return "focus_career"
        case .relationships: return "focus_relationships"
        case .wealth: return "focus_finances"
        case .health: return "focus_health"
        }
    }

    var body: some View {
        VStack {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 6 : 2)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.14) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.blue.opacity(0.75) : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        .accessibilityLabel(Text(area.rawValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

