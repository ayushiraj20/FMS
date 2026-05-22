//
//  Untitled.swift
//  FMS
//
//  Created by Kshitij on 22/05/26.
//

import SwiftUI

struct ExpiringDocumentsDetailView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                headerCard

                documentCard(
                    title: "Vehicle Insurance",
                    vehicle: "Truck A",
                    expiry: "Expires in 4 days",
                    color: .red
                )

                documentCard(
                    title: "Road Permit",
                    vehicle: "Truck C",
                    expiry: "Expires in 8 days",
                    color: .orange
                )

                documentCard(
                    title: "Emission Certificate",
                    vehicle: "Van B",
                    expiry: "Expires in 14 days",
                    color: .yellow
                )
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Expiring Documents")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        GlassCard {
            HStack {

                VStack(alignment: .leading, spacing: 6) {

                    Text("Documents Requiring Action")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("3 Pending")
                        .font(.largeTitle.weight(.bold))
                }

                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.brand)
            }
        }
    }

    // MARK: - Document Card

    private func documentCard(
        title: String,
        vehicle: String,
        expiry: String,
        color: Color
    ) -> some View {

        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                HStack {

                    VStack(alignment: .leading, spacing: 4) {

                        Text(title)
                            .font(.headline)

                        Text(vehicle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                }

                Divider()

                HStack {

                    Label(expiry, systemImage: "clock.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(color)

                    Spacer()

                    Button {

                    } label: {
                        Text("Renew")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.brand)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExpiringDocumentsDetailView()
    }
}
