import SwiftUI
import Combine

// MARK: - iOS 26 Native Design Overhaul
struct DriverShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.assignedVehicle }
    
    private var shift: ShiftInfo? {
        currentUser.flatMap { appViewModel.service.currentShift(for: $0.id) }
    }

    private var isOnDutyBinding: Binding<Bool> {
        Binding(
            get: {
                guard let user = currentUser else { return false }
                return appViewModel.service.dutyStatus(for: user.id) == .onDuty
            },
            set: { _ in
                guard let user = currentUser else { return }
                appViewModel.service.toggleDutyStatus(for: user.id)
                appViewModel.refreshCurrentUser()
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                assignedVehicleCard
                shiftTimingsWidget
                onDutyToggleCard
                weekCalendarWidget
                upcomingShiftsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DriverScreenBackground())
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Assigned Vehicle Card
    private var assignedVehicleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let vehicle = assignedVehicle {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DriverTheme.accent.opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(DriverTheme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(vehicle.displayName)
                                .font(.system(.headline, design: .rounded).bold())
                                .foregroundStyle(DriverTheme.textPrimary)
                            
                            Text(vehicle.plateNumber)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(DriverTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DriverTheme.textSecondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Text(vehicle.model)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : DriverTheme.textSecondary)
                                .frame(width: 6, height: 6)
                            Text(vehicle.status.rawValue)
                                .font(.system(.caption2, design: .rounded).bold())
                                .foregroundStyle(vehicle.status == .active ? DriverTheme.successGreen : DriverTheme.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "fuelpump.fill")
                                .font(.caption2)
                            Text("\(vehicle.fuelLevel)%")
                                .font(.system(.caption, design: .rounded).bold())
                        }
                        .foregroundStyle(vehicle.fuelLevel < 20 ? DriverTheme.criticalRed : DriverTheme.textSecondary)
                        
                        Text("\(vehicle.odometer.formatted()) km")
                            .font(.system(.caption2, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(DriverTheme.textSecondary.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "truck.box.fill")
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Assigned Vehicle")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("Please contact dispatch")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DriverTheme.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Shift Timings Widget
    private var shiftTimingsWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                timingRow(label: "Start", time: shift?.startTime.formatted(date: .omitted, time: .shortened) ?? "--:--")
                timingRow(label: "Break", time: shift?.breakTime?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                timingRow(label: "End", time: shift?.endTime.formatted(date: .omitted, time: .shortened) ?? "--:--")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            let progress = shift?.progress ?? 0.0
            let totalHours = shift?.totalHours ?? 0.0
            
            ZStack {
                CircularProgressRing(progress: progress, size: 100, strokeWidth: 10)
                VStack(spacing: 2) {
                    Text(shift != nil ? "\(Int(progress * 100))%" : "--")
                        .font(.system(.title3, design: .rounded).bold())
                        .contentTransition(.numericText())
                    Text(shift != nil ? "\(Int(totalHours))h" : "--")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func timingRow(label: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriverTheme.textSecondary)
            Text(time)
                .font(.system(.headline, design: .rounded).bold())
        }
    }

    // MARK: - On Duty Toggle Card
    private var onDutyToggleCard: some View {
        Toggle(isOn: isOnDutyBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duty Status")
                    .font(.system(.headline, design: .rounded).bold())
                Text(isOnDutyBinding.wrappedValue ? "Active and tracking" : "Currently resting")
                    .font(.caption)
                    .foregroundStyle(DriverTheme.textSecondary)
            }
        }
        .tint(DriverTheme.successGreen)
        .padding(16)
        .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Week Calendar Widget
    private var weekCalendarWidget: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
        
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        
        let driverShifts = currentUser.map { user in
            appViewModel.service.shifts.filter { $0.driverID == user.id }
        } ?? []
        let hasShiftOnDay: (Date) -> Bool = { targetDate in
            driverShifts.contains { calendar.isDate($0.date, inSameDayAs: targetDate) }
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { idx in
                    let date = days[idx]
                    let dayNum = calendar.component(.day, from: date)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    
                    VStack(spacing: 8) {
                        Text(weekdaySymbols[idx])
                            .font(.caption.bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        Text("\(dayNum)")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(isToday ? .white : DriverTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(isToday ? DriverTheme.accent : Color.clear, in: Circle())
                        
                        Circle()
                            .fill(hasShiftOnDay(date) ? (isToday ? .white : DriverTheme.accent) : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
        )
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
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textSecondary)
                .padding(.horizontal, 4)

            if upcomingShifts.isEmpty {
                Text("No upcoming shifts scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcomingShifts) { shift in
                            let dayString = shift.date.formatted(.dateTime.weekday(.wide))
                            let dateString = shift.date.formatted(.dateTime.day().month())
                            let timeString = shift.startTime.formatted(date: .omitted, time: .shortened)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(dayString).font(.system(.headline, design: .rounded))
                                        Text(dateString).font(.caption).foregroundStyle(DriverTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "clock.fill").foregroundStyle(DriverTheme.accent)
                                }
                                Text(timeString).font(.title3.bold())
                                Text("Assigned")
                                    .font(.caption2.bold())
                                    .foregroundStyle(DriverTheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DriverTheme.accent.opacity(0.15), in: Capsule())
                            }
                            .padding(14)
                            .frame(width: 150)
                            .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
                            )
                            .scrollTransition { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .padding(.horizontal, -16)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverShiftDetailView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
