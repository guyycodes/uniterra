//
//  ChatRoomsView.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/15/25.
//

import SwiftUI

struct ChatRoomsView: View {
    
    @EnvironmentObject var authManager: AuthManager
    
    @State private var scrollOffset: CGFloat = 0
    @State private var warmupManager: MessageManager?
    @State private var privateRooms: [ChatRoom] = []
    @State private var roomToShowQR: ChatRoom? = nil  // Single state: nil = hidden, has room = show QR
    @State private var showingScanner: Bool = false
    @State private var scannedCode: String?
    @State private var showingAccessDenied: Bool = false
    @State private var activeSheet: ActiveSheet?
    
    private let privateRoomsKey = "privateRoomIds"
    private let createdRoomsKey = "createdPrivateRoomIds"
    
    let chatRooms = ChatRoom.publicRooms
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayers
                collapsibleScrollView
            }
            .navigationTitle("Uniterra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                signOutToolbar
            }
            .sheet(item: $activeSheet, onDismiss: {
                warmupManager = nil
            }) { sheetInfo in
                activeSheetView(sheetInfo)
            }
            .sheet(item: $roomToShowQR) { room in
                QRCodeModal(room: room)
            }
            .sheet(isPresented: $showingScanner) {
                QRScannerView(scannedCode: $scannedCode)
                    .ignoresSafeArea()
            }
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
    
    // MARK: - Extracted Subviews
    
    private var backgroundLayers: some View {
        ZStack {
            BackgroundImageCarousel(
                theme: .gym,
                isAuthenticated: true,
                preLoginImage: "fitness-6"
            )
            
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
        }
    }
    
    private var collapsibleScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .opacity(Double(max(0, 1 - (scrollOffset / 150))))
                    .offset(y: -scrollOffset * 0.5)
                
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
    
    private var signOutToolbar: some ToolbarContent {
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
    
    @ViewBuilder
    private func activeSheetView(_ sheetInfo: ActiveSheet) -> some View {
        switch sheetInfo {
        case .rules(let room):
            RulesModal(
                roomTitle: "\(room.emoji) \(room.name)",
                onAgree: {
                    activeSheet = .chat(room)
                },
                onCancel: {
                    activeSheet = nil
                    warmupManager = nil
                }
            )
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("🔥 TranslateMe 🔥")
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
            
            HStack(spacing: 12) {
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
            if !privateRooms.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔒 Private Rooms")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(privateRooms) { room in
                                PrivateRoomTileWrapper(
                                    room: room,
                                    onTap: {
                                        warmupManager = MessageManager(roomId: room.id)
                                        activeSheet = .rules(room)
                                    },
                                    onLongPress: {
                                        let createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
                                        if createdRooms.contains(room.id) {
                                            // Single state update - guaranteed to work
                                            roomToShowQR = room
                                        } else {
                                            showingAccessDenied = true
                                        }
                                    },
                                    onDelete: {
                                        deletePrivateRoom(room)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
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
    
    private func checkForPendingRoom() {
        guard let roomId = UserDefaults.standard.string(forKey: "pendingRoomId") else { return }
        
        UserDefaults.standard.removeObject(forKey: "pendingRoomId")
        
        if let existingRoom = privateRooms.first(where: { $0.id == roomId }) {
            warmupManager = MessageManager(roomId: existingRoom.id)
            activeSheet = .rules(existingRoom)
        } else if roomId.starts(with: "private-") {
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
            
            Task {
                await authManager.addPrivateRoom(roomId)
            }
            
            warmupManager = MessageManager(roomId: newRoom.id)
            activeSheet = .rules(newRoom)
        }
    }
    
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
        
        var createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
        createdRooms.append(roomId)
        UserDefaults.standard.set(createdRooms, forKey: createdRoomsKey)
        
        Task {
            await authManager.addPrivateRoom(roomId)
        }
        
        roomToShowQR = newRoom  // This triggers the QR modal to show
    }
    
    private func deletePrivateRoom(_ room: ChatRoom) {
        withAnimation(.easeOut(duration: 0.3)) {
            privateRooms.removeAll { $0.id == room.id }
            savePrivateRoomsToLocal()
            
            var createdRooms = UserDefaults.standard.stringArray(forKey: createdRoomsKey) ?? []
            createdRooms.removeAll { $0 == room.id }
            UserDefaults.standard.set(createdRooms, forKey: createdRoomsKey)
            
            Task {
                await authManager.removePrivateRoom(room.id)
            }
        }
    }
    
    private func savePrivateRoomsToLocal() {
        let roomIds = privateRooms.map { $0.id }
        UserDefaults.standard.set(roomIds, forKey: privateRoomsKey)
    }
    
    private func loadPrivateRoomsFromBoth() {
        if let localRoomIds = UserDefaults.standard.stringArray(forKey: privateRoomsKey) {
            privateRooms = localRoomIds.map { createRoomFromId($0) }
        }
        
        Task {
            let firebaseRoomIds = await authManager.loadPrivateRooms()
            
            let existingIds = Set(privateRooms.map { $0.id })
            let newRooms = firebaseRoomIds
                .filter { !existingIds.contains($0) }
                .map { createRoomFromId($0) }
            
            privateRooms.append(contentsOf: newRooms)
            
            savePrivateRoomsToLocal()
        }
    }
    
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
        scannedCode = nil
        
        if let url = URL(string: code) {
            if url.scheme == "uniterra", url.host == "room",
               let roomId = url.pathComponents.last {
                joinPrivateRoom(roomId: roomId)
            } else if code.starts(with: "private-") {
                joinPrivateRoom(roomId: code)
            }
        } else if code.starts(with: "private-") {
            joinPrivateRoom(roomId: code)
        }
    }
    
    private func joinPrivateRoom(roomId: String) {
        if let existingRoom = privateRooms.first(where: { $0.id == roomId }) {
            warmupManager = MessageManager(roomId: existingRoom.id)
            activeSheet = .rules(existingRoom)
        } else {
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

// MARK: - PrivateRoomTileWrapper with Haptic and Visual Feedback

struct PrivateRoomTileWrapper: View {
    let room: ChatRoom
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        PrivateRoomTile(
            room: room,
            onDelete: onDelete
        )
        .scaleEffect(isPressed ? 0.93 : 1.0)  // Visual feedback - shrink when pressed
        .opacity(isPressed ? 0.8 : 1.0)  // Visual feedback - dim when pressed
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // Quick tap
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: .infinity,
            pressing: { pressing in
                // This is called when press state changes
                isPressed = pressing
                if pressing {
                    // Haptic feedback when long press starts
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            },
            perform: {
                // This is called when long press completes
                // Another haptic to confirm action
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                onLongPress()
            }
        )
    }
}

// MARK: - PrivateRoomTile

struct PrivateRoomTile: View {
    let room: ChatRoom
    let onDelete: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Text(room.emoji)
                    .font(.system(size: 32))
                
                Text("Private")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                HStack(spacing: 2) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10))
                    Text("Hold for QR")
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                )
            }
            
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
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "#9333EA").opacity(0.4), radius: 8, x: 0, y: 4)
        .shadow(color: Color(hex: "#EC4899").opacity(0.3), radius: 12, x: 0, y: 0)  // Glow effect
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
                    
                    Button(action: { dismiss() }) {
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
            Text(room.emoji)
                .font(.system(size: 48))
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
            
            Text(room.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(room.memberCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white.opacity(0.8))
            
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
                room.gradientType.gradient
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
        .environmentObject(AuthManager())
}
