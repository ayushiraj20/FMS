
//
//  FuelTransactionDetailView.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import SwiftUI

struct FuelTransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    let transaction: FuelTransaction
    var fuelVM: FuelViewModel

    @State private var showRejectionAlert = false
    @State private var rejectionReason = ""
    @State private var isVerifying = false
    @State private var isRejecting = false
    @State private var showFullScreenReceipt = false

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusBadge
                    detailsCard
                    receiptCard
                    if transaction.verificationStatus == .pending {
                        verificationButtons
                    }
                    if transaction.verificationStatus == .rejected,
                       let reason = transaction.rejectionReason {
                        rejectionReasonCard(reason: reason)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Transaction Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showFullScreenReceipt) {
                ImagePreviewSheet(image: nil, imageURLString: transaction.receiptImageURL)
            }
        }
        .alert("Reject Transaction", isPresented: $showRejectionAlert) {
            TextField("Reason for rejection", text: $rejectionReason)
            Button("Reject", role: .destructive) {
                Task {
                    isRejecting = true
                    await fuelVM.reject(
                        transaction: transaction,
                        reason: rejectionReason
                    )
                    isRejecting = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Provide a reason. This will be recorded against the transaction.")
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: transaction.verificationStatus.iconName)
            Text(transaction.verificationStatus.displayName)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(statusColor.opacity(0.12)))
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Driver",     value: driverName)
            Divider().padding(.horizontal, 16)
            detailRow(label: "Vehicle",    value: vehiclePlate)
            Divider().padding(.horizontal, 16)
            detailRow(label: "Amount",     value: "₹\(Int(transaction.manualAmount))")
            Divider().padding(.horizontal, 16)
            detailRow(label: "Litres",     value: String(format: "%.2f L", transaction.litres))
            Divider().padding(.horizontal, 16)
            detailRow(label: "Odometer",   value: "\(transaction.odometerReading) km")
            Divider().padding(.horizontal, 16)
            detailRow(
                label: "Date & Time",
                value: transaction.timestamp.formatted(date: .long, time: .shortened)
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Receipt Card

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fuel Receipt", systemImage: "doc.viewfinder.fill")
                .font(.headline)
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            AsyncImage(url: URL(string: transaction.receiptImageURL)) { phase in
                switch phase {
                case .empty:
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 180)

                case .success(let image):
                    ZStack(alignment: .bottomTrailing) {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        
                        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                            .background(Circle().fill(.black.opacity(0.35)))
                            .padding(12)
                    }
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFullScreenReceipt = true
                    }

                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.secondary)
                        Text("Could not load receipt")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)

                @unknown default:
                    EmptyView()
                }
            }
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    // MARK: - Verification Buttons

    private var verificationButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    isVerifying = true
                    await fuelVM.verify(transaction: transaction)
                    isVerifying = false
                    dismiss()
                }
            } label: {
                Group {
                    if isVerifying {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Verifying…")
                        }
                    } else {
                        Label("Mark as Verified", systemImage: "checkmark.seal.fill")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.green)
                )
            }

            Button {
                showRejectionAlert = true
            } label: {
                Group {
                    if isRejecting {
                        HStack(spacing: 8) {
                            ProgressView().tint(.red)
                            Text("Rejecting…")
                        }
                    } else {
                        Label("Reject Transaction", systemImage: "xmark.seal.fill")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.12))
                )
            }
        }
    }

    // MARK: - Rejection Reason Card

    private func rejectionReasonCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rejection Reason", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }
}
