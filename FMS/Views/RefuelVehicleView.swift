//
//  RefuelVehicleView.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import SwiftUI
import PhotosUI

struct RefuelVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let vehicleID: UUID
    let driverID: UUID
    let tripID: UUID?

    @State private var fuelVM: FuelViewModel

    // PhotosPicker state
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showSourcePicker = false
    @State private var showPhotoLibrary = false

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
                    odometerField
                    receiptSection
                    errorBanner
                    Spacer(minLength: 20)
                    submitButton
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Refuel Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let item = newItem else { return }
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                // Use UIImage-free approach via SwiftUI
                if let uiImage = await loadUIImage(from: data) {
                    let swiftUIImage = Image(uiImage: uiImage)
                    fuelVM.setReceipt(data: data, image: swiftUIImage)
                }
            }
        }
        .alert("Fuel Logged!", isPresented: $fuelVM.submissionSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your refuel has been submitted for verification.")
        }
    }

    // MARK: - Load Image Helper

    @MainActor
    private func loadUIImage(from data: Data) async -> UIImage? {
        UIImage(data: data)
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
                ZStack(alignment: .topTrailing) {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    Button {
                        fuelVM.clearReceipt()
                        selectedPhotoItem = nil
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

                Label("Receipt captured", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)

            } else {
                // Upload CTA
                Button {
                    showPhotoLibrary = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                        Text("Upload Receipt")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tap to choose from Photo Library")
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
