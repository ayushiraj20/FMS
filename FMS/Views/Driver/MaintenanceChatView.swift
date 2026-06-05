import SwiftUI

struct MaintenanceChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @State private var messageText = ""

    private var currentUser: User? { appViewModel.currentUser }

    private var messages: [ChatMessage] {
        guard let user = currentUser, let maintenanceUser else { return [] }
        return appViewModel.service.chatMessages(between: user.id, and: maintenanceUser.id)
    }

    private var maintenanceUser: User? {
        appViewModel.service.users(for: .maintenance).first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.1))
                        .frame(width: geo.size.width)
                        .blur(radius: 60)
                        .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.2)
                }.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(0..<messages.count, id: \.self) { index in
                                    let msg = messages[index]
                                    let nextMessage = index < messages.count - 1 ? messages[index + 1] : nil
                                    
                                    // Show timestamp if next message is from a different sender, OR next message is > 1 min later
                                    let showTimestamp = nextMessage == nil || nextMessage?.senderID != msg.senderID || nextMessage!.timestamp.timeIntervalSince(msg.timestamp) > 60
                                    
                                    chatBubble(msg, showTimestamp: showTimestamp)
                                        .id(msg.id)
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 20)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: messages.count) { _, _ in
                            if let lastID = messages.last?.id {
                                withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                            }
                        }
                    }

                    // Input bar
                    VStack {
                        HStack(spacing: 12) {
                            TextField("Type a message...", text: $messageText)
                                .font(.system(.body, design: .rounded))
                                .padding(16)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.textSecondary.opacity(0.2), lineWidth: 1))

                            Button {
                                sendMessage()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? DriverTheme.textSecondary.opacity(0.3) : DriverTheme.accent)
                                    .symbolEffect(.bounce, value: messageText)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                }
            }
            .navigationTitle("Maintenance Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DriverTheme.textSecondary.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func chatBubble(_ message: ChatMessage, showTimestamp: Bool) -> some View {
        let isSent = message.senderID == currentUser?.id
        let isSameSenderAsNext = messages.firstIndex(of: message).map { idx in
            guard idx < messages.count - 1 else { return false }
            let next = messages[idx + 1]
            return next.senderID == message.senderID && next.timestamp.timeIntervalSince(message.timestamp) <= 60
        } ?? false

        return HStack {
            if isSent { Spacer(minLength: 40) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(isSent ? .white : DriverTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isSent ? AnyShapeStyle(DriverTheme.accent) : AnyShapeStyle(.regularMaterial),
                        in: CustomCorners(corners: isSent ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight], radius: 20)
                    )

                if showTimestamp {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(DriverTheme.textSecondary)
                        .padding(.top, 2)
                }
            }
            .scrollTransition { content, phase in
                content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
            }

            if !isSent { Spacer(minLength: 40) }
        }
        .padding(.bottom, isSameSenderAsNext ? 0 : 8)
    }

    private func sendMessage() {
        guard let user = currentUser, let receiver = maintenanceUser, !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        appViewModel.service.sendChatMessage(senderID: user.id, receiverID: receiver.id, message: messageText)
        messageText = ""
    }
}

struct DriverManagerChatView: View {
    @Environment(AppViewModel.self) private var appViewModel

    let driverID: UUID?

    @State private var messageText = ""
    @State private var pollTimer: Timer? = nil
    @State private var speech = SpeechTranscriptionService()
    @State private var showSpeechError = false

    init(driverID: UUID? = nil) {
        self.driverID = driverID
    }

    private var currentUser: User? {
        appViewModel.currentUser
    }

    private var driver: User? {
        if let driverID {
            return appViewModel.service.users.first { $0.id == driverID && ($0.role == .driver || $0.role == .maintenance) }
        }
        return (currentUser?.role == .driver || currentUser?.role == .maintenance) ? currentUser : nil
    }

    private var fleetManager: User? {
        guard let currentUser else { return nil }
        return appViewModel.service.users.first {
            $0.role == .fleetManager && $0.organizationID == currentUser.organizationID
        } ?? appViewModel.service.users(for: .fleetManager).first
    }

