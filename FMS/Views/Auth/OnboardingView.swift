import SwiftUI

// MARK: - Data Model

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selection = 0
    @State private var appeared = false

    private let pages = [
        OnboardingPage(
            title: "Connect the Fleet",
            subtitle: "Managers, drivers & mechanics — unified in real time.",
            icon: "person.2.badge.gearshape.fill",
            accentColor: AppTheme.brand
        ),
        OnboardingPage(
            title: "Simplify Tasks",
            subtitle: "Log trips, inspect vehicles & report issues instantly.",
            icon: "checklist.checked",
            accentColor: Color(hex: "#34C759")
        ),
        OnboardingPage(
            title: "Keep Moving",
            subtitle: "Track health, schedule service & cut downtime.",
            icon: "gauge.with.needle.fill",
            accentColor: Color(hex: "#007AFF")
        )
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()

                // Icon + Text content area
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, isActive: selection == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                // Custom page indicator
                customPageIndicator
                    .padding(.top, 16)

                Spacer()
                    .frame(height: 40)

                // Buttons
                buttonsSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 50)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Ambient glow from current page accent
            Circle()
                .fill(pages[selection].accentColor.opacity(0.08))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: -60, y: -200)
                .animation(.easeInOut(duration: 0.8), value: selection)

            Circle()
                .fill(pages[selection].accentColor.opacity(0.05))
                .frame(width: 350, height: 350)
                .blur(radius: 90)
                .offset(x: 100, y: 250)
                .animation(.easeInOut(duration: 0.8), value: selection)
        }
    }

    // MARK: - Page Indicator

    private var customPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? pages[selection].accentColor : AppTheme.textSecondary.opacity(0.25))
                    .frame(width: index == selection ? 28 : 8, height: 8)
                    .animation(.spring(duration: 0.4, bounce: 0.2), value: selection)
            }
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        VStack(spacing: 14) {
            Button {
                if selection == pages.count - 1 {
                    appViewModel.completeOnboarding()
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                        selection += 1
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection == pages.count - 1 ? "Get Started" : "Continue")
                        .fontWeight(.semibold)

                    if selection == pages.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .font(.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    pages[selection].accentColor,
                                    pages[selection].accentColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: pages[selection].accentColor.opacity(0.35), radius: 16, x: 0, y: 8)
                )
            }
            .animation(.easeInOut(duration: 0.4), value: selection)

            Button {
                appViewModel.completeOnboarding()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Individual Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var iconAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            // Icon with animated rings
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(page.accentColor.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 200, height: 200)
                    .scaleEffect(iconAnimated ? 1.15 : 0.9)
                    .opacity(iconAnimated ? 0 : 0.6)

                // Middle ring
                Circle()
                    .fill(page.accentColor.opacity(0.06))
                    .frame(width: 170, height: 170)

                // Inner circle
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 130, height: 130)

                // Icon
                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.accentColor, page.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.bounce, value: isActive)
            }

            // Text
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(page.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.horizontal)
        .onAppear {
            startPulse()
        }
        .onChange(of: isActive) {
            if isActive { startPulse() }
        }
    }

    private func startPulse() {
        iconAnimated = false
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            iconAnimated = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AppViewModel())
}
