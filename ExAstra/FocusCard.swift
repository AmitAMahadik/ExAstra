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
        case .travel: return "focus_travel"
        case .education: return "focus_education"
        }
    }
    
    var body: some View {
        Image(iconName)
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.06 : 1.0)
           /* .shadow(
                color: .black.opacity(isSelected ? 0.18 : 0.0),
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 6 : 0
            )*/
            .contentShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .animation(
                .spring(response: 0.30, dampingFraction: 0.75),
                value: isSelected
            )
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