    private var recipient: User? {
        guard let currentUser else { return nil }
        switch currentUser.role {
        case .driver:
            return fleetManager
        case .fleetManager:
            return driver
        case .maintenance:
            return fleetManager
        }
    }

    private var messages: [ChatMessage] {
        guard let currentUser, let recipient else { return [] }
        return appViewModel.service.chatMessages(between: currentUser.id, and: recipient.id)
    }

    private var isDriverExperience: Bool {
        currentUser?.role == .driver || currentUser?.role == .maintenance
    }

    private var accent: Color {
        isDriverExperience ? DriverTheme.accent : AppTheme.brand
    }

    private var screenBackground: Color {
        isDriverExperience ? DriverTheme.background : AppTheme.background
    }

    private var primaryText: Color {
        isDriverExperience ? DriverTheme.textPrimary : AppTheme.textPrimary
    }

    private var secondaryText: Color {
        isDriverExperience ? DriverTheme.textSecondary : AppTheme.textSecondary
    }

    var body: some View {
        VStack(spacing: 0) {
            if let recipient {
                conversationHeader(recipient: recipient)
            }

            if recipient == nil {
                unavailableState
            } else if messages.isEmpty {
                emptyState
            } else {
                messagesList
            }

            Divider().foregroundStyle(AppTheme.border)
            inputBar
        }
        .background(screenBackground.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await appViewModel.service.syncChatMessages()
                if let currentUser, let recipient {
                    appViewModel.service.markChatMessagesRead(between: currentUser.id, and: recipient.id)
                }
            }
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task { @MainActor in
                    await appViewModel.service.syncChatMessages()
                    if let currentUser, let recipient {
                        appViewModel.service.markChatMessagesRead(between: currentUser.id, and: recipient.id)
                    }
                }
            }
        }
        .onDisappear {
            pollTimer?.invalidate()
            pollTimer = nil
            if speech.isRecording {
                speech.cancelRecording()
            }
        }
        .onChange(of: speech.partialTranscript) { _, newValue in
            if speech.isRecording {
                messageText = newValue
            }
        }
        .alert("Voice message", isPresented: $showSpeechError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(speech.errorMessage ?? "Could not record your message.")
        }
    }

    private var navigationTitle: String {
        if currentUser?.role == .fleetManager, let driver {
            return driver.name
        }
        return "Fleet Manager"
    }

    private func conversationHeader(recipient: User) -> some View {
        let vehicle = driver.flatMap { driver in
            appViewModel.service.vehicles.first { $0.assignedDriverID == driver.id }
        }

        return HStack(spacing: 12) {
            AvatarView(name: recipient.name, size: 44, customColor: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipient.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(primaryText)

                Text(headerSubtitle(for: recipient, vehicle: vehicle))
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isDriverExperience ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppTheme.surface))
        .overlay(alignment: .bottom) {
            Divider().foregroundStyle(AppTheme.border)
        }
    }

    private func headerSubtitle(for recipient: User, vehicle: Vehicle?) -> String {
        if recipient.role == .fleetManager {
            return recipient.title.isEmpty ? "Fleet Manager" : recipient.title
        }
        if let vehicle {
            return "\(vehicle.displayName) - \(vehicle.plateNumber)"
        }
        return recipient.title.isEmpty ? "Driver" : recipient.title
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(0..<messages.count, id: \.self) { index in
                        let message = messages[index]
                        let prevMessage = index > 0 ? messages[index - 1] : nil
                        let nextMessage = index < messages.count - 1 ? messages[index + 1] : nil
                        
                        // Show sender info if:
                        // 1. It's not sent by current user
                        // 2. It's the first message, OR the previous message was from a different sender, OR the time difference is > 1 min
                        let showSenderInfo = message.senderID != currentUser?.id &&
                            (prevMessage == nil || prevMessage?.senderID != message.senderID || message.timestamp.timeIntervalSince(prevMessage!.timestamp) > 60)
                        
                        // Show timestamp if next message is from a different sender, OR next message is > 1 min later
                        let showTimestamp = nextMessage == nil || nextMessage?.senderID != message.senderID || nextMessage!.timestamp.timeIntervalSince(message.timestamp) > 60
                        
                        chatBubble(message, showSenderInfo: showSenderInfo, showTimestamp: showTimestamp)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                if let currentUser, let recipient {
                    appViewModel.service.markChatMessagesRead(between: currentUser.id, and: recipient.id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 42))
                .foregroundStyle(accent.opacity(0.35))

            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(primaryText)

            Text("Type a message or tap the microphone to speak. Your words are converted to text and sent to the fleet manager.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(secondaryText.opacity(0.5))

            Text("No conversation available")
                .font(.headline)
                .foregroundStyle(primaryText)

            Text("A driver and fleet manager are required before a direct chat can begin.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if isDriverExperience && speech.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Listening… speak your message")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text("Tap mic to send")
                        .font(.caption2)
                        .foregroundStyle(secondaryText)
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 12) {
                if isDriverExperience {
                    Button {
                        Task { await toggleVoiceRecording() }
                    } label: {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(speech.isRecording ? .red : accent)
                            .frame(width: 40, height: 40)
                            .background(
                                (speech.isRecording ? Color.red.opacity(0.15) : accent.opacity(0.12)),
                                in: Circle()
                            )
                            .symbolEffect(.pulse, isActive: speech.isRecording)
                    }
                    .accessibilityLabel(speech.isRecording ? "Stop recording and send" : "Record voice message")
                }

                TextField(
                    speech.isRecording ? "Listening…" : "Type a message...",
                    text: $messageText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
                )
                .foregroundStyle(primaryText)
                .disabled(speech.isRecording)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : accent)
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recipient == nil || speech.isRecording)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(UIColor.systemBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -3)
        )
    }

    private func chatBubble(_ message: ChatMessage, showSenderInfo: Bool, showTimestamp: Bool) -> some View {
        let isSent = message.senderID == currentUser?.id
        let sender = appViewModel.service.users.first { $0.id == message.senderID }
        let isSameSenderAsNext = messages.firstIndex(of: message).map { idx in
            guard idx < messages.count - 1 else { return false }
            let next = messages[idx + 1]
            return next.senderID == message.senderID && next.timestamp.timeIntervalSince(message.timestamp) <= 60
        } ?? false

        return HStack(alignment: .bottom, spacing: 8) {
            if isSent {
                Spacer(minLength: 54)
            }

            if !isSent {
                if showSenderInfo {
                    AvatarView(name: sender?.name ?? "User", size: 30, customColor: accent)
                } else {
                    Color.clear
                        .frame(width: 30, height: 30)
                }
            }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.message)
                    .font(.system(size: 15))
                    .foregroundStyle(isSent ? .white : primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSent ? accent : AppTheme.surfaceSecondary)
                    )

                if showTimestamp {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(secondaryText)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
            }

            if !isSent {
                Spacer(minLength: 54)
            }
        }
        .padding(.bottom, isSameSenderAsNext ? 0 : 8)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let currentUser, let recipient, !trimmed.isEmpty else { return }

        appViewModel.service.sendChatMessage(
            senderID: currentUser.id,
            receiverID: recipient.id,
            message: trimmed
        )
        messageText = ""
    }

    private func toggleVoiceRecording() async {
        if speech.isRecording {
            let transcript = speech.stopRecording()
            messageText = transcript
            guard !transcript.isEmpty else { return }
            sendMessage()
            return
        }

        guard await speech.requestPermissions() else {
            showSpeechError = true
            return
        }

        guard speech.isAvailable else {
            speech.errorMessage = SpeechTranscriptionError.recognizerUnavailable.errorDescription
            showSpeechError = true
            return
        }

        do {
            try await speech.startRecording()
        } catch {
            speech.errorMessage = error.localizedDescription
            showSpeechError = true
        }
    }
}

#Preview {
    MaintenanceChatView()
        .environment(AppViewModel())
}
