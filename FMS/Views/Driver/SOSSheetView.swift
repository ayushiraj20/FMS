import SwiftUI
import UIKit

struct SOSSheetView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    @State private var isPulsing = false
    @State private var holdProgress: Double = 0
    @State private var holdTimer: Timer?

    private let holdDuration: TimeInterval = 1.5

    private var fleetManagerPhone: String? {
        let orgID = appViewModel.currentUser?.organizationID
        return appViewModel.service.users.first {
            $0.role == .fleetManager && (orgID == nil || $0.organizationID == orgID)
        }?.phone
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !driverVM.sosConfirmed {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .scaleEffect(isPulsing ? 1.2 : 0.8)
                    .blur(radius: 30)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            }

            if driverVM.sosConfirmed {
                confirmedView
                    .transition(.scale.combined(with: .opacity))
            } else {
                countdownView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: driverVM.sosConfirmed)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            cancelHold()
        }
    }

    private var countdownView: some View {
        VStack(spacing: 28) {
            HStack {
                Spacer()
                Button {
                    driverVM.cancelSOS()
                } label: {
                    Text("Cancel")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                }
                .accessibilityLabel("Cancel SOS")
                .accessibilityHint("Aborts the emergency alert before it is sent.")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title2)
                    Text("EMERGENCY")
                        .font(.largeTitle.weight(.heavy))
                }
                .foregroundStyle(.white)
                .shadow(color: Color.red.opacity(0.6), radius: 10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Text("Alert will be sent in")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(spacing: 8) {
                Text("TAP TO CHANGE CATEGORY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 16) {
                    emergencyTypeButton(title: "Accident", icon: "car.2.fill")
                    emergencyTypeButton(title: "Medical", icon: "heart.text.square.fill")
                    emergencyTypeButton(title: "Breakdown", icon: "wrench.adjustable.fill")
                    emergencyTypeButton(title: "Security", icon: "shield.fill")
                }
            }
            .padding(.horizontal, 20)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(driverVM.sosCountdown) / 5.0)
                    .stroke(DriverTheme.criticalRed, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: driverVM.sosCountdown)

                Text("\(driverVM.sosCountdown)")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Countdown: \(driverVM.sosCountdown) seconds remaining before SOS is sent")

            descriptionField

            Spacer(minLength: 12)

            holdToSendButton
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
    }

    private var descriptionField: some View {
        TextField(
            "",
            text: Binding(
                get: { driverVM.sosDescription },
                set: { driverVM.sosDescription = $0 }
            ),
            prompt: Text("Describe the situation (optional)")
                .foregroundStyle(.white.opacity(0.5))
        )
        .textInputAutocapitalization(.sentences)
        .submitLabel(.done)
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .accessibilityLabel("Emergency description")
        .accessibilityHint("Optional details that will be sent to the fleet manager.")
    }

    private var holdToSendButton: some View {
        ZStack {
            Capsule().fill(DriverTheme.criticalRed.opacity(0.35))

            GeometryReader { geo in
                Capsule()
                    .fill(DriverTheme.criticalRed)
                    .frame(width: geo.size.width * holdProgress)
            }
            .clipShape(Capsule())

            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                Text(holdProgress > 0 ? "Keep holding…" : "Hold to Send")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(.white)
        }
        .frame(height: 64)
        .shadow(color: DriverTheme.criticalRed.opacity(0.4), radius: 15, y: 5)
        .gesture(
            LongPressGesture(minimumDuration: holdDuration)
                .onChanged { _ in startHold() }
                .onEnded { _ in
                    completeHold()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in
                    if holdProgress < 1 { cancelHold() }
                }
        )
        .accessibilityLabel("Send SOS")
        .accessibilityHint("Press and hold for one and a half seconds to dispatch the emergency alert immediately.")
        .accessibilityAddTraits(.isButton)
    }

    private var confirmedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 10)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(Color.green)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("SOS Sent")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("Help is on the way")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.95))

                Text("Fleet Manager has been notified with your exact location.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            quickActionRow

            Spacer()

            Button {
                driverVM.cancelSOS()
            } label: {
                Text("Close")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
            .accessibilityLabel("Close emergency screen")
        }
    }

    @ViewBuilder
    private var quickActionRow: some View {
        if let phone = fleetManagerPhone,
           let telURL = URL(string: "tel://\(phoneDigits(phone))"),
           let smsURL = URL(string: "sms:\(phoneDigits(phone))") {
            HStack(spacing: 12) {
                Link(destination: telURL) {
                    quickActionLabel(icon: "phone.fill", title: "Call Manager", tint: .green)
                }
                .accessibilityLabel("Call fleet manager")

                Link(destination: smsURL) {
                    quickActionLabel(icon: "message.fill", title: "Text Manager", tint: .blue)
                }
                .accessibilityLabel("Text fleet manager")
            }
            .padding(.horizontal, 24)
        }
    }

    private func quickActionLabel(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(tint.opacity(0.85), in: Capsule())
    }

    private func phoneDigits(_ phone: String) -> String {
        phone.filter { "0123456789+".contains($0) }
    }

    private func emergencyTypeButton(title: String, icon: String) -> some View {
        let isSelected = driverVM.selectedEmergencyType == title
        return Button {
            withAnimation(.spring()) {
                driverVM.selectedEmergencyType = title
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.red : Color.white.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(isSelected ? 0.3 : 0.0), lineWidth: 1))

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) emergency type")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Hold to send

    private func startHold() {
        guard holdTimer == nil, !driverVM.sosConfirmed else { return }
        let start = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(1, elapsed / holdDuration)
            Task { @MainActor in
                holdProgress = progress
                if progress >= 1 {
                    holdTimer?.invalidate()
                    holdTimer = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    driverVM.triggerSOS(service: appViewModel.service, user: appViewModel.currentUser)
                }
            }
        }
    }

    private func completeHold() {
        if holdProgress >= 1 {
            holdProgress = 0
            holdTimer?.invalidate()
            holdTimer = nil
        } else {
            cancelHold()
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0
        }
    }
}

#Preview {
    SOSSheetView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
