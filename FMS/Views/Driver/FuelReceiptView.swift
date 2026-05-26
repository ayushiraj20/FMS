import SwiftUI

struct FuelReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    @State private var showManualEntry = false
    @State private var stationName = ""
    @State private var litres = ""
    @State private var amount = ""
    @State private var selectedDate = Date.now

    // Scan Simulation States
    @State private var isScanning = false
    @State private var scanProgress: Double = 0.0
    @State private var scanStatus = "Positioning receipt..."
    @State private var showScanSuccessToast = false
    @State private var animateLaser = false

    // Real Camera States
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessingCapturedPhoto = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessingCapturedPhoto {
                    photoProcessingView
                } else if isScanning {
                    scannerView
                } else if !showManualEntry {
                    optionsView
                } else {
                    manualEntryForm
                }
            }
            .padding(20)
            .navigationTitle(isProcessingCapturedPhoto ? "Analyzing..." : (isScanning ? "Scanner" : "Fuel Receipt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isScanning && !isProcessingCapturedPhoto {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(showManualEntry ? "Back" : "Cancel") {
                            if showManualEntry {
                                withAnimation {
                                    showManualEntry = false
                                    stationName = ""
                                    litres = ""
                                    amount = ""
                                    showScanSuccessToast = false
                                }
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .background(
                ZStack {
                    DriverTheme.background.ignoresSafeArea()
                    GeometryReader { geo in
                        Circle()
                            .fill(DriverTheme.accent.opacity(0.1))
                            .frame(width: geo.size.width)
                            .blur(radius: 60)
                            .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.3)
                    }
                    .ignoresSafeArea()
                }
            )
        }
        .presentationDetents(isScanning || isProcessingCapturedPhoto ? [.large] : [.medium, .large])
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage) { image in
                startPhotoProcessing(with: image)
            }
            .ignoresSafeArea()
        }
    }

    private var optionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 64))
                .foregroundStyle(DriverTheme.accent)
                .symbolEffect(.pulse)
                .padding(.top, 40)
                .padding(.bottom, 20)

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    startScanningSimulation()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    Text("Scan Receipt")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(DriverTheme.accent, in: Capsule())
                .shadow(color: DriverTheme.accent.opacity(0.3), radius: 10, y: 5)
            }

            Button {
                withAnimation {
                    stationName = ""
                    litres = ""
                    amount = ""
                    showScanSuccessToast = false
                    showManualEntry = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.line")
                        .font(.title2)
                    Text("Enter Manually")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundStyle(DriverTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(DriverTheme.textSecondary.opacity(0.2), lineWidth: 1))
            }

            Spacer()
        }
    }

    private var manualEntryForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                if showScanSuccessToast {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan Successful")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.white)
                            Text("Details pre-filled. Please verify.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(DriverTheme.successGreen, in: RoundedRectangle(cornerRadius: 16))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 16) {
                    if let vehicle = appViewModel.assignedVehicle {
                        HStack {
                            Text("Vehicle").foregroundStyle(DriverTheme.textSecondary)
                            Spacer()
                            Text(vehicle.plateNumber).font(.system(.headline, design: .rounded).bold())
                        }
                        .padding()
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                    }

                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .padding()
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))

                    TextField("Station Name", text: $stationName)
                        .padding()
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))

                    TextField("Litres", text: $litres)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))

                    HStack {
                        Text("₹").foregroundStyle(DriverTheme.textSecondary)
                        TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button {
                    guard let user = appViewModel.currentUser,
                          let vehicle = appViewModel.assignedVehicle,
                          let litresVal = Double(litres),
                          let amountVal = Double(amount) else { return }

                    appViewModel.service.addFuelReceipt(
                        driverID: user.id, vehicleID: vehicle.id, stationName: stationName,
                        litres: litresVal, amount: amountVal, vehiclePlate: vehicle.plateNumber
                    )
                    driverVM.showToastMessage("Fuel receipt saved")
                    dismiss()
                } label: {
                    Text("Save Receipt")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(stationName.isEmpty || litres.isEmpty || amount.isEmpty ? Color.gray : DriverTheme.accent, in: Capsule())
                }
                .disabled(stationName.isEmpty || litres.isEmpty || amount.isEmpty)
                .padding(.top, 16)
            }
        }
    }

    private var scannerView: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.8))
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(scanProgress >= 1.0 ? DriverTheme.successGreen : DriverTheme.accent, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .frame(width: 260, height: 360)
                    .overlay {
                        GeometryReader { _ in
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, DriverTheme.accent, .clear], startPoint: .top, endPoint: .bottom))
                                .frame(height: 4)
                                .shadow(color: DriverTheme.accent, radius: 8)
                                .offset(y: animateLaser ? 340 : 0)
                        }.frame(width: 240, height: 340)
                    }

                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(scanStatus).font(.subheadline.bold()).foregroundStyle(.white)
                        ProgressView(value: scanProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: DriverTheme.accent))
                            .frame(width: 200)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 24)
                }
            }
            .frame(height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .onAppear {
                animateLaser = false
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { animateLaser = true }
            }

            Button {
                withAnimation { isScanning = false; showManualEntry = false }
            } label: {
                Text("Cancel").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 56).background(DriverTheme.criticalRed, in: Capsule())
            }
        }
    }

    private var photoProcessingView: some View {
        VStack(spacing: 32) {
            Spacer()
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.4))
                        ProgressView().scaleEffect(2).tint(.white)
                    }
            } else {
                ProgressView().scaleEffect(2).tint(DriverTheme.accent)
            }
            VStack(spacing: 8) {
                Text("Analyzing Receipt...").font(.title3.bold())
                Text(scanStatus).font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func startScanningSimulation() {
        stationName = ""
        litres = ""
        amount = ""
        showScanSuccessToast = false
        scanProgress = 0.0
        scanStatus = "Positioning receipt..."
        withAnimation { isScanning = true }
        
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard isScanning else { return }
            await MainActor.run { scanStatus = "Detecting edges..."; scanProgress = 0.25 }

            try? await Task.sleep(nanoseconds: 800_000_000)
            guard isScanning else { return }
            await MainActor.run { scanStatus = "Extracting text..."; scanProgress = 0.6 }

            try? await Task.sleep(nanoseconds: 700_000_000)
            guard isScanning else { return }
            await MainActor.run { scanStatus = "Parsing details..."; scanProgress = 0.9 }

            try? await Task.sleep(nanoseconds: 400_000_000)
            guard isScanning else { return }
            await MainActor.run { scanProgress = 1.0; scanStatus = "Complete!" }

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard isScanning else { return }
            await MainActor.run {
                stationName = "Indian Oil Corp Ltd"
                litres = "42.50"
                amount = "4150"
                showScanSuccessToast = true
                withAnimation { isScanning = false; showManualEntry = true }
            }
        }
    }

    private func startPhotoProcessing(with image: UIImage) {
        scanStatus = "Analyzing image..."
        withAnimation { isProcessingCapturedPhoto = true }
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { scanStatus = "Running OCR..." }
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { scanStatus = "Matching data..." }
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                stationName = "HP Fuel Station"
                litres = "38.40"
                amount = "3725"
                showScanSuccessToast = true
                withAnimation { isProcessingCapturedPhoto = false; showManualEntry = true }
            }
        }
    }
}

#Preview {
    FuelReceiptView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
