//
//  MessageManager.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import Foundation
import FirebaseFirestore

@Observable
class MessageManager {

    var messages: [Message] = []
    var isLoading: Bool = true // <-- Add loading state
    let roomId: String

    private let dataBase = Firestore.firestore()

    init(roomId: String = "general") {
        self.roomId = roomId
        getMessages()
    }

    func getMessages() {
        // Query messages filtered by roomId
        dataBase.collection("messages")
            .whereField("roomId", isEqualTo: roomId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                // Get the documents for the messages collection
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(String(describing: error))")
                    self.isLoading = false // <-- Stop loading even on error
                    return
                }
                
                // Map Firestore documents to Message objects
                let messages = documents.compactMap { document in
                    do {
                        return try document.data(as: Message.self)
                    } catch {
                        print("Error decoding document into message: \(error)")
                        return nil
                    }
                }
                
                // Update the messages property with the fetched messages
                self.messages = messages.sorted(by: { $0.timestamp < $1.timestamp })
                self.isLoading = false // <-- Stop loading once we have data
            }
    }

    func sendMessage(text: String, username: String) {
        do {
            // Detect language of the message
            let detectedLanguage = LanguageDetector.detect(from: text)
            
            let message = Message(
                id: UUID().uuidString,
                text: text,
                timestamp: Date(),
                username: username,
                roomId: roomId,
                language: detectedLanguage
            )

            // Use the message's id as the Firestore document ID
            try dataBase.collection("messages").document(message.id).setData(from: message)

        } catch {
            print("Error sending message to Firestore: \(error)")
        }
    }
}
