//
//  RefuelVehicleView.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import SwiftUI

struct RefuelVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let vehicleID: UUID
    let driverID: UUID
    let tripID: UUID?

    @State private var fuelVM: FuelViewModel

    @State private var showReceiptCapture = false
    @State private var showFullScreenReceipt = false

    init(vehicleID: UUID, driverID: UUID, tripID: UUID?, repo: FuelRepository) {
        self.vehicleID = vehicleID
        self.driverID = driverID
        self.tripID = tripID
        _fuelVM = State(initialValue: FuelViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    amountField
                    litresField
                    odometerField
                    receiptSection
                    errorBanner
                    Spacer(minLength: 20)
                    submitButton
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Log Refuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showFullScreenReceipt) {
                ImagePreviewSheet(image: fuelVM.receiptImage, imageURLString: nil)
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showReceiptCapture) {
            FuelReceiptView { image, ocrResult in
                handleReceiptImage(image)

                if fuelVM.amountText.isEmpty, let amount = ocrResult?.amount, !amount.isEmpty {
                    fuelVM.amountText = amount
                }
                if fuelVM.litresText.isEmpty, let litres = ocrResult?.litres, !litres.isEmpty {
                    fuelVM.litresText = litres
                }
            }
            .environment(appViewModel)
        }
        .alert("Fuel Logged!", isPresented: $fuelVM.submissionSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your refuel has been submitted for verification.")
        }
    }

    @MainActor
    private func handleReceiptImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        fuelVM.setReceipt(data: data, image: Image(uiImage: image))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 44))
                .foregroundStyle(DriverTheme.accent)
            Text("Log Refuel")
                .font(.system(size: 20, weight: .bold))
            Text("Fill in details and upload your receipt to continue.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fuel Amount Spent (₹)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                Text("₹")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18, weight: .semibold))
                TextField("0", text: $fuelVM.amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    // MARK: - Litres Field

    private var litresField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fuel Filled (Litres)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                TextField("e.g. 42.5", text: $fuelVM.litresText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold))
                Text("L")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    // MARK: - Odometer Field

    private var odometerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Odometer Reading (km)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                TextField("e.g. 54200", text: $fuelVM.odometerText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .bold))
                Text("km")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    // MARK: - Receipt Section

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Fuel Receipt")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("* Required")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
            }

            if fuelVM.receiptUploadSucceeded, let image = fuelVM.receiptImage {
                // Preview
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topTrailing) {
                        ZStack(alignment: .bottomTrailing) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )

                            Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.85))
                                .background(Circle().fill(.black.opacity(0.35)))
                                .padding(10)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showFullScreenReceipt = true
                        }

                        Button {
                            fuelVM.clearReceipt()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.red)
                                .background(
                                    Circle().fill(Color(uiColor: .systemBackground))
                                )
                        }
                        .padding(8)
                    }

                    Button {
                        showReceiptCapture = true
                    } label: {
                        Label("Retake or Upload Different Receipt", systemImage: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DriverTheme.accent)
                    }
                }

                Label("Receipt captured", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)

            } else {
                Button {
                    showReceiptCapture = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                        Text("Add Receipt")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Open receipt capture to take or upload a photo")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(DriverTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DriverTheme.accent.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        DriverTheme.accent.opacity(0.4),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                    )
                            )
                    )
                }

                // Blocking warning
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Receipt upload required to resume trip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
            }
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = fuelVM.submissionError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(0.10))
            )
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await fuelVM.submitRefuel(
                        vehicleID: vehicleID,
                        driverID: driverID,
                        tripID: tripID
                    )
                }
            } label: {
                Group {
                    if fuelVM.isSubmitting {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Submitting...")
                        }
                    } else {
                        Text("Submit Refuel")
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule().fill(
                        fuelVM.canSubmit
                            ? DriverTheme.accent
                            : DriverTheme.accent.opacity(0.35)
                    )
                )
            }
            .disabled(!fuelVM.canSubmit)

            if fuelVM.resumeTripBlocked {
                Text("Receipt upload required")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }
}
