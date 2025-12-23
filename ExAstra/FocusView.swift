//
//  FocusView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

// FocusView.swift
import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose your focus")
                    .font(.title2).bold()
                    .padding(.top, 12)

                Text("This helps tailor the guidance and the questions you ask.")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FocusArea.allCases) { area in
                        FocusCard(
                            area: area,
                            isSelected: state.focusArea == area
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                state.focusArea = area
                            }
                        }
                    }
                }
                .padding(.top, 8)

                NavigationLink {
                    ChatView()
                } label: {
                    Text("Start Chat")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(state.focusArea == nil ? Color.gray.opacity(0.25) : Color.blue.opacity(0.9))
                        .foregroundStyle(state.focusArea == nil ? .gray : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(state.focusArea == nil)
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
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

