import SwiftUI

struct MaintenanceChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var messageText = ""

    private var currentUser: User? { appViewModel.currentUser }

    private var messages: [ChatMessage] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.chatMessages(for: user.id)
    }

    private var maintenanceUser: User? {
        appViewModel.service.users(for: .maintenance).first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastID = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider().foregroundStyle(DriverTheme.separator)

                // Input bar
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText)
                        .font(.system(size: 15))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(DriverTheme.cardFill)
                        )

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(DriverTheme.accent))
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(DriverTheme.background)
            }
            .background(DriverTheme.background.ignoresSafeArea())
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
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                Text(message.message)
                    .font(.system(size: 15))
                    .foregroundStyle(isSent ? .white : DriverTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSent ? DriverTheme.accent : DriverTheme.cardFill)
                    )

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(DriverTheme.textSecondary)
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }

    private func sendMessage() {
        guard let user = currentUser,
              let receiver = maintenanceUser,
              !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        appViewModel.service.sendChatMessage(
            senderID: user.id,
            receiverID: receiver.id,
            message: messageText
        )
        messageText = ""
    }
}

#Preview {
    MaintenanceChatView()
        .environmentObject(AppViewModel())
}
