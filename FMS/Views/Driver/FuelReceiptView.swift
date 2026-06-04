import SwiftUI
import Vision
import PhotosUI

struct FuelReceiptView: View {
    @Environment(\.dismiss) private var dismiss

    let onReceiptCaptured: (UIImage, FuelOCRResult?) -> Void

    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessingCapturedPhoto = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var scanStatus = "Positioning receipt..."

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessingCapturedPhoto {
                    photoProcessingView
                } else {
                    optionsView
                }
            }
            .padding(20)
            .navigationTitle(isProcessingCapturedPhoto ? "Analyzing..." : "Fuel Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isProcessingCapturedPhoto {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .background(DriverScreenBackground())
        }
        .presentationDetents(isProcessingCapturedPhoto ? [.large] : [.medium, .large])
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage) { image in
                startPhotoProcessing(with: image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run {
                    startPhotoProcessing(with: image)
                }
            }
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
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    Text("Scan Receipt")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DriverTheme.accent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .opacity(UIImagePickerController.isSourceTypeAvailable(.camera) ? 1 : 0.5)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("Upload Receipt")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(DriverTheme.accent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)

            Text("Capture or upload a clear receipt photo. OCR will extract amount and litres where possible.")
                .font(.footnote)
                .foregroundStyle(DriverTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()
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
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(2).tint(.white)
                            Text("OCR Active")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
            } else {
                ProgressView().scaleEffect(2).tint(DriverTheme.accent)
            }
            VStack(spacing: 8) {
                Text("Reading Receipt...")
                    .font(.title3.bold())
                Text(scanStatus)
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private func startPhotoProcessing(with image: UIImage) {
        capturedImage = image
        scanStatus = "Analyzing image..."
        withAnimation { isProcessingCapturedPhoto = true }

        Task {
            await MainActor.run { scanStatus = "Detecting text on receipt..." }

            do {
                let result = try await FuelOCRService.extractReceiptData(from: image)
                await MainActor.run { scanStatus = "Extracting fuel details..." }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    onReceiptCaptured(image, result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    onReceiptCaptured(image, nil)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    FuelReceiptView { _, _ in }
}
