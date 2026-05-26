import SwiftUI

struct SOSSheetView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    var body: some View {
        ZStack {
            DriverTheme.criticalRed.ignoresSafeArea()
            
            GeometryReader { geo in
                Circle()
                    .fill(.red.opacity(0.8))
                    .frame(width: geo.size.width)
                    .blur(radius: 60)
                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.1)
                
                Circle()
                    .fill(.orange.opacity(0.5))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
            }.ignoresSafeArea()

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
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 12) {
                Text("EMERGENCY")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)

                Text("Alert will be sent in")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: CGFloat(driverVM.sosCountdown) / 10.0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: driverVM.sosCountdown)

                VStack(spacing: 4) {
                    Text("\(driverVM.sosCountdown)")
                        .font(.system(size: 80, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

            Text("Tap Cancel to abort")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button {
                driverVM.triggerSOS(service: appViewModel.service, user: appViewModel.currentUser)
            } label: {
                Text("Send Now")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.criticalRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(.white, in: Capsule())
                    .shadow(color: .white.opacity(0.3), radius: 15, y: 5)
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
                    .fill(.white.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }

            VStack(spacing: 12) {
                Text("SOS Sent")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("Help is on the way")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

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
                    .foregroundStyle(DriverTheme.criticalRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(.white, in: Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    SOSSheetView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
