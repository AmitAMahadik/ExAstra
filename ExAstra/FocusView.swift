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
                            title: area.rawValue,
                            isSelected: state.focusArea == area
                        )
                        .onTapGesture { state.focusArea = area }
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

private struct FocusCard: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(isSelected ? "Selected" : "Tap to select")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.blue.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }
}