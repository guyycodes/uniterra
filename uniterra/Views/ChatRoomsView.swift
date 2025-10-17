//
//  ChatRoomsView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

struct ChatRoomsView: View {
    
    @Environment(AuthManager.self) var authManager

    @State private var scrollOffset: CGFloat = 0
    @State private var warmupManager: MessageManager?
    @State private var privateRooms: [ChatRoom] = []
    @State private var showingQRCode: Bool = false
    @State private var selectedPrivateRoom: ChatRoom?
    @State private var showingScanner: Bool = false
    @State private var scannedCode: String?
    @State private var showingAccessDenied: Bool = false
    
    // UserDefaults keys
    private let privateRoomsKey = "privateRoomIds"
    private let createdRoomsKey = "createdPrivateRoomIds"

    // Instead of two booleans + selectedRoom, define a single enum to drive our sheet:
    @State private var activeSheet: ActiveSheet?

    let chatRooms = ChatRoom.publicRooms

    var body: some View {
        NavigationStack {
            ZStack {
                // Rotating background carousel
                BackgroundImageCarousel(
                    theme: .gym,
                    isAuthenticated: true,  // Always show carousel in chat rooms
                    preLoginImage: "fitness-6"
                )
                
                // Gradient overlay for readability
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#1E1E22").opacity(0.7),
                                Color(hex: "#2D2D35").opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
                
                // Scrollable content with collapsing header
                ScrollView {
                    VStack(spacing: 0) {
                        // Collapsing header section
                        headerSection
                            .opacity(Double(max(0, 1 - (scrollOffset / 150))))
                            .offset(y: -scrollOffset * 0.5)
                        
                        // Chat rooms grid
                        chatRoomsGrid
                            .padding(.top, 20)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = max(0, -value)
                }
            }
            .navigationTitle("Uniterra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { authManager.signOut() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign out")
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    }
                }
            }
            // Present either the rules modal OR the chat view in the same sheet:
            .sheet(item: $activeSheet, onDismiss: {
                // When any sheet is dismissed, clear the warmup
                warmupManager = nil
            }) { sheetInfo in
                switch sheetInfo {
                case .rules(let room):
                    RulesModal(
                        roomTitle: "\(room.emoji) \(room.name)",
                        onAgree: {
                            // Close rules and open chat
                            activeSheet = .chat(room)
                        },
                        onCancel: {
                            // Close rules entirely
                            activeSheet = nil
                            warmupManager = nil
                        }
                    )
                    // In case tap happened before warmup creation, ensure warmup exists
                    .onAppear {
                        if warmupManager == nil {
                            warmupManager = MessageManager(roomId: room.id)
                        }
                    }
                    
                case .chat(let room):
                    NavigationStack {
                        ChatView(
                            roomId: room.id,
                            roomName: "\(room.emoji) \(room.name)"
                        )
                        .onAppear {
                            // We no longer need the warmup now that the real chat is presented
                            warmupManager = nil
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Back") {
                                    activeSheet = nil
                                }
                                .foregroundColor(Color(hex: "#F6511E"))
                            }
                        }
                    }
                    
