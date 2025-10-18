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
    
    // REMOVE @ObservedObject - it's triggering initialization!
    @State private var isTranslating = false
    @State private var translationResult: String?
    @State private var translationError: String?
    @State private var modelDownloadProgress: Double = 0.0
    @State private var isDownloadingModel = false
    @State private var currentMessageText: String = ""  // Track current input text
    @State private var modelThoughts: String = ""  // Store model's thinking process
    @State private var showThoughts = false  // Toggle for expanding thoughts
    
    init(roomId: String = "general", roomName: String = "Chat") {
        messageManager = MessageManager(roomId: roomId)
        self.roomName = roomName
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#1E1E22")
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
            
            if messageManager.isLoading {
                // Loading state
                ProgressView()
                    .tint(Color(hex: "#F6511E"))
            } else {
                // Chat content
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if messageManager.messages.isEmpty {
                                emptyState
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
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            hideKeyboard()
                        }
                    )
                    
                    if let translation = translationResult {
                        translationOverlay(translation)
                    }
                    
                    SendMessageView(messageText: $currentMessageText) { messageText in
                        messageManager.sendMessage(text: messageText, username: authManager.userEmail ?? "")
                        currentMessageText = ""  // Clear after sending
                    }
                }
            }
            
            // Progress Overlay
            if isDownloadingModel || isTranslating {
                VStack {
                    Spacer()
                    progressOverlay
                }
            }
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Translate") {
                    runTranslate()
                }
                .disabled(isDownloadingModel || isTranslating)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign out") {
                    authManager.signOut()
                }
            }
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
    
    // MARK: - Subviews
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("💬").font(.system(size: 60))
            Text("No messages yet")
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var progressOverlay: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProgressView().tint(Color(hex: "#F6511E"))
                
                if isDownloadingModel {
                    Text("Downloading...")
                        .foregroundColor(.white)
                } else if isTranslating {
                    // Animated thinking display
                    HStack(spacing: 2) {
                        Text("Thinking")
                            .foregroundColor(.white)
                        ThinkingDots()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, 16)
    }
    
    private func translationOverlay(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(currentMessageText.isEmpty ? "📚 Translation (from chat)" : "✏️ Translation (your text)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button {
                    translationResult = nil
                    modelThoughts = ""
                    showThoughts = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            
            // Expandable thoughts section (if present)
            if !modelThoughts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showThoughts.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showThoughts ? "chevron.down.circle" : "chevron.right.circle")
                                .font(.caption)
                            Text("Model thoughts")
                                .font(.caption2)
                            Spacer()
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    
                    if showThoughts {
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(modelThoughts)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 12)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 100)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
            }
            
            // Main translation result
            HStack {
                Text(translation)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(12)
            .background(Color(hex: "#2D2D35"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Translation Logic
    
    private func runTranslate() {
        guard let targetLanguage = authManager.userProfile?.language else {
            translationError = "Please set your language"
            return
        }
        
        // PRIORITY 1: Check if there's text in the input field
        let sourceText: String
        if !currentMessageText.isEmpty {
            sourceText = currentMessageText
            print("🎯 Translating from INPUT FIELD: \(sourceText)")
        } else {
            // PRIORITY 2: Look for latest incoming message
            print("🔍 Latest messages:")
            for msg in messageManager.messages.suffix(3) {
                print("  - \(msg.username): \(msg.text)")
            }
            
            let sample = "Hey, can you meet at 3pm?"
            let latestIncoming = messageManager.messages
                .reversed() // Start from most recent
                .first(where: { $0.username != authManager.userEmail })?.text
            sourceText = latestIncoming ?? sample
            
            print("🎯 Translating from MESSAGES: \(sourceText)")
        }
        
        Task.detached(priority: .userInitiated) {
            do {
                await ensureModelConfiguration()
                
                if await !ModelManager.shared.isReady {
                    await MainActor.run { isDownloadingModel = true }
                    
                    try await ModelManager.shared.prepareModel { progress in
                        Task { @MainActor in
                            self.modelDownloadProgress = progress
                        }
                    }
                    await MainActor.run { isDownloadingModel = false }
                }
                
                await MainActor.run {
                    isTranslating = true
                }
                
                // Get translation (onToken gets full response, not streaming)
                let output = try await ModelManager.shared.translate(
                    sourceText,
                    targetLang: targetLanguage,
                    onToken: nil  // Not actually streaming, so don't bother
                    // COMMENTED OUT FOR NOW BECAUSE IT'S NOT WORKING and not implmented
                    // onToken: { token in
                    //     fullOutput += token
                        
                    //     // Update streaming thought display
                    //     Task { @MainActor in
                    //         // Extract current thinking content if in thinking tags
                    //         if fullOutput.contains("<think>") && !fullOutput.contains("</think>") {
                    //             // We're in the middle of thinking - show last line
                    //             let thinkStart = fullOutput.range(of: "<think>")!
                    //             let thoughtContent = String(fullOutput[thinkStart.upperBound...])
                    //                 .replacingOccurrences(of: "\n", with: " ")
                    //                 .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                    //             // Show last 80 characters of current thought
                    //             if thoughtContent.count > 80 {
                    //                 streamingThought = "..." + String(thoughtContent.suffix(80))
                    //             } else {
                    //                 streamingThought = thoughtContent
                    //             }
                    //         }
                    //     }
                    // }
                    
                )
                
                await MainActor.run {
                    let parsed = parseTranslation(output)
                    translationResult = parsed.translation
                    modelThoughts = parsed.thoughts
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    translationError = "Translation failed: \(error.localizedDescription)"
                    isTranslating = false
                    isDownloadingModel = false
                }
            }
        }
    }
    
    private func parseTranslation(_ rawOutput: String) -> (translation: String, thoughts: String) {
        // Remove chat template markers first
        var cleaned = rawOutput
            .replacingOccurrences(of: "<|im_start|>assistant", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|im_start|>user", with: "")
            .replacingOccurrences(of: "<|im_start|>system", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract thoughts if present
        var thoughts = ""
        var translation = cleaned
        
        if let thinkStart = cleaned.range(of: "<think>"),
           let thinkEnd = cleaned.range(of: "</think>") {
            // Extract the thinking content
            let thoughtContent = String(cleaned[thinkStart.upperBound..<thinkEnd.lowerBound])
            thoughts = thoughtContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove the entire think block from the output
            translation = cleaned.replacingOccurrences(of: "<think>\(thoughtContent)</think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Clean up any remaining newlines and get just the translation
        translation = translation
            .split(separator: "\n")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? translation
        
        return (translation: translation, thoughts: thoughts)
    }
    
    private func ensureModelConfiguration() async {
        let modelId = UserDefaults.standard.string(forKey: "selectedModelId") ?? ModelDefinition.qwen8BInstruct.id
        guard let model = ModelDefinition.availableModels.first(where: { $0.id == modelId }) else {
            return
        }
        
        let config = ModelManager.Config(
            modelRemoteURL: URL(string: model.huggingFaceURL)!,
            modelFilename: model.filename,
            modelSHA256: model.sha256,
            contextLength: model.contextLength,
            temperature: 0.2,
            topP: 0.95,
            topK: 64,
            repeatPenalty: 1.05,
            maxTokens: 256
        )
        
        await MainActor.run {
            ModelManager.shared.configure(config)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - MessageRow
struct MessageRow: View {
    let text: String
    let isOutgoing: Bool
    
    var body: some View {
        HStack {
            if isOutgoing { Spacer() }
            Text(text)
                .padding(12)
                .background(isOutgoing ? Color(hex: "#F6511E") : Color(.systemGray5))
                .foregroundColor(isOutgoing ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isOutgoing { Spacer() }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - SendMessageView
struct SendMessageView: View {
    @Binding var messageText: String  // Changed from @State to @Binding
    var onSend: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText)
                .focused($isFocused)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .textFieldStyle(.plain)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? .gray : Color(hex: "#F6511E"))
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        onSend(messageText)
        // Parent handles clearing the text now
        isFocused = false
    }
}

// MARK: - ThinkingDots Animation
struct ThinkingDots: View {
    @State private var dotCount = 0
    
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()  // Faster
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .foregroundColor(.white)
            .frame(width: 20, alignment: .leading)
            .animation(.easeInOut(duration: 0.3), value: dotCount)  // Smooth animation
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
    }
}
