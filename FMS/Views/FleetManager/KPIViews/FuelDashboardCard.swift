//
//  FuelDashboardCard.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import SwiftUI

struct FuelDashboardCard: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var summary: FuelDashboardSummary? = nil
    @State private var isLoading = true

    let repo: FuelRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Label("Fuel Overview", systemImage: "fuelpump.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 80)

            } else if let s = summary {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    metricCell(
                        title: "Total Spend",
                        value: "₹\(Int(s.totalVerifiedSpend))",
                        icon: "indianrupeesign.circle.fill",
                        isAlert: false
                    )
                    metricCell(
                        title: "Today's Spend",
                        value: "₹\(Int(s.todayVerifiedSpend))",
                        icon: "sun.max.fill",
                        isAlert: false
                    )
                    metricCell(
                        title: "Pending Review",
                        value: "\(s.pendingCount)",
                        icon: "clock.fill",
                        isAlert: s.pendingCount > 0
                    )
                    metricCell(
                        title: "Vehicles Tracked",
                        value: "\(s.vehicleWiseSpend.count)",
                        icon: "car.2.fill",
                        isAlert: false
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
        )
        .task {
            do {
                summary = try await repo.dashboardSummary()
            } catch {
                print("FuelDashboardCard error: \(error)")
            }
            isLoading = false
        }
    }

    private func metricCell(
        title: String,
        value: String,
        icon: String,
        isAlert: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(isAlert ? .red : DriverTheme.accent)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(isAlert ? .red : Color.primary)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}
