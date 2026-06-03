//
//  FuelTransactionsListView.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import SwiftUI

struct FuelTransactionsListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var fuelVM: FuelViewModel
    @State private var selectedTransaction: FuelTransaction? = nil
    @State private var filterStatus: FuelVerificationStatus? = nil

    init(repo: FuelRepository) {
        _fuelVM = State(initialValue: FuelViewModel(repo: repo))
    }

    private var filtered: [FuelTransaction] {
        guard let status = filterStatus else { return fuelVM.allTransactions }
        return fuelVM.allTransactions.filter { $0.verificationStatus == status }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if fuelVM.isLoadingTransactions {
                Spacer()
                ProgressView("Loading transactions…")
                Spacer()

            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "fuelpump.slash",
                    description: Text("No fuel records match the selected filter.")
                )

            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { tx in
                            Button {
                                selectedTransaction = tx
                            } label: {
                                FuelTransactionRow(transaction: tx)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await fuelVM.loadAllTransactions()
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Fuel Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fuelVM.loadAllTransactions() }
        .sheet(item: $selectedTransaction) { tx in
            FuelTransactionDetailView(
                transaction: tx,
                fuelVM: fuelVM
            )
            .registersSheetPresentation()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip("All", status: nil)
                filterChip("Pending", status: .pending)
                filterChip("Verified", status: .verified)
                filterChip("Rejected", status: .rejected)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func filterChip(
        _ label: String,
        status: FuelVerificationStatus?
    ) -> some View {
        let isSelected = filterStatus == status
        return Button {
            withAnimation(.spring(response: 0.3)) {
                filterStatus = status
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                            ? DriverTheme.accent
                            : Color(uiColor: .secondarySystemBackground)
                    )
                )
        }
    }
}

// MARK: - Transaction Row

struct FuelTransactionRow: View {
    let transaction: FuelTransaction
    @Environment(AppViewModel.self) private var appViewModel

    private var driverName: String {
        appViewModel.service.user(for: transaction.driverID)?.name ?? "Unknown Driver"
    }

    private var vehiclePlate: String {
        appViewModel.service.vehicle(for: transaction.vehicleID)?.plateNumber ?? "—"
    }

    private var statusColor: Color {
        switch transaction.verificationStatus {
        case .pending:  return .orange
        case .verified: return .green
        case .rejected: return .red
        }
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(driverName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("\(vehiclePlate) • \(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("₹\(Int(transaction.manualAmount))")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(transaction.verificationStatus.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
    }
}
