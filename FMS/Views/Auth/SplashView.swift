import SwiftUI

struct SplashView: View {
    @State private var animateIcon = false
    @State private var animateText = false

    var body: some View {
        ZStack {
            // Native system background
            AppTheme.background
                .ignoresSafeArea()

            // Subtle background ambient brand glow
            GeometryReader { geo in
                Circle()
                    .fill(AppTheme.brand.opacity(0.08))
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.1, y: geo.size.height * 0.15)
            }
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 24) {
                    // App Icon Showcase with double drop shadows and brand halo
                    ZStack {
                        // Soft orange brand halo behind the icon
                        Circle()
                            .fill(AppTheme.brand.opacity(0.18))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .scaleEffect(animateIcon ? 1.0 : 0.8)

                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 10)
                            .shadow(color: AppTheme.brand.opacity(0.2), radius: 24, x: 0, y: 16)
                            .scaleEffect(animateIcon ? 1.0 : 0.85)
                            .opacity(animateIcon ? 1.0 : 0.0)
                    }

                    // App branding labels
                    VStack(spacing: 12) {
                        Text(AppBranding.name)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(AppBranding.tagline)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 40)
                    }
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 12)
                }

                Spacer()

                VStack(spacing: 24) {
                    // Custom Apple-style circular loading indicator
                    ProgressView()
                        .tint(AppTheme.brand)
                        .scaleEffect(1.15)
                        .opacity(animateText ? 1.0 : 0.0)
                    
                    // Native bottom signature branding
                    Text("FLEET MANAGEMENT SYSTEM")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3.0)
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                        .opacity(animateText ? 1.0 : 0.0)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // Snappy Apple-native spring animation
            withAnimation(.spring(response: 0.82, dampingFraction: 0.74, blendDuration: 0)) {
                animateIcon = true
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.25)) {
                animateText = true
            }
        }
    }
}

#Preview {
    SplashView()
}
