//
//  ChatViewModel.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//


// ChatViewModel.swift
import Foundation
import SwiftUI
import SwiftOpenAI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var isSending: Bool = false
    @Published var errorText: String? = nil

    private let service: OpenAIService

    private var profileContext: String = ""
    private var focusHint: String = ""

   /* init(apiKey: String, organizationID: String? = nil) {
        // SwiftOpenAI recommended init
        if let organizationID, !organizationID.isEmpty {
            self.service = OpenAIServiceFactory.service(apiKey: apiKey, organizationID: organizationID)
        } else {
            self.service = OpenAIServiceFactory.service(apiKey: apiKey)
        }
    }*/
    
    // MARK: - Init
    init() {
        let key = Bundle.main.object(
            forInfoDictionaryKey: "OPENAI_API_KEY"
        ) as? String

        print("API Key exists:", !(key ?? "").isEmpty)

        guard let apiKey = key, !apiKey.isEmpty else {
            fatalError("❌ OPENAI_API_KEY missing. Check Secrets.xcconfig + Info.plist")
        }

        self.service = OpenAIServiceFactory.service(apiKey: apiKey)
    }
    

    func seedIfNeeded(profile: String, focusHint: String) {
        guard messages.isEmpty else { return }

        self.profileContext = profile
        self.focusHint = focusHint

        messages.append(.init(role: .assistant, content: """
        Hello. I’m your astrologer guide. Ask a specific question and I’ll tailor the answer to your profile and focus area.
        """))
    }

    func send() async {
        errorText = nil
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        messages.append(.init(role: .user, content: text))
        isSending = true
        defer { isSending = false }

        do {
            let system = """
            You are a helpful astrologer assistant blending Western, Vedic, and Chinese astrology.
            Provide thoughtful, actionable guidance. Be clear about uncertainty and avoid absolute claims.
            Keep responses concise but useful. Ask a clarifying question if the user’s query is ambiguous.

            User Profile:
            \(profileContext)

            Focus Guidance:
            \(focusHint)
            """

            var chat: [ChatCompletionParameters.Message] = [
                .init(role: .system, content: .text(system))
            ]

            for m in messages {
                switch m.role {
                case .user:
                    chat.append(.init(role: .user, content: .text(m.content)))
                case .assistant:
                    chat.append(.init(role: .assistant, content: .text(m.content)))
                }
            }

            // Choose a model you have enabled. SwiftOpenAI supports .gpt4o (and others).
            let params = ChatCompletionParameters(
                messages: chat,
                model: .gpt5Mini
            )

            let response = try await service.startChat(parameters: params)

            let reply =
            response.choices?.first?.message?.content
                ?? "I couldn’t generate a response."

            messages.append(.init(role: .assistant, content: reply))
            

        } catch APIError.responseUnsuccessful(let description, let statusCode) {
            errorText = "Request failed (\(statusCode)): \(description)"
        } catch {
            errorText = error.localizedDescription
        }
    }
}
