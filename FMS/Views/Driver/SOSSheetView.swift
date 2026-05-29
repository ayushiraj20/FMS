import SwiftUI

struct SOSSheetView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Pure black background for high contrast, night-vision preservation, and battery saving in emergencies.
            Color.black.ignoresSafeArea()
            
            // Pulsing background emergency aura
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
    }

    private var countdownView: some View {
        VStack(spacing: 40) {
            // Top Cancel bar
            HStack {
                Spacer()
                Button {
                    driverVM.cancelSOS()
                } label: {
                    Text("Cancel")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title2)
                    Text("EMERGENCY")
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                }
                .foregroundStyle(.white)
                .shadow(color: Color.red.opacity(0.6), radius: 10, x: 0, y: 0)

                Text("Alert will be sent in")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            // SELECT EMERGENCY TYPE SELECTOR
            VStack(spacing: 8) {
                Text("TAP TO CHANGE CATEGORY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                
                HStack(spacing: 16) {
                    emergencyTypeButton(title: "Accident", icon: "car.2.fill")
                    emergencyTypeButton(title: "Medical", icon: "heart.text.square.fill")
                    emergencyTypeButton(title: "Breakdown", icon: "wrench.adjustable.fill")
                    emergencyTypeButton(title: "Security", icon: "shield.fill")
                }
            }
            .padding(.horizontal, 20)

            // Countdown ring
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

                VStack(spacing: 4) {
                    Text("\(driverVM.sosCountdown)")
                        .font(.system(size: 70, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            .shadow(color: Color.red.opacity(0.3), radius: 25, y: 0)

            Text("Tap Cancel to abort")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Button {
                driverVM.triggerSOS(service: appViewModel.service, user: appViewModel.currentUser)
            } label: {
                Text("Send Now")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(DriverTheme.criticalRed, in: Capsule())
                    .shadow(color: DriverTheme.criticalRed.opacity(0.4), radius: 15, y: 5)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var confirmedView: some View {
        VStack(spacing: 32) {
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

            VStack(spacing: 12) {
                Text("SOS Sent")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("Help is on the way")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Fleet Manager has been notified with your exact location.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                driverVM.cancelSOS()
            } label: {
                Text("Close")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SOSSheetView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
