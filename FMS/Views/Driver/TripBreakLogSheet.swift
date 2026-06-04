import SwiftUI
import MapKit

struct TripBreakLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let trip: Trip?

    @State private var selectedBreakType = "Fuel Stop"
    let breakTypes = [
        ("Fuel Stop", "fuelpump.fill"),
        ("Rest Break", "moon.fill"),
        ("Meal Break", "fork.knife"),
        ("Other", "ellipsis.circle.fill")
    ]

    // Duration picker
    @State private var durationMinutes: Int = 15
    let durationOptions = Array(stride(from: 5, through: 120, by: 5))

    // Refuel sheet
    @State private var showRefuelSheet = false

    private var currentUser: User? { appViewModel.currentUser }

    private var todayBreaks: [BreakLogEntry] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.breakLogs.filter {
            $0.driverID == user.id && Calendar.current.isDateInToday($0.startTime)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Break Log")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(Color.primary)

                                if let trip = trip {
                                    Text("Trip #\(String(trip.id.uuidString.prefix(4)).uppercased())")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Break Duration:")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)

                                Picker("Duration", selection: $durationMinutes) {
                                    ForEach(durationOptions, id: \.self) { min in
                                        Text("\(min) min").tag(min)
                                    }
                                }
                                .tint(DriverTheme.accent)
                                .background(DriverTheme.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)

                        // Break Types Grid
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 16
                        ) {
                            ForEach(breakTypes, id: \.0) { type, icon in
                                Button {
                                    withAnimation { selectedBreakType = type }
                                } label: {
                                    VStack(spacing: 12) {
                                        Image(systemName: icon)
                                            .font(.system(size: 28))
                                            .foregroundStyle(
                                                selectedBreakType == type
                                                    ? DriverTheme.accent
                                                    : Color.gray
                                            )

                                        Text(type)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(
                                                selectedBreakType == type
                                                    ? Color.primary
                                                    : Color.gray
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                selectedBreakType == type
                                                    ? DriverTheme.accent.opacity(0.1)
                                                    : Color(uiColor: .secondarySystemBackground)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedBreakType == type
                                                    ? DriverTheme.accent
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        // Fuel Stop — Refuel Button
                        if selectedBreakType == "Fuel Stop" {
                            Button {
                                showRefuelSheet = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "fuelpump.fill")
                                    Text("Refuel Vehicle")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(DriverTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DriverTheme.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }

                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Auto-captured Location")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)

                            HStack(spacing: 12) {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(DriverTheme.accent)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(DriverTheme.accent.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text("NH48, Lonavala")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .padding(.horizontal)

                        // Today's Breaks
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Breaks")
                                .font(.headline)
                                .padding(.horizontal)

                            if todayBreaks.isEmpty {
                                Text("No breaks taken today.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(todayBreaks) { brk in
                                    HStack(spacing: 12) {
                                        Text(brk.startTime.formatted(date: .omitted, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundStyle(Color.secondary)
                                            .frame(width: 70, alignment: .leading)

                                        Circle()
                                            .fill(
                                                brk.breakType == "Fuel Stop"
                                                    ? DriverTheme.accent
                                                    : Color.gray
                                            )
                                            .frame(width: 8, height: 8)

                                        Text(brk.breakType)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.primary)

                                        Spacer()

                                        if let endTime = brk.endTime {
                                            let diff = Int(endTime.timeIntervalSince(brk.startTime) / 60)
                                            Text("\(diff)min")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.secondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }

                // Bottom Button
                VStack {
                    Spacer()
                    Button {
                        logBreakAndDismiss()
                    } label: {
                        Text("Break Log")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(DriverTheme.accent))
                            .shadow(color: DriverTheme.accent.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .systemBackground).opacity(0),
                                Color(uiColor: .systemBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showRefuelSheet) {
                if let user = appViewModel.currentUser,
                   let vehicleID = user.assignedVehicleID {
                    RefuelVehicleView(
                        vehicleID: vehicleID,
                        driverID: user.id,
                        tripID: trip?.id,
                        repo: FuelRepository(
                            service: FuelService(
                                client: SupabaseService.shared.client
                            )
                        )
                    )
                }
            }
        }
    }

    private func logBreakAndDismiss() {
        guard let user = appViewModel.currentUser else { return }
        appViewModel.service.addBreakLog(
            driverID: user.id,
            breakType: selectedBreakType,
            durationMinutes: durationMinutes
        )
        dismiss()
    }
}
