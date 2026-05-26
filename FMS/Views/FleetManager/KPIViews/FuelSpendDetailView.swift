//
//  FuelSpendDetailView.swift
//  FMS
//
//  Created by Kshitij on 22/05/26.
//

import SwiftUI

struct FuelSpendDetailView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                topAnalyticsCard

                monthlyBreakdownCard

                topConsumersCard

                recommendationsCard
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Fuel Spend")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Top Analytics

    private var topAnalyticsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {

                Text("Monthly Fuel Analytics")
                    .font(.title3.weight(.bold))

                HStack(alignment: .bottom, spacing: 10) {

                    Text("₹11.2k")
                        .font(.system(size: 42, weight: .bold))

                    Text("this month")
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.bottom, 6)
                }

                HStack {
                    Image(systemName: "arrow.down.right")

                    Text("12% lower than previous month")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Monthly Breakdown

    private var monthlyBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {

                Text("Weekly Breakdown")
                    .font(.headline)

                spendRow(week: "Week 1", amount: "₹2.8k")
                spendRow(week: "Week 2", amount: "₹3.1k")
                spendRow(week: "Week 3", amount: "₹2.5k")
                spendRow(week: "Week 4", amount: "₹2.8k")
            }
        }
    }

    // MARK: - Top Consumers

    private var topConsumersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {

                Text("Top Fuel Consumers")
                    .font(.headline)

                vehicleSpend(name: "Truck A", amount: "₹2,100")
                vehicleSpend(name: "Truck B", amount: "₹1,870")
                vehicleSpend(name: "Van C", amount: "₹1,420")
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                Label("AI Recommendation", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppTheme.brand)

                Text("Optimize Route Cluster B to reduce fuel consumption by approximately 8%.")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func spendRow(week: String, amount: String) -> some View {
        HStack {
            Text(week)

            Spacer()

            Text(amount)
                .fontWeight(.semibold)
        }
    }

    private func vehicleSpend(name: String, amount: String) -> some View {
        HStack {

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .fontWeight(.medium)

                Text("Fuel Efficiency: Good")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(amount)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.brand)
        }
    }
}

#Preview {
    NavigationStack {
        FuelSpendDetailView()
    }
}
