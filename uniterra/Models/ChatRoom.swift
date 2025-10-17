//
//  ChatRoom.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import Foundation

struct ChatRoom: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let gradientType: GradientType
    let memberCount: Int
    let lastMessage: String?
    let isPrivate: Bool
    
    init(id: String, name: String, emoji: String, gradientType: GradientType, memberCount: Int, lastMessage: String? = nil, isPrivate: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.gradientType = gradientType
        self.memberCount = memberCount
        self.lastMessage = lastMessage
        self.isPrivate = isPrivate
    }
}

// MARK: - Public Rooms
extension ChatRoom {
    static let publicRooms: [ChatRoom] = [
        ChatRoom(id: "general", name: "General", emoji: "💬", gradientType: .bluePurplePink, memberCount: 342, lastMessage: "What's up everyone!"),
        ChatRoom(id: "gym-bros", name: "Gym Bros", emoji: "💪", gradientType: .orangeRed, memberCount: 156, lastMessage: "Leg day tomorrow!"),
        ChatRoom(id: "mindfulness", name: "Mindfulness", emoji: "🧘", gradientType: .cyanToPurple, memberCount: 89, lastMessage: "Morning meditation at 6am"),
        ChatRoom(id: "gaming", name: "Gaming", emoji: "🎮", gradientType: .blueToCyan, memberCount: 234, lastMessage: "Anyone down for some Apex?"),
        ChatRoom(id: "food-lovers", name: "Food Lovers", emoji: "🍕", gradientType: .hotDay, memberCount: 198, lastMessage: "Best pizza in town?"),
        ChatRoom(id: "music", name: "Music", emoji: "🎵", gradientType: .yellowToPink, memberCount: 287, lastMessage: "New album dropped!"),
    ]
}
