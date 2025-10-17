//
//  ScannerReminderModal.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/17/25.
//

import SwiftUI

struct ScannerReminderModal: View {
    let onProceed: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#1E1E22"),
                        Color(hex: "#2D2D35")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("⚠️ QR Code Safety Reminder")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Before scanning, remember:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Only scan QR codes from trusted sources", systemImage: "checkmark.shield")
                            Label("Unknown QR codes may collect your data", systemImage: "exclamationmark.triangle")
                            Label("Verify the sender before scanning", systemImage: "person.crop.circle.badge.checkmark")
                            Label("Never share personal info via QR", systemImage: "lock.shield")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.12))
                                )
                                .foregroundColor(.white)
                        }
                        
                        Button(action: onProceed) {
                            Text("I Understand, Proceed")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#00B4D8"), Color(hex: "#0077B6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                }
                .padding()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
