import SwiftUI

struct DriverProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    @State private var showDefectSheet = false
    @State private var showChatSheet = false
    @State private var showLogoutAlert = false

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeader
                    vehicleCard
                    contactInfo
                    safetyScore
                    tripHistory
                    settingsSection
                    logoutButton
                }
                .padding(20)
            }
            .background(DriverTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showDefectSheet) {
                DefectReportView()
                    .environment(appViewModel)
            }
            .sheet(isPresented: $showChatSheet) {
                MaintenanceChatView()
                    .environment(appViewModel)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Log Out", role: .destructive) {
                    dismiss()
                    appViewModel.logout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .presentationDetents([.large])
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DriverTheme.accent)
                    .frame(width: 80, height: 80)
                Text(driverVM.driverInitials(currentUser))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            if let user = currentUser {
                Text(user.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)

                Text("Licence: DL-0420231234567")
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)
            }
        }
    }

    private var vehicleCard: some View {
        DriverGlassCard {
            if let vehicle = assignedVehicle {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DriverTheme.cardFill)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DriverTheme.accent.opacity(0.6))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.plateNumber)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(vehicle.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(vehicle.status.rawValue)
                                .font(.system(size: 12))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var contactInfo: some View {
        DriverGlassCard {
            VStack(spacing: 12) {
                if let user = currentUser {
                    profileRow(icon: "envelope.fill", label: "Email", value: user.email)
                    Divider().foregroundStyle(DriverTheme.separator)
                    profileRow(icon: "phone.fill", label: "Phone", value: user.phone)
                    Divider().foregroundStyle(DriverTheme.separator)
                    profileRow(icon: "building.2.fill", label: "Organization", value: appViewModel.organizationName)
                }
            }
        }
    }

    private var safetyScore: some View {
        DriverGlassCard {
            HStack(spacing: 20) {
                ZStack {
                    CircularProgressRing(
                        progress: 0.92,
                        size: 80,
                        strokeWidth: 8
                    )
                    Text("92")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Score")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text("Excellent driving record")
                        .font(.system(size: 13))
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var tripHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip History")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            if let user = currentUser {
                let allTrips = appViewModel.service.trips(for: user.id)
                ForEach(allTrips.prefix(5)) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        DriverGlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(trip.origin) → \(trip.destination)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DriverTheme.textPrimary)
                                    Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 13))
                                        .foregroundStyle(DriverTheme.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(Int(trip.distanceKM)) km")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DriverTheme.textPrimary)
                                    Text(trip.status.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(trip.status == .completed ? DriverTheme.successGreen : trip.status == .inProgress ? DriverTheme.accent : DriverTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            DriverGlassCard {
                VStack(spacing: 0) {
                    settingsRow(icon: "bell.fill", title: "Notifications") { }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "lock.fill", title: "Change Password") { }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "globe", title: "Language") { }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "wrench.fill", title: "Report Defect") {
                        showDefectSheet = true
                    }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "message.fill", title: "Maintenance Chat") {
                        showChatSheet = true
                    }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "info.circle.fill", title: "About") { }
                }
            }
        }
    }

    private var logoutButton: some View {
        Button("Log Out") {
            showLogoutAlert = true
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(DriverTheme.criticalRed)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DriverTheme.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(DriverTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(DriverTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DriverTheme.accent)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(DriverTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    DriverProfileView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
