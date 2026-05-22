import SwiftUI
import Combine

struct DriverShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }
    
    private var shift: ShiftInfo? {
        currentUser.flatMap { appViewModel.service.currentShift(for: $0.id) }
    }

    // Toggle binding for Duty Status
    private var isOnDutyBinding: Binding<Bool> {
        Binding(
            get: {
                guard let user = currentUser else { return false }
                return appViewModel.service.dutyStatus(for: user.id) == .onDuty
            },
            set: { newValue in
                guard let user = currentUser else { return }
                appViewModel.service.toggleDutyStatus(for: user.id)
                // Trigger view model refresh if needed
                driverVM.objectWillChange.send()
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Assigned Vehicle Card
                assignedVehicleCard

                // 2. Shift Timings & Circular Ring Card
                shiftTimingsCard

                // 3. On Duty Toggle Switch
                onDutyToggleCard

                // 4. Week Calendar view
                weekCalendarCard

                // 5. Upcoming Shifts
                upcomingShiftsSection
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("My Shift")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Assigned Vehicle Card

    private var assignedVehicleCard: some View {
        DriverGlassCard {
            if let vehicle = assignedVehicle {
                HStack(spacing: 16) {
                    // Vehicle Photo
                    Image("truck_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 75)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(vehicle.plateNumber)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        
                        Text(vehicle.displayName)
                            .font(.system(size: 14))
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        // Status Pill
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(vehicle.status.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(vehicle.status == .active ? DriverTheme.successGreen : DriverTheme.textSecondary)
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text("No Vehicle Assigned")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Shift Timings & Circular Ring Card

    private var shiftTimingsCard: some View {
        DriverGlassCard {
            HStack(spacing: 20) {
                // Times
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        Text(shift?.startTime.formatted(date: .omitted, time: .shortened) ?? "6:00 AM")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("End")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        Text(shift?.endTime.formatted(date: .omitted, time: .shortened) ?? "6:00 PM")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Break")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        Text(shift?.breakTime?.formatted(date: .omitted, time: .shortened) ?? "12:00 PM")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Shift Progress Ring
                let progress = shift?.progress ?? 0.65
                let totalHours = shift?.totalHours ?? 12.0
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 12)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                            .stroke(
                                DriverTheme.accentGradient,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 120, height: 120)

                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            Text("\(Int(totalHours))h")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - On Duty Toggle Card

    private var onDutyToggleCard: some View {
        HStack {
            Text("On Duty")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: isOnDutyBinding)
                .labelsHidden()
                .tint(DriverTheme.successGreen)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
    }

    // MARK: - Week Calendar Card

    private var weekCalendarCard: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
        
        // Let's build 7 days centered or starting from sunday
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        
        let driverShifts = currentUser.map { user in
            appViewModel.service.shifts.filter { $0.driverID == user.id }
        } ?? []
        let hasShiftOnDay: (Date) -> Bool = { targetDate in
            driverShifts.contains { calendar.isDate($0.date, inSameDayAs: targetDate) }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { idx in
                    let date = days[idx]
                    let dayNum = calendar.component(.day, from: date)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    
                    VStack(spacing: 8) {
                        Text(weekdaySymbols[idx])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        Text("\(dayNum)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isToday ? .white : DriverTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(isToday ? Circle().fill(DriverTheme.accent) : Circle().fill(Color.clear))
                        
                        // Shift indicator dot
                        Circle()
                            .fill(hasShiftOnDay(date) ? DriverTheme.accent : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
        }
    }

    // MARK: - Upcoming Shifts Section

    private var upcomingShiftsSection: some View {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let driverShifts = currentUser.map { user in
            appViewModel.service.shifts.filter { $0.driverID == user.id }
        } ?? []
        let upcomingShifts = driverShifts.filter { $0.date > todayStart }
            .sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Shifts")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            if upcomingShifts.isEmpty {
                Text("No upcoming shifts scheduled")
                    .font(.system(size: 14))
                    .foregroundStyle(DriverTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcomingShifts) { shift in
                            let dayString = shift.date.formatted(.dateTime.weekday(.abbreviated).day())
                            let timeString = shift.startTime.formatted(date: .omitted, time: .shortened)
                            upcomingShiftCard(day: dayString, time: timeString, status: "Assigned")
                        }
                    }
                }
            }
        }
    }

    private func upcomingShiftCard(day: String, time: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)
            
            Text(time)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DriverTheme.textSecondary)
            
            Text(status)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DriverTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(DriverTheme.accent.opacity(0.15)))
        }
        .padding(16)
        .frame(width: 130, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
    }
}

#Preview {
    NavigationStack {
        DriverShiftDetailView()
            .environmentObject(AppViewModel())
            .environmentObject(driverVMPreview)
    }
}

private var driverVMPreview: DriverViewModel {
    let vm = DriverViewModel()
    return vm
}
