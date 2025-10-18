//
//  RulesModal.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/17/25.
//

import SwiftUI

struct RulesModal: View {
    @Environment(AuthManager.self) var authManager
    let roomTitle: String
    let onAgree: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedLanguage: String = ""
    @State private var isUpdatingLanguage: Bool = false
    @State private var selectedModelId: String = UserDefaults.standard.string(forKey: "selectedModelId") ?? ModelDefinition.qwen8BInstruct.id
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 20) {
                titleSection
                
                if authManager.userProfile?.language == nil {
                    languageSelectionSection
                }
                
                modelSelectionSection
                
                roomRulesSection
                
                actionButtons
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#1E1E22"),
                Color(hex: "#2D2D35")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        Text("🌍 Translation Settings")
            .font(.title.bold())
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    // MARK: - Language Selection Section
    private var languageSelectionSection: some View {
        VStack(spacing: 16) {
            Text("Welcome to Uniterra Translation Chat!")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Select your primary language. All incoming messages from other languages will be translated TO this language:")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            languageMenu
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Language Menu
    private var languageMenu: some View {
        Menu {
            ForEach(UserProfile.availableLanguages, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                }) {
                    HStack {
                        Text(language)
                        if selectedLanguage == language {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(selectedLanguage.isEmpty ? "Select Your Language" : selectedLanguage)
                    .foregroundColor(selectedLanguage.isEmpty ? .white.opacity(0.6) : .white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding()
            .background(languageMenuBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLanguage)
    }
    
    private var languageMenuBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(languageGradient)
    }

    private var languageGradient: LinearGradient {
        if selectedLanguage.isEmpty {
            return LinearGradient(
                colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#F6511E").opacity(0.8), Color(hex: "#FF8C37").opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // MARK: - Model Selection Section
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Translation Model")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Select the AI model for translation")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 10) {
                ForEach(ModelDefinition.availableModels, id: \.id) { model in
                    modelOption(model)
                }
            }
            
            if isDownloadingModel {
                HStack {
                    ProgressView()
                        .tint(Color(hex: "#F6511E"))
                    Text("Downloading model... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func modelOption(_ model: ModelDefinition) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if isModelDownloaded(model) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#10B981"))
                            .font(.caption)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: selectedModelId == model.id ? "checkmark.circle.fill" : "circle")
                .foregroundColor(
                    selectedModelId == model.id
                    ? Color(hex: "#F6511E")
                    : Color.white.opacity(0.4)
                )
                .font(.system(size: 20))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    selectedModelId == model.id
                    ? Color(hex: "#F6511E").opacity(0.2)
                    : Color.white.opacity(0.05)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selectedModelId == model.id
                    ? Color(hex: "#F6511E").opacity(0.5)
                    : Color.white.opacity(0.2),
                    lineWidth: 1
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedModelId = model.id
                UserDefaults.standard.set(model.id, forKey: "selectedModelId")
            }
        }
    }
    
    // MARK: - Room Rules Section
    private var roomRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Rules for \(roomTitle)")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("• Messages in other languages will be translated TO your language\n• Keep conversations 🔥 but respectful\n• No hate or harassment\n• Don't spam\n• Follow community guidelines")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
        )
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            cancelButton
            enterChatButton
        }
        .padding(.top, 4)
    }
    
    private var cancelButton: some View {
        Button(role: .cancel) {
            onCancel()
        } label: {
            Text("Cancel")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.12))
                )
                .foregroundColor(.white)
        }
    }
    
    private var enterChatButton: some View {
        Button {
            handleEnterChat()
        } label: {
            HStack {
                if isUpdatingLanguage {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text("Enter Chat")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(enterChatButtonBackground)
            .foregroundColor(.white)
            .shadow(color: Color(hex: "#F6511E").opacity(0.4), radius: 8, x: 0, y: 2)
        }
        .disabled(isEnterChatDisabled)
        .opacity(isEnterChatDisabled ? 0.6 : 1.0)
    }
    
    private var enterChatButtonBackground: some View {
        LinearGradient(
            colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var isEnterChatDisabled: Bool {
        (authManager.userProfile?.language == nil && selectedLanguage.isEmpty) || isUpdatingLanguage
    }
    
    private func handleEnterChat() {
        if authManager.userProfile?.language == nil && !selectedLanguage.isEmpty {
            // Update language first, then proceed
            isUpdatingLanguage = true
            Task {
                await authManager.updateUserLanguage(selectedLanguage)
                await configureSelectedModel()
                isUpdatingLanguage = false
                onAgree()
            }
        } else if authManager.userProfile?.language != nil {
            Task {
                await configureSelectedModel()
                onAgree()
            }
        }
    }
    
    private func configureSelectedModel() async {
        guard let model = ModelDefinition.availableModels.first(where: { $0.id == selectedModelId }) else {
            return
        }
        
        // Configure ModelManager with selected model
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
        
        ModelManager.shared.configure(config)
        print("Model configured: \(model.name)")
        
        // Pre-load model in background if already downloaded (warm it up)
        if isModelDownloaded(model) {
            Task.detached(priority: .background) {
                do {
                    print("🔥 Pre-loading model in background...")
                    try await ModelManager.shared.prepareModel()
                    print("✅ Model pre-loaded and ready!")
                } catch {
                    print("⚠️ Model pre-load failed (will retry when needed): \(error)")
                }
            }
        }
    }
    
    private func isModelDownloaded(_ model: ModelDefinition) -> Bool {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsDir.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
}
