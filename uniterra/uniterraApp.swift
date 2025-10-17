//
//  uniterraApp.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI
import FirebaseCore


@main
struct uniterraApp: App {
    
    @State private var authManager: AuthManager
    @State private var modelManager: ModelManager?
    @State private var showSplash = true // <-- Add splash screen state
    
    init() {
        FirebaseApp.configure()
        authManager = AuthManager()
        
        // Only set the window background, not the view hierarchy
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)
        }
        
        let cfg = ModelManager.Config(
          modelRemoteURL: URL(string: "...")!,
          modelFilename: "qwen2.5-7b-instruct-q4_k_m.gguf",
          modelSHA256: "PUT_THE_EXACT_SHA256_OF_THE_GGUF_HERE",
          contextLength: 256, temperature: 0.2, topP: 0.95, topK: 64, repeatPenalty: 1.05, maxTokens: 256
        )
        ModelManager.shared.configure(cfg)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    // Show splash screen
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    // Show main app
                    if authManager.user != nil {
                        // User is logged in - show chat rooms selection
                        ChatRoomsView()
                            .environment(authManager)
                            .transition(.opacity)
                    } else {
                        // No logged in user - show LoginView
                        LoginView()
                            .environment(authManager)
                            .transition(.opacity)
                    }
                }
            }
            .onAppear {
                // Hide splash screen after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
            .onOpenURL { url in
                handleDeepLink(url: url)
            }
        }
    }
    
    // Handle deep links from QR codes
    private func handleDeepLink(url: URL) {
        // Parse URL like: uniterra://room/private-123456-78910
        guard url.scheme == "uniterra",
              url.host == "room",
              let roomId = url.pathComponents.last else {
            return
        }
        
        // Store the room ID to handle after authentication
        UserDefaults.standard.set(roomId, forKey: "pendingRoomId")
        
        // TODO: Navigate to the specific room
        // This would be handled in ChatRoomsView by checking for pendingRoomId
        print("Opening room: \(roomId)")
    }
}
