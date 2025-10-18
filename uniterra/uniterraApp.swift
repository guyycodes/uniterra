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
    
    // 1) Use @StateObject so AuthManager is created once for the app's lifetime
    @StateObject private var authManager = AuthManager()
    
    // 2) Keep ModelManager optional if needed later
    @State private var modelManager: ModelManager?
    
    // 3) Track splash screen state
    @State private var showSplash = true
    
    init() {
        // Configure Firebase immediately on app launch
        FirebaseApp.configure()
        
        // Optionally set the global window background here (no SwiftUI views yet)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.backgroundColor = UIColor(
                red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0
            )
        }
        
        // IMPORTANT: Don't initialize or do network work for ModelManager
        // here if you want to defer that until a certain view.
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    // 4) Present the correct view depending on whether user is logged in
                    if authManager.user != nil {
                        ChatRoomsView()
                            // Make authManager available to child views via environment
                            .environmentObject(authManager)
                            .transition(.opacity)
                    } else {
                        LoginView()
                            .environmentObject(authManager)
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
        // Parse URL like: uniterra://room/private-123-456
        guard url.scheme == "uniterra",
              url.host == "room",
              let roomId = url.pathComponents.last
        else {
            return
        }
        
        // Store the room ID to handle after authentication
        UserDefaults.standard.set(roomId, forKey: "pendingRoomId")
        
        print("Opening room: \(roomId)")
        // Next step: In ChatRoomsView, check `pendingRoomId` and navigate if needed
    }
}
