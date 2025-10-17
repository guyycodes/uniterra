//
//  BackgroundImageCarousel.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

/// Animation timing constants (in seconds)
private let FADE_DURATION: Double = 0.25
private let DISPLAY_DURATION: Double = 3.0

/// Theme definitions containing image arrays
enum BackgroundTheme {
    case gym
    case mindfulness
    case recovery
    
    var images: [String] {
        switch self {
        case .gym:
            return [
                "fitness-1",      // Your current image
                "fitness-2",
                "fitness-3",
                "fitness-4",
                "fitness-5"
            ]
        case .mindfulness:
            return [
                "mindfulness-1",
                "mindfulness-2",
                "mindfulness-3"
            ]
        case .recovery:
            return [
                "recovery-1",
                "recovery-2",
                "recovery-3"
            ]
        }
    }
}

/// BackgroundImageCarousel - Handles image carousel with fade animations
struct BackgroundImageCarousel: View {
    
    // MARK: - Properties
    let theme: BackgroundTheme
    let isAuthenticated: Bool
    let preLoginImage: String
    
    @State private var currentIndex: Int = 0
    @State private var visibleLayer: Int = 1
    @State private var layer1Opacity: Double = 1.0
    @State private var layer2Opacity: Double = 0.0
    @State private var timer: Timer?
    
    private var backgroundImages: [String] {
        theme.images
    }
    
    // MARK: - Initialization
    init(
        theme: BackgroundTheme = .gym,
        isAuthenticated: Bool = false,
        preLoginImage: String = "fitness-girl"
    ) {
        self.theme = theme
        self.isAuthenticated = isAuthenticated
        self.preLoginImage = preLoginImage
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if !isAuthenticated {
                // Single static background when not authenticated
                GeometryReader { geometry in
                    Image(preLoginImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                // Two-layer carousel with fade animations
                GeometryReader { geometry in
                    ZStack {
                        // Layer 1
                        Image(backgroundImages[layer1Index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .opacity(layer1Opacity)
                        
                        // Layer 2
                        Image(backgroundImages[layer2Index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .opacity(layer2Opacity)
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    startCarousel()
                }
                .onDisappear {
                    stopCarousel()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var layer1Index: Int {
        visibleLayer == 1 ? currentIndex : (currentIndex + 1) % backgroundImages.count
    }
    
    private var layer2Index: Int {
        visibleLayer == 1 ? (currentIndex + 1) % backgroundImages.count : currentIndex
    }
    
    // MARK: - Methods
    
    /// Start the carousel animation loop
    private func startCarousel() {
        guard isAuthenticated else { return }
        
        // Reset state
        currentIndex = 0
        layer1Opacity = 1.0
        layer2Opacity = 0.0
        visibleLayer = 1
        
        scheduleNextTransition()
    }
    
    /// Stop the carousel and clean up timer
    private func stopCarousel() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Schedule the next image transition
    private func scheduleNextTransition() {
        guard isAuthenticated else { return }
        
        // Clear existing timer
        timer?.invalidate()
        
        // Schedule next transition
        timer = Timer.scheduledTimer(withTimeInterval: DISPLAY_DURATION, repeats: false) { _ in
            performTransition()
        }
    }
    
    /// Perform the fade transition between images
    private func performTransition() {
        let currentlyVisible = visibleLayer
        let currentlyHidden = visibleLayer == 1 ? 2 : 1
        
        withAnimation(.easeInOut(duration: FADE_DURATION)) {
            if currentlyVisible == 1 {
                layer1Opacity = 0.0
                layer2Opacity = 1.0
            } else {
                layer1Opacity = 1.0
                layer2Opacity = 0.0
            }
        }
        
        // After animation completes, update index and schedule next
        DispatchQueue.main.asyncAfter(deadline: .now() + FADE_DURATION) {
            currentIndex = (currentIndex + 1) % backgroundImages.count
            visibleLayer = currentlyHidden
            scheduleNextTransition()
        }
    }
}

// MARK: - Preview
#Preview {
    BackgroundImageCarousel(
        theme: .gym,
        isAuthenticated: true,
        preLoginImage: "fitness-1"
    )
}
