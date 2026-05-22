import SwiftUI

struct PriorityAlertDetailView: View {
    let category: String
    let count: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<count, id: \.self) { index in
                    alertCard(index: index)
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("\(category) (\(count))")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func alertCard(index: Int) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: iconName)
                            .foregroundStyle(iconColor)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(category) #\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(mockMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        
                    Text("\(index * 5 + 2) mins ago")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var mockMessage: String {
        switch category {
        case "SOS Alerts": return "Emergency assistance requested by the driver."
        case "Critical": return "Critical system failure or policy violation detected."
        case "Maintenance": return "Engine diagnostics report a critical fault."
        case "Off-Route": return "Vehicle has deviated from its assigned route."
        case "Geofence": return "Vehicle crossed a restricted geofence boundary."
        default: return "Alert details."
        }
    }
    
    private var iconName: String {
        switch category {
        case "SOS Alerts": return "exclamationmark.triangle.fill"
        case "Critical": return "bell.fill"
        case "Maintenance": return "wrench.and.screwdriver.fill"
        case "Off-Route": return "location.slash.fill"
        case "Geofence": return "mappin.and.ellipse"
        default: return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch category {
        case "SOS Alerts": return Color("AccentColor")
        case "Critical": return Color("AccentColor")
        case "Maintenance": return Color("AccentColor")
        case "Off-Route": return Color("AccentColor")
        case "Geofence": return Color("AccentColor")
        default: return Color("AccentColor")
        }
    }
}

#Preview {
    NavigationStack {
        PriorityAlertDetailView(category: "SOS Alerts", count: 5)
    }
}
