//
//  SplashScreenView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var flameScale: CGFloat = 0.5
    @State private var flameOpacity: Double = 0.5
    @State private var flameRotation: Double = -5
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1E1E22"),
                    Color(hex: "#2D2D35"),
                    Color(hex: "#1E1E22")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated Flame
                ZStack {
                    // Glow effect
                    Image(systemName: "flame.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#FF8C37").opacity(glowIntensity),
                                    Color(hex: "#F6511E").opacity(glowIntensity)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blur(radius: 30)
                        .scaleEffect(1.5)
                    
                    // Main flame
                    Image(systemName: "flame.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#FFD700"),
                                    Color(hex: "#FF8C37"),
                                    Color(hex: "#F6511E")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "#F6511E").opacity(0.8), radius: 20, x: 0, y: 10)
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)
                        .rotationEffect(.degrees(flameRotation))
                }
                
                // App name
                VStack(spacing: 8) {
                    Text("Uniterra")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(hex: "#F6511E").opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .opacity(flameOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Flame flicker animation
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
        ) {
            flameScale = 1.1
            flameOpacity = 1.0
            glowIntensity = 0.8
        }
        
        // Flame sway animation
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            flameRotation = 5
        }
    }
}

#Preview {
    SplashScreenView()
}
