
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
            List {
                Section {
                    HStack {
                        Spacer()
                        statusBadge
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Details") {
                    LabeledContent("Driver", value: driverName)
                    LabeledContent("Vehicle", value: vehiclePlate)
                    LabeledContent("Amount", value: "₹\(Int(transaction.manualAmount))")
                    LabeledContent("Litres", value: String(format: "%.2f L", transaction.litres))
                    LabeledContent("Odometer", value: "\(transaction.odometerReading) km")
                    LabeledContent("Date & Time", value: transaction.timestamp.formatted(date: .long, time: .shortened))
                }

                Section("Fuel Receipt") {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .background(Circle().fill(.black.opacity(0.35)))
                                    .padding(12)
                            }
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
                    .padding(.vertical, 4)
                }

                if transaction.verificationStatus == .rejected, let reason = transaction.rejectionReason {
                    Section("Rejection Reason") {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Transaction Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if transaction.verificationStatus == .pending {
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                isVerifying = true
                                await fuelVM.verify(transaction: transaction)
                                isVerifying = false
                                dismiss()
                            }
                        } label: {
                            Label("Mark as Verified", systemImage: "checkmark.seal.fill")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                        .tint(.green)

                        Button {
                            showRejectionAlert = true
                        } label: {
                            Label("Reject Transaction", systemImage: "xmark.seal.fill")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                        .tint(Color.red.opacity(0.15))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .background(.ultraThinMaterial)
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
}
