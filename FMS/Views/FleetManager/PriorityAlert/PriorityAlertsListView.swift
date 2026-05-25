import SwiftUI

struct PriorityAlertsListView: View {
    let alerts = [
        ("SOS Alerts", 5, "exclamationmark.triangle.fill"),
        ("Critical", 3, "bell.fill"),
        ("Maintenance", 2, "wrench.and.screwdriver.fill"),
        ("Off-Route", 4, "location.slash.fill"),
        ("Geofence", 1, "mappin.and.ellipse")
    ]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(alerts, id: \.0) { alert in
                    NavigationLink(destination: PriorityAlertDetailView(category: alert.0, count: alert.1)) {
                        VStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: alert.2)
                                    .font(.system(size: 32, weight: .regular))
                                    .foregroundStyle(Color("AccentColor"))
                                    .frame(width: 50, height: 50)
                                
                                if alert.1 > 0 {
                                    Text("\(alert.1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 22, minHeight: 22)
                                        .background(Circle().fill(Color("AccentColor")))
                                        .overlay(
                                            Circle()
                                                .stroke(AppTheme.cardBackground, lineWidth: 2)
                                        )
                                        .offset(x: 8, y: -8)
                                }
                            }
                            
                            Text(alert.0)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("All Priority Alerts")
    }
}

#Preview {
    NavigationStack {
        PriorityAlertsListView()
    }
}
