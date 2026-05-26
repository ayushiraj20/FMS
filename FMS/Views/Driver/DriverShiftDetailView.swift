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
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                assignedVehicleCard
                shiftTimingsWidget
                onDutyToggleCard
                weekCalendarWidget
                upcomingShiftsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(DriverScreenBackground())
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Assigned Vehicle Card
    private var assignedVehicleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let vehicle = assignedVehicle {
                HStack(spacing: 16) {
                    Image("truck_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 5)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(vehicle.plateNumber)
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        
                        Text(vehicle.displayName)
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        Label(vehicle.status.rawValue, systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(vehicle.status == .active ? DriverTheme.successGreen : DriverTheme.textSecondary)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 16) {
                    Circle()
                        .fill(DriverTheme.textSecondary.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "truck.box.fill").foregroundStyle(DriverTheme.textSecondary))
                    
                    Text("No Vehicle Assigned")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .opacity(phase.isIdentity ? 1 : 0.8)
        }
    }

    // MARK: - Shift Timings Widget
    private var shiftTimingsWidget: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                timingRow(label: "Start", time: shift?.startTime.formatted(date: .omitted, time: .shortened) ?? "6:00 AM")
                timingRow(label: "Break", time: shift?.breakTime?.formatted(date: .omitted, time: .shortened) ?? "12:00 PM")
                timingRow(label: "End", time: shift?.endTime.formatted(date: .omitted, time: .shortened) ?? "6:00 PM")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            let progress = shift?.progress ?? 0.65
            let totalHours = shift?.totalHours ?? 12.0
            
            ZStack {
                CircularProgressRing(progress: progress, size: 130, strokeWidth: 14)
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(.title, design: .rounded).bold())
                        .contentTransition(.numericText())
                    Text("\(Int(totalHours))h")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    
    private func timingRow(label: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DriverTheme.textSecondary)
            Text(time)
                .font(.system(.title3, design: .rounded).bold())
        }
    }

    // MARK: - On Duty Toggle Card
    private var onDutyToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duty Status")
                    .font(.system(.headline, design: .rounded))
                Text(isOnDutyBinding.wrappedValue ? "Active and tracking" : "Currently resting")
                    .font(.caption)
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOnDutyBinding)
                .labelsHidden()
                .tint(DriverTheme.successGreen)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

        return VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.system(.title2, design: .rounded).bold())
            
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { idx in
                    let date = days[idx]
                    let dayNum = calendar.component(.day, from: date)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    
                    VStack(spacing: 10) {
                        Text(weekdaySymbols[idx])
                            .font(.caption.bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        Text("\(dayNum)")
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(isToday ? .white : DriverTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(isToday ? DriverTheme.accent : Color.clear, in: Circle())
                        
                        Circle()
                            .fill(hasShiftOnDay(date) ? (isToday ? .white : DriverTheme.accent) : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

        return VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming")
                .font(.system(.title2, design: .rounded).bold())

            if upcomingShifts.isEmpty {
                Text("No upcoming shifts scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(upcomingShifts) { shift in
                            let dayString = shift.date.formatted(.dateTime.weekday(.wide))
                            let dateString = shift.date.formatted(.dateTime.day().month())
                            let timeString = shift.startTime.formatted(date: .omitted, time: .shortened)
                            
                            VStack(alignment: .leading, spacing: 12) {
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(DriverTheme.accent.opacity(0.15), in: Capsule())
                            }
                            .padding(16)
                            .frame(width: 160)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .padding(.horizontal, -20)
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
