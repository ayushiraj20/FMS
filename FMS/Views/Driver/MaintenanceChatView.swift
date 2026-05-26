import SwiftUI

struct MaintenanceChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
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

#Preview {
    MaintenanceChatView()
        .environment(AppViewModel())
}
