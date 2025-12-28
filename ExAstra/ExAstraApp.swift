//
//  ExAstraApp.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import UIKit

enum AppTab: Hashable {
    case profile
    case focus
    case chat
}

@main
struct ExAstraApp: App {
    @StateObject private var state = AppState()
    @State private var selectedTab: AppTab = .profile

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)

                NavigationStack {
                    FocusView()
                }
                .tabItem {
                    Label("Focus", systemImage: "sparkles")
                }
                .tag(AppTab.focus)

                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(AppTab.chat)
            }
            .environmentObject(state)
            .onAppear {
                selectedTab = state.isProfileComplete ? .focus : .profile
            }
            .onChange(of: state.isProfileComplete) { _, isComplete in
                selectedTab = isComplete ? .focus : .profile
            }
        }
    }
}

// MARK: - Profile gating

extension AppState {
    var isProfileComplete: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlace = placeOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
        let dobIsValid = dob <= Date()
        return !trimmedName.isEmpty && !trimmedPlace.isEmpty && dobIsValid
    }
}

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil,
                   from: nil,
                   for: nil)
    }
}
