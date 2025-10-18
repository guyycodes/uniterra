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
    @State private var flameRotation: Double = -2  // reduced rotation range
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
                ZStack {
                    // Glow effect with reduced blur
                    Image(systemName: "flame.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)  // reduced from 150
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
                        .blur(radius: 15)  // reduced from 30 to 15
                        .scaleEffect(1.3)  // reduced from 1.5
                    
                    // Main flame
                    Image(systemName: "flame.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)  // reduced from 120
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
                        .shadow(color: Color(hex: "#F6511E").opacity(0.7), radius: 10, x: 0, y: 5)  // reduced shadow
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)
                        .rotationEffect(.degrees(flameRotation))
                }
                
                Text("Uniterra")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "#F6511E").opacity(0.5), radius: 8, x: 0, y: 4)  // reduced shadow
                    .opacity(flameOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Flicker + scale up a bit
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatCount(3, autoreverses: true)  // only repeat a few times
        ) {
            flameScale = 1.1
            flameOpacity = 1.0
            glowIntensity = 0.7  // reduced from 0.8
        }
        
        // Sway back and forth slightly
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatCount(3, autoreverses: true)  // also limit repeats
        ) {
            flameRotation = 2  // reduced from 5
        }
    }
}

#Preview {
    SplashScreenView()
}
