//
//  ChatView.swift
//  ExAstra
//
//  Created by Mahadik, Amit on 12/22/25.
//

// ChatView.swift
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var vm = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { msg in
                            ChatBubble(role: msg.role, text: msg.content)
                                .id(msg.id)
                        }

                        if let err = vm.errorText {
                            Text("Error: \(err)")
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .padding(.top, 8)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Ask your astrologer…", text: $vm.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        let text = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty, !vm.isSending else {
                            isInputFocused = false
                            return
                        }

                        isInputFocused = false
                        Task { await vm.send() }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isInputFocused = false
                            }
                        }
                    }
                Button {
                    isInputFocused = false
                    Task { await vm.send() }
                } label: {
                    if vm.isSending { ProgressView() }
                    else { Text("Send") }
                }
                .disabled(vm.isSending || vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .navigationTitle("Astro Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let focusHint = state.focusArea?.systemHint ?? "General guidance."
            vm.seedIfNeeded(
                profile: state.profileSummary(),
                focusHint: focusHint,
                lunarSign: state.lunarSignDeterministic,
                solarSign: state.solarSign,
                chineseSign: state.chineseSign
            )
        }
    }
}

private struct ChatBubble: View {
    let role: ChatMessage.Role
    let text: String

    var body: some View {
        HStack {
            if role == .assistant { Spacer(minLength: 30) }

            Text(text)
                .padding(12)
                .background(role == .user ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)

            if role == .user { Spacer(minLength: 30) }
        }
    }
}
