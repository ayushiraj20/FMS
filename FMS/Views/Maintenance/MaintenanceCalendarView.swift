//
//  MaintenanceCalendarView.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import SwiftUI

struct MaintenanceCalendarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    
    let orders: [WorkOrder]
    
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    private var ordersAccent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var warmSecondaryText: Color { Color.dynamic(light: "#715B54", dark: "#D7B8AC") }
    
    // Group orders by start of day of their scheduledDate
    private var ordersByDate: [Date: [WorkOrder]] {
        Dictionary(grouping: orders) {
            calendar.startOfDay(for: $0.scheduledDate)
        }
    }
    
    // Filter orders on the selected day
    private var selectedDayOrders: [WorkOrder] {
        ordersByDate[selectedDate] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Navigation
            monthHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            // Calendar Grid Card
            VStack(spacing: 12) {
                // Weekday Header
                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(warmSecondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 10)
                
                Divider()
                    .overlay(Color.dynamic(light: "#E6D8D2", dark: "#3B3841").opacity(0.4))
                
                // Days Grid
                let days = generateDaysInMonth(for: currentMonth)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(0..<days.count, id: \.self) { index in
                        if let date = days[index] {
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            let hasOrders = ordersByDate[calendar.startOfDay(for: date)] != nil
                            let isToday = calendar.isDateInToday(date)
                            
                            Button {
                                selectedDate = calendar.startOfDay(for: date)
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(
                                            isSelected
                                            ? Color.white
                                            : (isToday ? ordersAccent : headingText)
                                        )
                                        .frame(width: 36, height: 36)
                                        .background(
                                            ZStack {
                                                if isSelected {
                                                    Circle()
                                                        .fill(ordersAccent)
                                                        .shadow(color: ordersAccent.opacity(0.35), radius: 6)
                                                } else if isToday {
                                                    Circle()
                                                        .stroke(ordersAccent, lineWidth: 1.5)
                                                }
                                            }
                                        )
                                    
                                    // Highlight indicator
                                    Circle()
                                        .fill(isSelected ? Color.white : ordersAccent)
                                        .frame(width: 5, height: 5)
                                        .opacity(hasOrders ? 1 : 0)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("")
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.dynamic(light: "#FFFFFF", dark: "#191A20"))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
            )
            .padding(.horizontal, 16)
            
            // Selected Date Subtitle
            HStack {
                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(headingText)
                Spacer()
                Text("\(selectedDayOrders.count) work orders")
                    .font(.subheadline)
                    .foregroundStyle(warmSecondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            // Works list for selected date
            ScrollView {
                VStack(spacing: 14) {
                    if selectedDayOrders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(warmSecondaryText.opacity(0.6))
                            Text("No work orders scheduled")
                                .font(.headline)
                                .foregroundStyle(headingText)
                            Text("You are free on this day.")
                                .font(.subheadline)
                                .foregroundStyle(warmSecondaryText)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(selectedDayOrders) { order in
                            NavigationLink {
                                MaintenanceWorkOrdersView.MaintenanceWorkOrderDetailView(workOrder: order)
                                    .environment(appViewModel)
                            } label: {
                                MaintenanceWorkOrdersView.MaintenanceWorkOrderCard(
                                    order: order,
                                    vehicle: appViewModel.service.vehicle(for: order.vehicleID)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Calendar Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(ordersAccent)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var monthHeader: some View {
        HStack {
            Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.bold))
                .foregroundStyle(headingText)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ordersAccent)
                        .frame(width: 32, height: 32)
                        .background(ordersAccent.opacity(0.12), in: Circle())
                }
                
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ordersAccent)
                        .frame(width: 32, height: 32)
                        .background(ordersAccent.opacity(0.12), in: Circle())
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func generateDaysInMonth(for month: Date) -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        
        let weekdayOfFirst = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = weekdayOfFirst - 1
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in 1...monthRange.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
}
