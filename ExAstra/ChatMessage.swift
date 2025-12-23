//
//  ChatMessage.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//


// ChatModels.swift
import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var content: String
    let createdAt: Date = Date()
}
