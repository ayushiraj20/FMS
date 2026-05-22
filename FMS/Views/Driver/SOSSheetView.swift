import SwiftUI

struct SOSSheetView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    var body: some View {
        ZStack {
            DriverTheme.criticalRed.ignoresSafeArea()

            if driverVM.sosConfirmed {
                confirmedView
            } else {
                countdownView
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 40) {
            HStack {
                Spacer()
                Button {
                    driverVM.cancelSOS()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("SOS")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)

            Text("Emergency alert will be sent in")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.8))

            // Countdown ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(driverVM.sosCountdown) / 10.0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: driverVM.sosCountdown)

                Text("\(driverVM.sosCountdown)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Tap Cancel to abort")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Button("Send Now") {
                driverVM.triggerSOS(service: appViewModel.service, user: appViewModel.currentUser)
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(DriverTheme.criticalRed)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Capsule().fill(.white))
            .padding(.bottom, 40)
        }
    }

    private var confirmedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)

            Text("SOS Confirmed")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Help is on the way")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.8))

            Text("Fleet Manager has been notified")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Button("Close") {
                driverVM.cancelSOS()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DriverTheme.criticalRed)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Capsule().fill(.white))
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    SOSSheetView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
