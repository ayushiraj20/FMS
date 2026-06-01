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
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { msg in
                                    chatBubble(msg)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isSent = message.senderID == currentUser?.id

        return HStack {
            if isSent { Spacer(minLength: 40) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(isSent ? .white : DriverTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isSent ? AnyShapeStyle(DriverTheme.accent) : AnyShapeStyle(.regularMaterial),
                        in: CustomCorners(corners: isSent ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight], radius: 20)
                    )

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            .scrollTransition { content, phase in
                content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
            }

            if !isSent { Spacer(minLength: 40) }
        }
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
            return appViewModel.service.users.first { $0.id == driverID && $0.role == .driver }
        }
        return currentUser?.role == .driver ? currentUser : nil
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
            return nil
        }
    }

    private var messages: [ChatMessage] {
        guard let currentUser, let recipient else { return [] }
        return appViewModel.service.chatMessages(between: currentUser.id, and: recipient.id)
    }

    private var isDriverExperience: Bool {
        currentUser?.role == .driver
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
            }
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task {
                    await appViewModel.service.syncChatMessages()
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

            Image(systemName: "message.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.12), in: Circle())
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
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        chatBubble(message)
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(speech.isRecording ? .red : accent)
                            .frame(width: 44, height: 44)
                            .background(
                                (speech.isRecording ? Color.red.opacity(0.12) : accent.opacity(0.12)),
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
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isDriverExperience ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(AppTheme.surfaceSecondary), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .foregroundStyle(primaryText)
                .disabled(speech.isRecording)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(accent, in: Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recipient == nil || speech.isRecording)
                .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recipient == nil || speech.isRecording ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isDriverExperience ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppTheme.surface))
    }

    private func chatBubble(_ message: ChatMessage) -> some View {
        let isSent = message.senderID == currentUser?.id
        let sender = appViewModel.service.users.first { $0.id == message.senderID }

        return HStack(alignment: .bottom, spacing: 8) {
            if isSent {
                Spacer(minLength: 54)
            }

            if !isSent {
                AvatarView(name: sender?.name ?? "User", size: 30, customColor: accent)
            }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                if !isSent {
                    Text(sender?.name ?? "Team Member")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                        .padding(.horizontal, 4)
                }

                Text(message.message)
                    .font(.system(size: 15))
                    .foregroundStyle(isSent ? .white : primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSent ? accent : (isDriverExperience ? Color.white.opacity(0.72) : AppTheme.surfaceSecondary))
                    )

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(secondaryText)
                    .padding(.horizontal, 4)
            }

            if !isSent {
                Spacer(minLength: 54)
            }
        }
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
