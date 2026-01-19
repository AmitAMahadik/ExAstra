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

    private var service: OpenAIService?

    private var profileContext: String = ""
    private var focusHint: String = ""

    private var lunarSign: String = "—"
    private var solarSign: String = "—"
    private var chineseSign: String = "—"
    
    // MARK: - Init
    init() {
        // Try to initialize service from UserDefaults first (runtime setup), otherwise fall back to Info.plist.
        let userKey = UserDefaults.standard.string(forKey: "OPENAI_API_KEY")
        if let apiKey = userKey, !apiKey.isEmpty {
            self.service = OpenAIServiceFactory.service(apiKey: apiKey)
        } else {
            let bundleKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
            if let apiKey = bundleKey, !apiKey.isEmpty {
                self.service = OpenAIServiceFactory.service(apiKey: apiKey)
            } else {
                self.service = nil
                print("Warning: OPENAI_API_KEY not set — AI features disabled for this build.")
            }
        }
    }
    
    private func ensureService() {
        if service != nil { return }
        if let apiKey = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !apiKey.isEmpty {
            service = OpenAIServiceFactory.service(apiKey: apiKey)
        } else if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !bundleKey.isEmpty {
            service = OpenAIServiceFactory.service(apiKey: bundleKey)
        }
    }

    func seedIfNeeded(profile: String, focusHint: String, lunarSign: String, solarSign: String, chineseSign: String) {
        guard messages.isEmpty else { return }

        self.profileContext = profile
        self.focusHint = focusHint
        self.lunarSign = lunarSign
        self.solarSign = solarSign
        self.chineseSign = chineseSign

        let nameLine: String = {
            // Extract the name from the profile summary if present
            if let line = profile.split(separator: "\n").first(where: { $0.starts(with: "Name:") }) {
                let fullName = line.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces)
                let firstName = fullName.split(separator: " ").first.map(String.init) ?? ""
                if !firstName.isEmpty && firstName != "Unknown" {
                    return "Hello, \(firstName)."
                }
            }
            return "Hello."
        }()

        messages.append(.init(role: .assistant, content: """
            \(nameLine) I’m your astrologer guide. Ask a specific question and I’ll tailor the answer to your profile and focus area.
            """))
    }

    func send() async {
        errorText = nil
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        messages.append(.init(role: .user, content: text))
        
        // Create a placeholder assistant message that we will “fill” as tokens stream in
        messages.append(.init(role: .assistant, content: ""))
        let assistantIndex = messages.count - 1
        
        isSending = true
        defer { isSending = false }

        do {
            let system = """
\(ChatViewPrompts.system)

Current date: \(DateFormatter.exAstraISO.string(from: Date()))

User Profile:
\(profileContext)

Signs:
- Lunar (Sidereal): \(lunarSign)
- Sun (Western): \(solarSign)
- Chinese: \(chineseSign)

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
                model: .gpt4turbo
            )

            // Ensure service is initialized (supports runtime setup via Profile -> API Key)
            ensureService()
            guard let service = service else {
                let msg = "AI features are disabled for this build. No API key configured."
                errorText = msg
                messages[assistantIndex].content = "Sorry — AI responses are not available in this build."
                return
            }

            // ✅ STREAM
            let stream = try await service.startStreamedChat(parameters: params)  //  //[oai_citation:1‡GitHub](https://github.com/jamesrochabrun/SwiftOpenAI)
            for try await chunk in stream {
                let delta = chunk.choices?.first?.delta?.content ?? ""
                guard !delta.isEmpty else { continue }
                messages[assistantIndex].content += delta
            }

            // Optional: tidy if model returns whitespace only
            if messages[assistantIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[assistantIndex].content = "I couldn’t generate a response."
            }

        } catch APIError.responseUnsuccessful(let description, let statusCode) {
            errorText = "Request failed (\(statusCode)): \(description)"
            // Optional: replace placeholder with error
            messages[assistantIndex].content = "Sorry — something went wrong."
        } catch {
            errorText = error.localizedDescription
            messages[assistantIndex].content = "Sorry — something went wrong."
        }
    }
}

private extension DateFormatter {
    static let exAstraISO: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