                case .scannerReminder:
                    ScannerReminderModal(
                        onProceed: {
                            activeSheet = nil
                            showingScanner = true
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                }
            }
            // Sheet for QR Code display
            .sheet(isPresented: $showingQRCode) {
                if let room = selectedPrivateRoom {
                    QRCodeModal(room: room)
                }
            }
            // Sheet for QR Scanner
            .sheet(isPresented: $showingScanner) {
                QRScannerView(scannedCode: $scannedCode)
                    .ignoresSafeArea()
            }
            // Sheet for Access Denied
            .sheet(isPresented: $showingAccessDenied) {
                QRAccessDeniedModal()
            }
            .onAppear {
                loadPrivateRoomsFromBoth()
                checkForPendingRoom()
            }
            .onChange(of: scannedCode) { _, newValue in
                if let code = newValue {
                    handleScannedCode(code)
                }
            }
        }
    }
    
    // Check if we need to open a room from deep link
    private func checkForPendingRoom() {
        guard let roomId = UserDefaults.standard.string(forKey: "pendingRoomId") else { return }
        
        // Clear the pending room
        UserDefaults.standard.removeObject(forKey: "pendingRoomId")
        
        // Check if it's an existing private room
        if let existingRoom = privateRooms.first(where: { $0.id == roomId }) {
            // Open existing room
            warmupManager = MessageManager(roomId: existingRoom.id)
            activeSheet = .rules(existingRoom)
        } else if roomId.starts(with: "private-") {
            // Create new private room with this ID
            let newRoom = ChatRoom(
                id: roomId,
                name: "Private Room",
                emoji: "🔐",
                gradientType: .cyanToPurple,
                memberCount: 0,
                lastMessage: nil,
                isPrivate: true
            )
            privateRooms.append(newRoom)
            savePrivateRoomsToLocal()
            
            // Sync with Firebase
            Task {
                await authManager.addPrivateRoom(roomId)
            }
            
            warmupManager = MessageManager(roomId: newRoom.id)
            activeSheet = .rules(newRoom)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large title
            Text("🔥 Uniterra 🔥")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#F6511E"), Color(hex: "#FF8C37")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "#F6511E").opacity(0.5), radius: 10, x: 0, y: 5)
            
            Text("Choose Your Server")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            // Private room buttons
            HStack(spacing: 12) {
                // Create private room
                Button(action: createPrivateRoom) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Create Private")
                        Image(systemName: "qrcode")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color(hex: "#9333EA").opacity(0.5), radius: 8, x: 0, y: 4)
                }
                
                // Scan QR code
                Button(action: { activeSheet = .scannerReminder }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Scan QR")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#00B4D8"), Color(hex: "#0077B6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color(hex: "#00B4D8").opacity(0.5), radius: 8, x: 0, y: 4)
                }
            }
            
            if authManager.userProfile?.language == nil {
                Text("⚠️ Set your language when entering a room")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#FFD700"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                    Text("Translating to: \(authManager.userProfile?.language ?? "")")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    // MARK: - Chat Rooms Grid
    private var chatRoomsGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Private rooms section if any exist
            if !privateRooms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔒 Private Rooms")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(privateRooms) { room in
                                PrivateRoomTile(
                                    room: room,
                                    onDelete: {
                                        deletePrivateRoom(room)
                                    }
                                )
                                .onTapGesture {
                                    warmupManager = MessageManager(roomId: room.id)
                                    activeSheet = .rules(room)
                                }
                                .onLongPressGesture {
                                    selectedPrivateRoom = room
                                    let createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
                                    if createdRooms.contains(room.id) {
                                        showingQRCode = true
                                    } else {
                                        showingAccessDenied = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            // Public rooms section
            Text("🌍 Public Servers")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(chatRooms) { room in
                    ChatRoomTile(room: room)
                        .onTapGesture {
                            warmupManager = MessageManager(roomId: room.id)
                            activeSheet = .rules(room)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helper Functions
    private func createPrivateRoom() {
        let roomId = QRCodeService.shared.generatePrivateRoomId()
        let newRoom = ChatRoom(
            id: roomId,
            name: "Private Room",
            emoji: "🔐",
            gradientType: .cyanToPurple,
            memberCount: 0,
            lastMessage: nil,
            isPrivate: true
        )
        privateRooms.append(newRoom)
        savePrivateRoomsToLocal()
        
        // Track that this user created this room
        var createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
        createdRooms.append(roomId)
        UserDefaults.standard.set(createdRooms, forKey: createdRoomsKey)
        
        // Sync with Firebase
        Task {
            await authManager.addPrivateRoom(roomId)
        }
        
        selectedPrivateRoom = newRoom
        showingQRCode = true
    }
    
    private func deletePrivateRoom(_ room: ChatRoom) {
        withAnimation(.easeOut(duration: 0.3)) {
            privateRooms.removeAll { $0.id == room.id }
            savePrivateRoomsToLocal()
            
            // Also remove from created rooms if it was created by this user
            var createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
            createdRooms.removeAll { $0 == room.id }
            UserDefaults.standard.set(createdRooms, forKey: createdRoomsKey)
            
            // Sync with Firebase
            Task {
                await authManager.removePrivateRoom(room.id)
            }
        }
    }
    
    // Save to local UserDefaults (for fast loading)
    private func savePrivateRoomsToLocal() {
        let roomIds = privateRooms.map { $0.id }
        UserDefaults.standard.set(roomIds, forKey: privateRoomsKey)
    }
    
    // Load from both local and Firebase, merge them
    private func loadPrivateRoomsFromBoth() {
        // First load from local for instant display
        if let localRoomIds = UserDefaults.standard.stringArray(forKey: privateRoomsKey) {
            privateRooms = localRoomIds.map { createRoomFromId($0) }
        }
        
        // Then sync with Firebase
        Task {
            let firebaseRoomIds = await authManager.loadPrivateRooms()
            
            // Merge Firebase rooms with local (avoiding duplicates)
            let existingIds = Set(privateRooms.map { $0.id })
            let newRooms = firebaseRoomIds
                .filter { !existingIds.contains($0) }
                .map { createRoomFromId($0) }
            
            privateRooms.append(contentsOf: newRooms)
            
            // Update local storage with merged list
            savePrivateRoomsToLocal()
        }
    }
    
    // Helper to create room from ID
    private func createRoomFromId(_ roomId: String) -> ChatRoom {
        return ChatRoom(
            id: roomId,
            name: "Private Room",
            emoji: "🔐",
            gradientType: .cyanToPurple,
            memberCount: 0,
            lastMessage: nil,
            isPrivate: true
        )
    }
    
    private func handleScannedCode(_ code: String) {
        scannedCode = nil // Reset for next scan
        
        // Parse the QR code
        if let url = URL(string: code) {
            if url.scheme == "uniterra", url.host == "room",
               let roomId = url.pathComponents.last {
                joinPrivateRoom(roomId: roomId)
            } else if code.starts(with: "private-") {
                // Direct room ID
                joinPrivateRoom(roomId: code)
            }
        } else if code.starts(with: "private-") {
            // Direct room ID
            joinPrivateRoom(roomId: code)
        }
    }
    
    private func joinPrivateRoom(roomId: String) {
        // Check if room already exists
        if let existingRoom = privateRooms.first(where: { $0.id == roomId }) {
            warmupManager = MessageManager(roomId: existingRoom.id)
            activeSheet = .rules(existingRoom)
        } else {
            // Create new room with scanned ID
            let newRoom = ChatRoom(
                id: roomId,
                name: "Private Room",
                emoji: "🔐",
                gradientType: .cyanToPurple,
                memberCount: 0,
                lastMessage: nil,
                isPrivate: true
            )
            privateRooms.append(newRoom)
            savePrivateRoomsToLocal()
            
            // Sync with Firebase
            Task {
                await authManager.addPrivateRoom(roomId)
            }
            
            warmupManager = MessageManager(roomId: newRoom.id)
            activeSheet = .rules(newRoom)
        }
    }
}

    // MARK: - ActiveSheet Enum
    private enum ActiveSheet: Identifiable {
        case rules(ChatRoom)
        case chat(ChatRoom)
        case scannerReminder

        var id: String {
            switch self {
            case .rules(let room):
                return "rules-\(room.id)"
            case .chat(let room):
                return "chat-\(room.id)"
            case .scannerReminder:
                return "scanner-reminder"
            }
        }
    }


    // MARK: - Private Room Tile
    struct PrivateRoomTile: View {
        let room: ChatRoom
        let onDelete: () -> Void
        
        var body: some View {
            ZStack {
                // Main content
                VStack(spacing: 8) {
                    Text(room.emoji)
                        .font(.system(size: 32))
                    
                    Text("Private")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    Text("Hold for QR")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Delete button positioned at top-right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 20))
                        }
                        .padding(6)
                    }
                    Spacer()
                }
            }
            .frame(width: 100, height: 100)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#9333EA").opacity(0.8), Color(hex: "#EC4899").opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color(hex: "#9333EA").opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - QR Access Denied Modal
    struct QRAccessDeniedModal: View {
        @Environment(\.dismiss) var dismiss
        
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
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("🔐 QR Code Access")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Only the creator of the room may directly access the room QR code")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { dismiss() }) {
                            Text("OK")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
    }
    
    
    // MARK: - QR Code Modal
    struct QRCodeModal: View {
        let room: ChatRoom
        @Environment(\.dismiss) var dismiss
        
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
                        Text("🔐 Private Room QR Code")
                            .font(.title2.bold())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // QR Code
                        Image(uiImage: QRCodeService.shared.generateQRCode(from: QRCodeService.shared.generateDeepLink(for: room.id)))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 12) {
                            Text("Room ID: \(room.id)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .textSelection(.enabled)
                            
                            Text("Share this QR code with others to invite them to this private room")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            // Share functionality would go here
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share QR Code")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#9333EA"), Color(hex: "#EC4899")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(Color(hex: "#EC4899"))
                    }
                }
            }
        }
    }
    
    // MARK: - Chat Room Tile
    struct ChatRoomTile: View {
        let room: ChatRoom

        var body: some View {
            VStack(spacing: 12) {
                // Emoji icon
                Text(room.emoji)
                    .font(.system(size: 48))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                
                // Room name
                Text(room.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Member count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(room.memberCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.8))
                
                // Last message preview
                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 30)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .padding(16)
            .background(
                ZStack {
                    // Gradient background
                    room.gradientType.gradient

                    // Frosted glass overlay
                    Color.white.opacity(0.1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ChatRoomsView()
        .environment(AuthManager())
}
