import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.gradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: AppTheme.brand.opacity(0.28), radius: 30, y: 16)
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(AppBranding.name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(AppBranding.tagline)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            ProgressView()
                .tint(AppTheme.brand)
                .padding(.bottom, 44)
        }
    }
}

#Preview {
    SplashView()
        .background(AppTheme.background)
}
