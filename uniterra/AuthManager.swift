//
//  AuthManager.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthManager: ObservableObject {  // ← Changed from @Observable

    @Published var user: User?  // ← Add @Published
    @Published var userProfile: UserProfile?  // ← Add @Published
    @Published var isSignedIn: Bool = false  // ← Add @Published
    @Published var errorMessage: String? = nil  // ← Add @Published
    
    let isMocked: Bool

    var userEmail: String? {
        isMocked ? "kingsley@dog.com" : user?.email
    }

    private var handle: AuthStateDidChangeListenerHandle?  // ← Remove @ObservationIgnored
    private let db = Firestore.firestore()

    init(isMocked: Bool = false) {
        self.isMocked = isMocked
        
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isSignedIn = user != nil
                if let user = user {
                    await self?.loadUserProfile(userId: user.uid)
                } else {
                    self?.userProfile = nil
                }
            }
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // Check if username already exists
    func checkUsernameAvailability(username: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            return snapshot.documents.isEmpty
        } catch {
            print("Error checking username: \(error)")
            return false
        }
    }
    
    // Check if phone number already exists
    func checkPhoneAvailability(phoneNumber: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .getDocuments()
            return snapshot.documents.isEmpty
        } catch {
            print("Error checking phone: \(error)")
            return false
        }
    }

    func signUp(email: String, password: String, userProfile: UserProfile) {
        Task {
            do {
                errorMessage = nil
                
                // Check if username is available
                let usernameAvailable = await checkUsernameAvailability(username: userProfile.username)
                if !usernameAvailable {
                    errorMessage = "This username is already taken"
                    return
                }
                
                // Check if phone number is available
                let phoneAvailable = await checkPhoneAvailability(phoneNumber: userProfile.phoneNumber)
                if !phoneAvailable {
                    errorMessage = "This phone number is already in use"
                    return
                }
                
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                
                var updatedProfile = userProfile
                updatedProfile = UserProfile(
                    id: authResult.user.uid,
                    email: updatedProfile.email,
                    username: updatedProfile.username,
                    phoneNumber: updatedProfile.phoneNumber,
                    dateOfBirth: updatedProfile.dateOfBirth,
                    language: updatedProfile.language
                )
                
                try await saveUserProfile(updatedProfile)
                
                self.user = authResult.user
                self.userProfile = updatedProfile
            } catch let error as NSError {
                if let errorCode = AuthErrorCode(_bridgedNSError: error) {
                    switch errorCode {
                    case .emailAlreadyInUse:
                        errorMessage = "This email is already in use"
                    case .weakPassword:
                        errorMessage = "Password is too weak. Please use at least 6 characters"
                    case .invalidEmail:
                        errorMessage = "Invalid email address"
                    default:
                        errorMessage = "Sign up failed. Please try again"
                    }
                } else {
                    errorMessage = "Sign up failed. Please try again"
                }
                print("Sign up error: \(error)")
            }
        }
    }

    func signIn(email: String, password: String) {
        Task {
            do {
                errorMessage = nil
                
                let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
                self.user = authResult.user
                // Load user profile after successful sign in
                await loadUserProfile(userId: authResult.user.uid)
            } catch let error as NSError {
                if let errorCode = AuthErrorCode(_bridgedNSError: error) {
                    switch errorCode {
                    case .wrongPassword:
                        errorMessage = "Incorrect password. Please try again"
                    case .userNotFound:
                        errorMessage = "No account found with this email"
                    case .invalidEmail:
                        errorMessage = "Invalid email address"
                    case .invalidCredential:
                        errorMessage = "Invalid email or password"
                    default:
                        errorMessage = "Login failed. Please try again"
                }
            } else {
                errorMessage = "Login failed. Please try again"
            }
            print("Sign in error: \(error)")
        }
    }
}

    func signOut() {
        do {
            errorMessage = nil
            try Auth.auth().signOut()
            user = nil
            userProfile = nil
        } catch {
            errorMessage = "Sign out failed"
            print("Sign out error: \(error)")
        }
    }
    
    private func saveUserProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.id).setData(from: profile)
    }
    
    func loadUserProfile(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                self.userProfile = try document.data(as: UserProfile.self)
            }
        } catch {
            print("Error loading user profile: \(error)")
        }
    }
    
    func updateUserLanguage(_ language: String) async {
        guard let userId = user?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "language": language
            ])
            
            // Update local profile
            if var profile = userProfile {
                profile.language = language
                self.userProfile = profile
            }
        } catch {
            print("Error updating language: \(error)")
            errorMessage = "Failed to update language preference"
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Rooms Management
    
    func savePrivateRooms(_ roomIds: [String]) async {
        guard let userId = user?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "privateRoomIds": roomIds
            ])
        } catch {
            // If document doesn't exist or field doesn't exist, use setData with merge
            do {
                try await db.collection("users").document(userId).setData([
                    "privateRoomIds": roomIds
                ], merge: true)
            } catch {
                print("Error saving private rooms: \(error)")
            }
        }
    }
    
    func loadPrivateRooms() async -> [String] {
        guard let userId = user?.uid else { return [] }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let roomIds = document.data()?["privateRoomIds"] as? [String] {
                return roomIds
            }
        } catch {
            print("Error loading private rooms: \(error)")
        }
        return []
    }
    
    func addPrivateRoom(_ roomId: String) async {
        guard let userId = user?.uid else { return }
        
        do {
            // Use FieldValue.arrayUnion to add if not already present
            try await db.collection("users").document(userId).updateData([
                "privateRoomIds": FieldValue.arrayUnion([roomId])
            ])
        } catch {
            // If document doesn't exist, create it with the room
            do {
                try await db.collection("users").document(userId).setData([
                    "privateRoomIds": [roomId]
                ], merge: true)
            } catch {
                print("Error adding private room: \(error)")
            }
        }
    }
    
    func removePrivateRoom(_ roomId: String) async {
        guard let userId = user?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "privateRoomIds": FieldValue.arrayRemove([roomId])
            ])
        } catch {
            print("Error removing private room: \(error)")
        }
    }
}
