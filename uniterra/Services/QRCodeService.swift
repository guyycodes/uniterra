//
//  QRCodeService.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/16/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class QRCodeService {
    static let shared = QRCodeService()
    
    private init() {}
    
    // Generate QR code image from a string
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        // Make the QR code larger
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        
        if let outputImage = filter.outputImage?.transformed(by: transform) {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        // Return a placeholder if generation fails
        return UIImage(systemName: "qrcode") ?? UIImage()
    }
    
    // Generate deep link URL for a private room
    func generateDeepLink(for roomId: String) -> String {
        // For now, use custom URL scheme which works when app is installed
        // Later, when you have a website, switch to Universal Links
        return "uniterra://room/\(roomId)"
        
        // Future: When you have uniterra.app domain set up:
        // return "https://uniterra.app/room/\(roomId)"
    }
    
    // Generate a unique private room ID
    func generatePrivateRoomId() -> String {
        // Create a unique ID with timestamp and random component
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 10000...99999)
        return "private-\(timestamp)-\(random)"
    }
}
