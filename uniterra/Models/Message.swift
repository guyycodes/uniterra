//
//  Message.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import Foundation

struct Message: Hashable, Identifiable, Codable {
    let id: String
    let text: String
    let timestamp: Date
    let username: String
    let roomId: String
    let language: String?  // Language of the message text
}
