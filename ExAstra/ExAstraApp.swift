//
//  ExAstraApp.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

import SwiftUI
import SwiftData

@main
struct ExAstraApp: App {
    @StateObject private var state = AppState()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }

                NavigationStack {
                    FocusView()
                }
                .tabItem {
                    Label("Focus", systemImage: "sparkles")
                }

                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .environmentObject(state)
        }
    }
}
    
