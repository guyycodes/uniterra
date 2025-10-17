//
//  ChatView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

struct ChatView: View {
    
    @Environment(AuthManager.self) var authManager
    @State var messageManager: MessageManager
    let roomName: String
    
    // 👇 ADD: observe the shared model manager (no other files touched)
    @ObservedObject private var translator = ModelManager.shared
    @State private var isTranslating = false
    @State private var translationResult: String?
    @State private var translationError: String?
    
    init(roomId: String = "general", roomName: String = "Chat") {
        messageManager = MessageManager(roomId: roomId)
        self.roomName = roomName
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1E1E22"),
                    Color(hex: "#2D2D35")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if messageManager.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color(hex: "#F6511E"))
                    
                    Text("Loading messages...")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
            } else {
                // Chat content
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 8) {
                            if messageManager.messages.isEmpty {
                                // Empty state
                                VStack(spacing: 12) {
                                    Text("💬")
                                        .font(.system(size: 60))
                                    Text("No messages yet")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Be the first to send a message!")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                            } else {
                                ForEach(messageManager.messages) { message in
                                    MessageRow(
                                        text: message.text,
                                        isOutgoing: authManager.userEmail == message.username
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .defaultScrollAnchor(.bottom)
                    
                    SendMessageView { messageText in
                        messageManager.sendMessage(text: messageText, username: authManager.userEmail ?? "")
                    }
                }
            }
            // 👇 ADD: lightweight progress HUD when preparing or translating
            if translator.isPreparing || isTranslating {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(hex: "#F6511E"))
                        if translator.isPreparing, let p = translator.downloadProgress {
                            Text("Preparing model… \(Int(p * 100))%")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.footnote)
                        } else if translator.isPreparing {
                            Text("Preparing model…")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.footnote)
                        } else {
                            Text("Translating…")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 16)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            // 👇 ADD: simple Translate button (does not replace your Sign out)
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    runTranslate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text("Translate")
                    }
                }
                .disabled(translator.isPreparing || isTranslating)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    authManager.signOut()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign out")
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            }
        }
        // 👇 ADD: show translation or error
                .alert("Translation", isPresented: Binding(
                    get: { translationResult != nil },
                    set: { if !$0 { translationResult = nil } }
                )) {
                    Button("OK", role: .cancel) { translationResult = nil }
                } message: {
                    Text(translationResult ?? "")
                }
                .alert("Translation Error", isPresented: Binding(
                    get: { translationError != nil },
                    set: { if !$0 { translationError = nil } }
                )) {
                    Button("OK", role: .cancel) { translationError = nil }
                } message: {
                    Text(translationError ?? "Unknown error")
                }
            }

            // 👇 ADD: helper to run translation without touching your existing flow
            private func runTranslate() {
                // Ensure user has language set
                guard let targetLanguage = authManager.userProfile?.language else {
                    translationError = "Please set your language in the main screen"
                    return
                }
                
                // Pick something sensible to translate:
                // - If there are messages, use the latest incoming one
                // - Else, use a short sample text
                let sample = "Hey, can you meet at 3pm?"
                let latestIncoming = messageManager.messages.last(where: { authManager.userEmail != $0.username })?.text
                let sourceText = latestIncoming ?? sample

                isTranslating = true
                Task {
                    do {
                        let output = try await ModelManager.shared.ensureAndTranslate(
                            sourceText,
                            targetLang: targetLanguage,
                            onToken: nil // you can stream to UI if you want
                        )
                        translationResult = "Original message translated to \(targetLanguage):\n\n\(output)"
                    } catch {
                        translationError = error.localizedDescription
                    }
                    isTranslating = false
                }
            }
        }

// MARK: - MessageRow
struct MessageRow: View {
    let text: String
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing {
                Spacer()
            }
            messageBubble
            if !isOutgoing {
                Spacer()
            }
        }
    }

    private var messageBubble: some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isOutgoing ? .white : .primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20.0)
                    .fill(
                        isOutgoing
                        ? LinearGradient(
                            colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isOutgoing ? Color(hex: "#F6511E").opacity(0.4) : Color.black.opacity(0.1),
                        radius: isOutgoing ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )
            .padding(isOutgoing ? .trailing : .leading, 12)
            .containerRelativeFrame(.horizontal, count: 7, span: 5, spacing: 0, alignment: isOutgoing ? .trailing : .leading)
    }
}

// MARK: - SendMessageView
struct SendMessageView: View {
    var onSend: (String) -> Void
    
    @State private var messageText: String = ""
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                )
                .lineLimit(1...5)
            
            Button(action: {
                guard !messageText.isEmpty else { return }
                onSend(messageText)
                messageText = ""
            }) {
                ZStack {
                    Circle()
                        .fill(
                            messageText.isEmpty
                            ? LinearGradient(
                                colors: [Color(.systemGray4), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(
                            color: messageText.isEmpty ? .clear : Color(hex: "#F6511E").opacity(0.5),
                            radius: 8,
                            x: 0,
                            y: 2
                        )
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(messageText.isEmpty)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        ChatView(roomId: "general", roomName: "General")
            .environment(AuthManager())
    }
}
