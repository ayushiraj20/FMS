import SwiftUI

struct AIPredictionDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.brand)
                    
                    Text("AI Prediction Dashboard")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Insights and predictive analytics for your fleet operations")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)
                
                // Content
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Maintenance Predictions")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("No critical maintenance predicted in the next 7 days.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Route Optimization")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("AI suggestions for optimal routing will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("AI Predictions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AIPredictionDashboardView()
    }
}
