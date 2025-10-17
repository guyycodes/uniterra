//
//  UserProfile.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String // This will be the Firebase Auth user ID
    let email: String
    let username: String
    let phoneNumber: String
    let dateOfBirth: Date
    let createdAt: Date
    var language: String? // User's primary language for translations
    
    init(id: String, email: String, username: String, phoneNumber: String, dateOfBirth: Date, language: String? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.phoneNumber = phoneNumber
        self.dateOfBirth = dateOfBirth
        self.createdAt = Date()
        self.language = language
    }
}

// Available languages for the app
extension UserProfile {
    static let availableLanguages = [
        "English",
        "Spanish",
        "French",
        "German",
        "Italian",
        "Portuguese",
        "Russian",
        "Chinese",
        "Japanese",
        "Korean",
        "Arabic",
        "Hindi",
        "Dutch",
        "Polish",
        "Turkish",
        "Swedish",
        "Norwegian",
        "Danish",
        "Finnish",
        "Greek"
    ]
}
