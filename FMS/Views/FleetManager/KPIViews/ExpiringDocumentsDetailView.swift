import SwiftUI

struct ExpiringDocumentsDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedDocument: VehicleDocument?

    private var expiringDocuments: [VehicleDocument] {
        appViewModel.service.documents.sorted(by: { $0.expiryDate < $1.expiryDate })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                if expiringDocuments.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.fill",
                        title: "All Clear!",
                        message: "All vehicle documents are current and verified."
                    )
                } else {
                    ForEach(expiringDocuments) { document in
                        Button {
                            selectedDocument = document
                        } label: {
                            let vehicle = appViewModel.service.vehicle(for: document.vehicleID)
                            let days = daysRemaining(to: document.expiryDate)
                            let color = days < 30 ? (days < 10 ? AppTheme.error : AppTheme.warning) : AppTheme.success
                            let statusText = days < 0 ? "Expired" : "Expires in \(days) days"
                            
                            documentCard(
                                title: documentTypeTitle(document.type),
                                vehicle: vehicle?.displayName ?? "Unknown Vehicle",
                                plate: vehicle?.plateNumber ?? "N/A",
                                expiry: statusText,
                                color: color
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Expiring Documents")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDocument) { doc in
            let vehicle = appViewModel.service.vehicle(for: doc.vehicleID)
            DocumentDetailSheet(document: doc, vehicle: vehicle)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        let count = expiringDocuments.filter { daysRemaining(to: $0.expiryDate) < 90 }.count
        return GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Documents Requiring Action")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("\(count) Pending")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
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
        plate: String,
        expiry: String,
        color: Color
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("\(vehicle) • \(plate)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                }

                Divider()
                    .background(AppTheme.border)

                HStack {
                    Label(expiry, systemImage: "clock.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(color)

                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func documentTypeTitle(_ type: DocumentType) -> String {
        switch type {
        case .rc: return "Registration Certificate (RC)"
        case .insurance: return "Vehicle Insurance Policy"
        case .puc: return "Pollution Under Control (PUC)"
        case .permit: return "National Road Permit"
        }
    }

    private func daysRemaining(to date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date.now, to: date)
        return components.day ?? 0
    }
}

// MARK: - Document Detail Sheet

struct DocumentDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: VehicleDocument
    let vehicle: Vehicle?

    private var daysLeft: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date.now, to: document.expiryDate)
        return components.day ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        Image(systemName: documentIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.brand)
                            .padding(.top, 16)

                        Text(documentTypeLongTitle)
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Doc No: \(document.documentNumber)")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    // Expiration Info callout
                    let statusColor = daysLeft < 30 ? (daysLeft < 10 ? AppTheme.error : AppTheme.warning) : AppTheme.success
                    let calloutText = daysLeft < 0 ? "Document has EXPIRED!" : "Expires in \(daysLeft) days"
                    
                    VStack(spacing: 6) {
                        Text(calloutText.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(statusColor)
                        
                        Text("Expiration Date: \(document.expiryDate.formatted(date: .long, time: .omitted))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(statusColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(statusColor.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Associated Vehicle Details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ASSOCIATED VEHICLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)

                        if let v = vehicle {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppTheme.brand.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "box.truck.fill")
                                        .foregroundStyle(AppTheme.brand)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(v.displayName)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Plate: \(v.plateNumber)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Text(v.status.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(v.status == .active ? AppTheme.success : AppTheme.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(v.status == .active ? AppTheme.success.opacity(0.12) : AppTheme.warning.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
                            .padding(.horizontal)
                        } else {
                            Text("No vehicle details available.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal)
                        }
                    }

                    // Compliance Verification Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("COMPLIANCE VERIFICATION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)

                        HStack(spacing: 14) {
                            Image(systemName: document.isVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .font(.title)
                                .foregroundStyle(document.isVerified ? AppTheme.success : AppTheme.error)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.isVerified ? "Verified Certificate" : "Verification Pending")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(document.isVerified ? "This document is fully compliant with regional RTO guidelines." : "Awaiting validation from transport supervisor.")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var documentIcon: String {
        switch document.type {
        case .rc: return "doc.text.fill"
        case .insurance: return "shield.doc.fill"
        case .puc: return "smoke.fill"
        case .permit: return "map.fill"
        }
    }

    private var documentTypeLongTitle: String {
        switch document.type {
        case .rc: return "Registration Certificate (RC)"
        case .insurance: return "Vehicle Insurance Policy"
        case .puc: return "Pollution Under Control (PUC)"
        case .permit: return "National Road Permit"
        }
    }
}

#Preview {
    NavigationStack {
        ExpiringDocumentsDetailView()
            .environment(AppViewModel())
    }
}
