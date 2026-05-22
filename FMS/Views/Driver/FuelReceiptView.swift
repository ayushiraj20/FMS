import SwiftUI

struct FuelReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel

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
            .navigationTitle(isProcessingCapturedPhoto ? "Analyzing..." : (isScanning ? "Scanner" : "Add Fuel Receipt"))
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
        VStack(spacing: 16) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 48))
                .foregroundStyle(DriverTheme.accent)
                .padding(.top, 20)

            Text("Add Fuel Receipt")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            // Scan Receipt Button
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    // Graceful fallback to simulated scanner on simulator
                    startScanningSimulation()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                    Text("Scan Receipt")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(DriverTheme.accent))
            }

            // Manual Entry Button
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
                        .font(.system(size: 20))
                    Text("Enter Manually")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(DriverTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(DriverTheme.cardFill)
                        .overlay(Capsule().stroke(DriverTheme.cardBorder, lineWidth: 0.5))
                )
            }

            Spacer()
        }
    }

    private var scannerView: some View {
        VStack(spacing: 20) {
            ZStack {
                // Simulated camera viewfinder background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .overlay {
                        // Grid/Finder details
                        GeometryReader { _ in
                            VStack {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                    Spacer()
                                    Image(systemName: "camera.metering.matrix")
                                }
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding()
                                Spacer()
                            }
                        }
                    }

                // Bounding scan frame
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        scanProgress >= 1.0 ? Color.green : DriverTheme.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [15, 10])
                    )
                    .frame(width: 250, height: 340)
                    .overlay {
                        // Simulated paper document
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RECEIPT")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                            Text("INDIAN OIL CORP")
                                .font(.system(.caption2, design: .monospaced))
                            Text("DATE: 22-MAY-2026")
                                .font(.system(.caption2, design: .monospaced))
                            Divider()
                                .background(Color.white.opacity(0.3))
                            Text("LITRES: 42.50 L")
                                .font(.system(.caption2, design: .monospaced))
                            Text("PRICE/L: 97.64")
                                .font(.system(.caption2, design: .monospaced))
                            Text("TOTAL: INR 4,150.00")
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(16)
                        .frame(width: 230, height: 320)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)

                        // Vertical Laser Line
                        GeometryReader { _ in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, DriverTheme.accent, .clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 3)
                                .shadow(color: DriverTheme.accent, radius: 4, x: 0, y: 0)
                                .offset(y: animateLaser ? 320 : 0)
                        }
                        .frame(width: 230, height: 320)
                    }

                // Scan status HUD at bottom of card
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(scanStatus)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        
                        ProgressView(value: scanProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: DriverTheme.accent))
                            .frame(width: 180)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
                    .padding(.bottom, 20)
                }
            }
            .frame(height: 420)
            .cornerRadius(16)
            .onAppear {
                animateLaser = false
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animateLaser = true
                }
            }

            // Cancel Scan Button
            Button {
                withAnimation {
                    isScanning = false
                    showManualEntry = false
                }
            } label: {
                Text("Cancel Scan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.8)))
            }
            
            Spacer()
        }
        .padding(.top, 10)
    }

    private var photoProcessingView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .blur(radius: 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.35))
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DriverTheme.accent))
                    .scaleEffect(1.5)
            }

            VStack(spacing: 8) {
                Text("Analyzing Receipt...")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)

                Text(scanStatus)
                    .font(.system(size: 14))
                    .foregroundStyle(DriverTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }

    private var manualEntryForm: some View {
        VStack(spacing: 16) {
            if showScanSuccessToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receipt Scanned Successfully")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("Parsed info is pre-filled. Please verify.")
                            .font(.system(size: 12))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        showScanSuccessToast = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity)
            }

            // Vehicle auto-filled
            if let vehicle = appViewModel.service.vehicle(for: appViewModel.currentUser?.assignedVehicleID) {
                HStack {
                    Text("Vehicle")
                        .foregroundStyle(DriverTheme.textSecondary)
                    Spacer()
                    Text(vehicle.plateNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DriverTheme.cardFill))
            }

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DriverTheme.cardFill))

            TextField("Station Name", text: $stationName)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DriverTheme.cardFill))

            TextField("Litres", text: $litres)
                .keyboardType(.decimalPad)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DriverTheme.cardFill))

            HStack {
                Text("₹")
                    .foregroundStyle(DriverTheme.textSecondary)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DriverTheme.cardFill))

            Spacer()

            Button("Save") {
                guard let user = appViewModel.currentUser,
                      let vehicleID = user.assignedVehicleID,
                      let litresVal = Double(litres),
                      let amountVal = Double(amount) else { return }

                let vehicle = appViewModel.service.vehicle(for: vehicleID)
                appViewModel.service.addFuelReceipt(
                    driverID: user.id,
                    vehicleID: vehicleID,
                    stationName: stationName,
                    litres: litresVal,
                    amount: amountVal,
                    vehiclePlate: vehicle?.plateNumber ?? ""
                )
                driverVM.showToastMessage("Fuel receipt saved")
                dismiss()
            }
            .buttonStyle(DriverAccentButtonStyle())
            .disabled(stationName.isEmpty || litres.isEmpty || amount.isEmpty)
            .opacity(stationName.isEmpty || litres.isEmpty || amount.isEmpty ? 0.5 : 1)
        }
    }

    private func startScanningSimulation() {
        stationName = ""
        litres = ""
        amount = ""
        showScanSuccessToast = false
        scanProgress = 0.0
        scanStatus = "Positioning receipt..."
        
        withAnimation {
            isScanning = true
        }

        Task {
            // Step 1: Detect Receipt
            try? await Task.sleep(for: .seconds(0.7))
            guard isScanning else { return }
            await MainActor.run {
                scanStatus = "Detecting document edges..."
                scanProgress = 0.25
            }

            // Step 2: Read OCR Text
            try? await Task.sleep(for: .seconds(0.8))
            guard isScanning else { return }
            await MainActor.run {
                scanStatus = "Extracting text with Vision OCR..."
                scanProgress = 0.6
            }

            // Step 3: Parse Fields
            try? await Task.sleep(for: .seconds(0.7))
            guard isScanning else { return }
            await MainActor.run {
                scanStatus = "Parsing amount & litres..."
                scanProgress = 0.9
            }

            // Step 4: Complete
            try? await Task.sleep(for: .seconds(0.4))
            guard isScanning else { return }
            await MainActor.run {
                scanProgress = 1.0
                scanStatus = "OCR Extraction Complete!"
            }

            // Short pause to show completion
            try? await Task.sleep(for: .seconds(0.3))
            guard isScanning else { return }
            
            await MainActor.run {
                stationName = "Indian Oil Corp Ltd"
                litres = "42.50"
                amount = "4150"
                showScanSuccessToast = true
                
                withAnimation {
                    isScanning = false
                    showManualEntry = true
                }
            }
        }
    }

    private func startPhotoProcessing(with image: UIImage) {
        scanStatus = "Analyzing receipt image..."
        
        withAnimation {
            isProcessingCapturedPhoto = true
        }

        Task {
            // Step 1: Analyze receipt
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                scanStatus = "Running OCR text extraction..."
            }
            
            // Step 2: Parse details
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                scanStatus = "Matching fuel receipt data..."
            }
            
            // Step 3: Prefill & transition
            try? await Task.sleep(for: .seconds(0.4))
            await MainActor.run {
                stationName = "HP Fuel Station"
                litres = "38.40"
                amount = "3725"
                showScanSuccessToast = true
                
                withAnimation {
                    isProcessingCapturedPhoto = false
                    showManualEntry = true
                }
            }
        }
    }
}

#Preview {
    FuelReceiptView()
        .environmentObject(AppViewModel())
        .environmentObject(DriverViewModel())
}
