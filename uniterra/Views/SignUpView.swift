//
//  SignUpView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

struct SignUpView: View {
    
    @Environment(AuthManager.self) var authManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var phoneNumber: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var selectedLanguage: String = "English" // Default to English
    
    var body: some View {
        ZStack {
            // Background
            BackgroundImageCarousel(
                theme: .gym,
                isAuthenticated: false,
                preLoginImage: "fitness-6"
            )
            
            // Gradient overlay
            Rectangle()
                .fill(GradientType.transparentOrangeRedToBlack.gradient)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Title
                    VStack(spacing: 10) {
                        Text("🔥 Uniterra 🔥")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        
                        Text("Create Your Account")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.top, 60)
                    
                    // Sign up form card
                    VStack(spacing: 20) {
                        // Error message from AuthManager
                        if let errorMessage = authManager.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    authManager.clearError()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .shadow(color: .red.opacity(0.5), radius: 5, x: 0, y: 3)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Form fields
                        VStack(spacing: 15) {
                            TextField("Username", text: $username)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(.white)
                                .tint(.white)
                                .onChange(of: username) { _, _ in
                                    authManager.clearError()
                                }
                            
                            TextField("Email", text: $email)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .foregroundColor(.white)
                                .tint(.white)
                                .onChange(of: email) { _, _ in
                                    authManager.clearError()
                                }
                            
                            TextField("Phone Number", text: $phoneNumber)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .keyboardType(.phonePad)
                                .foregroundColor(.white)
                                .tint(.white)
                                .onChange(of: phoneNumber) { _, _ in
                                    authManager.clearError()
                                }
                            
                            // Date of Birth Picker with age requirement note
                            VStack(alignment: .leading, spacing: 4) {
                                DatePicker("Date of Birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                                    .padding()
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .tint(.white)
                                
                                Text("Must be 18 years or older")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 4)
                            }
                            
                            // Language selector
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Primary Language")
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                    Spacer()
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
                                        HStack(spacing: 4) {
                                            Image(systemName: "globe")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(selectedLanguage)
                                                .foregroundColor(.white)
                                                .font(.subheadline)
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: "#F6511E").opacity(0.8), Color(hex: "#FF8C37").opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ))
                                        )
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                
                                Text("Incoming messages will be translated TO this language")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 4)
                            }
                            
                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(.white)
                                .tint(.white)
                                .onChange(of: password) { _, _ in
                                    authManager.clearError()
                                }
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(.white)
                                .tint(.white)
                                .onChange(of: confirmPassword) { _, _ in
                                    authManager.clearError()
                                }
                        }
                        
                        // Sign up button
                        Button(action: handleSignUp) {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(GradientType.orangeRed.gradient)
                                .cornerRadius(12)
                                .shadow(color: Color(hex: "#F6511E").opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        
                        // Back to login button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Already have an account? Login")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(30)
                    .background(
                        ZStack {
                            Color.black.opacity(0.2)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#F6511E").opacity(0.15),
                                    Color(hex: "#902F12").opacity(0.25),
                                    Color.black.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    )
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 30)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: authManager.errorMessage)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    private func handleSignUp() {
        // Clear any previous errors
        authManager.clearError()
        
        // Validation
        guard !username.isEmpty else {
            authManager.errorMessage = "Please enter a username"
            return
        }
        
        guard !email.isEmpty else {
            authManager.errorMessage = "Please enter an email"
            return
        }
        
        guard !phoneNumber.isEmpty else {
            authManager.errorMessage = "Please enter a phone number"
            return
        }
        
        // Age validation - must be 18 or older
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        guard let age = ageComponents.year, age >= 18 else {
            authManager.errorMessage = "You must be at least 18 years old to join"
            return
        }
        
        guard password.count >= 6 else {
            authManager.errorMessage = "Password must be at least 6 characters"
            return
        }
        
        guard password == confirmPassword else {
            authManager.errorMessage = "Passwords do not match"
            return
        }
        
        // Create user profile with language
        let userProfile = UserProfile(
            id: "", // Will be filled with Firebase Auth UID
            email: email,
            username: username,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth,
            language: selectedLanguage
        )
        
        // Sign up via AuthManager
        authManager.signUp(email: email, password: password, userProfile: userProfile)
    }
}

#Preview {
    SignUpView()
        .environment(AuthManager())
}
