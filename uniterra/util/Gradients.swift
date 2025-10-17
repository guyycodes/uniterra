//
//  Gradients.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

enum GradientType {
    case orangeRed
    case bluePurplePink
    case cyanToPurple
    case hotDay
    case airQuality
    case sunny
    case rainy
    case yellowToPink
    case pinkToYellow
    case blueToCyan
    case transparentToCyan
    case redToBlue
    case blackToOrangeRed
    case transparentOrangeRedToBlack
    
    var gradient: LinearGradient {
        switch self {
        case .orangeRed:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F6511E"),
                    Color(hex: "#902F12")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .bluePurplePink:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#3B82F6"),
                    Color(hex: "#9333EA"),
                    Color(hex: "#EC4899")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
        case .cyanToPurple:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#00FFFF"),
                    Color(hex: "#9B5DE5")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .hotDay:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FF8C37"),
                    Color(hex: "#FF3D3D")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .airQuality:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#00B4D8"),
                    Color(hex: "#FF6B6B")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .sunny:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FDB813"),
                    Color(hex: "#FD5E53")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
        case .rainy:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#3a7bd5"),
                    Color(hex: "#3a6073")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
        case .yellowToPink:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F7F282"),
                    Color(hex: "#FBCEFF")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .pinkToYellow:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FBCEFF"),
                    Color(hex: "#F7F282")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .blueToCyan:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1A6DED"),
                    Color(hex: "#00E5FF")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .transparentToCyan:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1A6DED").opacity(0.7),
                    Color(hex: "#00E5FF").opacity(0.7)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .redToBlue:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FE0000"),
                    Color(hex: "#253082")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .blackToOrangeRed:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#1E1E22"),
                    Color(hex: "#EC4E1D")
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
        case .transparentOrangeRedToBlack:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#EC4E1D").opacity(0.5),
                    Color(hex: "#1E1E22").opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// Helper extension to use hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
