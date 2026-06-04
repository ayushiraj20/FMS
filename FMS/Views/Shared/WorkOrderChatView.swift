import SwiftUI

struct WorkOrderChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    
    var workOrderID: UUID? = nil
    var defectReportID: UUID? = nil
    var onManage: (() -> Void)? = nil
    @State private var messageText = ""
    @State private var pollTimer: Timer? = nil
    
    private var currentUser: User? {
        appViewModel.currentUser
    }
    
    private var workOrder: WorkOrder? {
        guard let wID = workOrderID else { return nil }
        return appViewModel.service.workOrders.first { $0.id == wID }
    }
    
    private var defectReport: DefectReport? {
        guard let dID = defectReportID else { return nil }
        return appViewModel.service.defects.first { $0.id == dID }
    }
    
    /// True when the view was opened for a defect report (before a work order exists)
    private var isDefectMode: Bool {
        defectReportID != nil && workOrderID == nil
    }
    
    private var messages: [ChatMessage] {
        if let dID = defectReportID {
            return appViewModel.service.chatMessages(forDefect: dID)
        } else if let wID = workOrderID {
            return appViewModel.service.chatMessages(forWorkOrder: wID)
        }
        return []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header Info Card
            // -- Header: Work Order or Defect Report info --
            if isDefectMode, let defect = defectReport {
                let vehicle = appViewModel.service.vehicle(for: defect.vehicleID)
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(defect.title ?? "Defect Report")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text("Vehicle: \(vehicle?.displayName ?? "Unknown") (\(vehicle?.plateNumber ?? "N/A"))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    StatusBadgeView(
                        text: defect.status.rawValue,
                        color: defect.status == .completed ? AppTheme.success : .orange
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .overlay(
                    VStack {
                        Spacer()
                        Divider().foregroundStyle(AppTheme.border)
                    }
                )
            } else if let order = workOrder {
                let vehicle = appViewModel.service.vehicle(for: order.vehicleID)
                
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.brand.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text("Vehicle: \(vehicle?.displayName ?? "Unknown") (\(vehicle?.plateNumber ?? "N/A"))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    StatusBadgeView(
                        text: order.status.rawValue,
                        color: order.status == .completed ? AppTheme.success : AppTheme.warning
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .overlay(
                    VStack {
                        Spacer()
                        Divider().foregroundStyle(AppTheme.border)
                    }
                )
            }
            
            // Messages List
            if messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "message.and.waveform.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    Text("No coordination messages yet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Type a message below to start coordinating between Manager, Technician, and Driver.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(0..<messages.count, id: \.self) { index in
                                let msg = messages[index]
                                let prevMessage = index > 0 ? messages[index - 1] : nil
                                let nextMessage = index < messages.count - 1 ? messages[index + 1] : nil
                                
                                let showSenderInfo = msg.senderID != currentUser?.id &&
                                    (prevMessage == nil || prevMessage?.senderID != msg.senderID || msg.timestamp.timeIntervalSince(prevMessage!.timestamp) > 60)
                                
                                let showTimestamp = nextMessage == nil || nextMessage?.senderID != msg.senderID || nextMessage!.timestamp.timeIntervalSince(msg.timestamp) > 60
                                
                                let isSameSenderAsNext = nextMessage != nil && nextMessage?.senderID == msg.senderID && nextMessage!.timestamp.timeIntervalSince(msg.timestamp) <= 60
                                
                                chatBubble(msg, showSenderInfo: showSenderInfo, showTimestamp: showTimestamp, isSameSenderAsNext: isSameSenderAsNext)
                                    .id(msg.id)
                            }
                        }
                        .padding(16)
                    }
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
            
            Divider().foregroundStyle(AppTheme.border)
            
            // Input Bar
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppTheme.brand))
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(isDefectMode ? "Defect Chat" : "Repair Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage") {
                        onManage()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .onAppear {
            // Initial sync on load
            Task {
                await appViewModel.service.syncChatMessages()
            }
            
            // Poll for new coordination messages every 2.0 seconds while chat is active
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                Task {
                    await appViewModel.service.syncChatMessages()
                }
            }
        }
        .onDisappear {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
    
    private func chatBubble(_ message: ChatMessage, showSenderInfo: Bool, showTimestamp: Bool, isSameSenderAsNext: Bool) -> some View {
        guard let currentUserID = currentUser?.id else { return AnyView(EmptyView()) }
        let isSent = message.senderID == currentUserID
        
        let senderUser = appViewModel.service.users().first { $0.id == message.senderID }
        let senderName = senderUser?.name ?? "Team Member"
        let role = senderUser?.role ?? .driver
        
        return AnyView(
            HStack(alignment: .bottom, spacing: 8) {
                if isSent { Spacer(minLength: 60) }
                
                if !isSent {
                    if showSenderInfo {
                        initialsAvatar(name: senderName, role: role)
                            .padding(.bottom, 2)
                    } else {
                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
                
                VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                    if !isSent && showSenderInfo {
                        HStack(spacing: 6) {
                            Text(senderName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            roleTag(role)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }
                    
                    Text(message.message)
                        .font(.system(size: 15))
                        .foregroundStyle(isSent ? .white : AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSent ? AppTheme.brand : AppTheme.surfaceSecondary)
                        )
                    
                    if showTimestamp {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                    }
                }
                
                if !isSent { Spacer(minLength: 60) }
            }
            .padding(.bottom, isSameSenderAsNext ? 0 : 8)
        )
    }
    
    private func initialsAvatar(name: String, role: UserRole) -> some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        return Text(initials)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(roleColor(role))
            .clipShape(Circle())
    }
    
    private func roleTag(_ role: UserRole) -> some View {
        let title: String = {
            switch role {
            case .fleetManager: return "Manager"
            case .maintenance: return "Technician"
            case .driver: return "Driver"
            }
        }()
        
        return Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleColor(role))
            .clipShape(Capsule())
    }
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .fleetManager: return AppTheme.brand
        case .maintenance: return AppTheme.success
        case .driver: return Color.purple
        }
    }
    
    private func sendMessage() {
        guard let user = currentUser,
              !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        appViewModel.service.sendChatMessage(
            senderID: user.id,
            receiverID: nil,
            message: messageText,
            workOrderID: workOrderID,
            defectReportID: defectReportID
        )
        
        messageText = ""
    }
}

#Preview {
    NavigationStack {
        WorkOrderChatView(workOrderID: UUID())
            .environment(AppViewModel())
    }
}
