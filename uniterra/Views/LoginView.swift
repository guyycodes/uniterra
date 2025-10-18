//
//  LoginView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//
import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showSignUp: Bool = false
    
    private var isAuthenticated: Bool {
        authManager.user != nil
    }

    var body: some View {
        ZStack {
            BackgroundImageCarousel(
                theme: .gym,
                isAuthenticated: isAuthenticated,
                preLoginImage: "fitness-1"
            )
            
            Rectangle()
                .fill(GradientType.transparentOrangeRedToBlack.gradient)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 10) {
                    Text("🔥 Uniterra 🔥")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Text("Translation Servers")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .padding(.top, 40)
                
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Join the Chat 🔥")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Error message display
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
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .foregroundColor(.white)
                            .tint(.white)
                            .onChange(of: email) { _, _ in
                                authManager.clearError() // Clear error when typing
                            }
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.white)
                            .tint(.white)
                            .onChange(of: password) { _, _ in
                                authManager.clearError() // Clear error when typing
                            }
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            authManager.signIn(email: email, password: password)
                        }) {
                            Text("Login")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(GradientType.orangeRed.gradient)
                                .cornerRadius(12)
                                .shadow(color: Color(hex: "#F6511E").opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                )
                        }
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
                
                Spacer()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .presentationDetents([.fraction(0.99)])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
