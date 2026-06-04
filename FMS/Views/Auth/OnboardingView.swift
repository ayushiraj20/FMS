import SwiftUI

// MARK: - Data Model

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icons: [OnboardingIcon]
    let accentColor: Color
    let backgroundGradientColors: [Color]
}

struct OnboardingIcon: Identifiable {
    let id = UUID()
    let systemName: String
    let size: CGFloat
    let offset: CGSize
    let rotation: Double
    let delay: Double
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selection = 0
    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Connect the Fleet",
            subtitle: "Managers, drivers & mechanics — unified in real time.",
            icons: [
                OnboardingIcon(systemName: "person.2.fill", size: 38, offset: CGSize(width: -30, height: -20), rotation: -8, delay: 0),
                OnboardingIcon(systemName: "gearshape.fill", size: 24, offset: CGSize(width: 35, height: -35), rotation: 15, delay: 0.1),
                OnboardingIcon(systemName: "antenna.radiowaves.left.and.right", size: 22, offset: CGSize(width: 0, height: 30), rotation: 0, delay: 0.2),
                OnboardingIcon(systemName: "arrow.triangle.swap", size: 18, offset: CGSize(width: -40, height: 25), rotation: -12, delay: 0.15),
            ],
            accentColor: AppTheme.brand,
            backgroundGradientColors: [
                Color(hex: "#FFF7ED"),
                Color(hex: "#FFFBF5"),
                Color(hex: "#FFFFFF"),
            ]
        ),
        OnboardingPage(
            title: "Simplify Tasks",
            subtitle: "Log trips, inspect vehicles & report issues instantly.",
            icons: [
                OnboardingIcon(systemName: "checkmark.circle.fill", size: 36, offset: CGSize(width: -25, height: -25), rotation: -5, delay: 0),
                OnboardingIcon(systemName: "doc.text.fill", size: 24, offset: CGSize(width: 35, height: -15), rotation: 10, delay: 0.1),
                OnboardingIcon(systemName: "camera.fill", size: 22, offset: CGSize(width: -35, height: 25), rotation: -8, delay: 0.2),
                OnboardingIcon(systemName: "bolt.fill", size: 20, offset: CGSize(width: 30, height: 30), rotation: 12, delay: 0.15),
            ],
            accentColor: Color(hex: "#34C759"),
            backgroundGradientColors: [
                Color(hex: "#F0FFF4"),
                Color(hex: "#F8FFF9"),
                Color(hex: "#FFFFFF"),
            ]
        ),
        OnboardingPage(
            title: "Keep Moving",
            subtitle: "Track health, schedule service & cut downtime.",
            icons: [
                OnboardingIcon(systemName: "gauge.with.needle.fill", size: 36, offset: CGSize(width: 0, height: -30), rotation: 0, delay: 0),
                OnboardingIcon(systemName: "wrench.and.screwdriver.fill", size: 24, offset: CGSize(width: -38, height: 10), rotation: -15, delay: 0.1),
                OnboardingIcon(systemName: "calendar.badge.clock", size: 22, offset: CGSize(width: 38, height: 5), rotation: 10, delay: 0.2),
                OnboardingIcon(systemName: "chart.line.uptrend.xyaxis", size: 20, offset: CGSize(width: 0, height: 35), rotation: 5, delay: 0.15),
            ],
            accentColor: Color(hex: "#007AFF"),
            backgroundGradientColors: [
                Color(hex: "#EFF6FF"),
                Color(hex: "#F5F9FF"),
                Color(hex: "#FFFFFF"),
            ]
        ),
    ]

    var body: some View {
        ZStack {
            // Animated background
            backgroundLayer
                .animation(.easeInOut(duration: 0.6), value: selection)

            VStack(spacing: 0) {
                // Top spacer
                Spacer()
                    .frame(height: 40)

                // Hero illustration area
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingHeroView(page: page, isActive: selection == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 50)

                // Text content
                textContent
                    .padding(.horizontal, 32)

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 40)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // Base gradient that shifts per page
            LinearGradient(
                colors: pages[selection].backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating accent orbs
            Circle()
                .fill(pages[selection].accentColor.opacity(0.07))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -80, y: -280)

            Circle()
                .fill(pages[selection].accentColor.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: 300)
        }
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(spacing: 14) {
            Text(pages[selection].title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .id("title-\(selection)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal: .opacity.combined(with: .offset(y: -10))
                ))

            Text(pages[selection].subtitle)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .id("subtitle-\(selection)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity.combined(with: .offset(y: -8))
                ))
        }
        .animation(.easeInOut(duration: 0.35), value: selection)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicator
            customPageIndicator

            // Primary action button — iOS-native style
            Button {
                if selection == pages.count - 1 {
                    appViewModel.completeOnboarding()
                } else {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                        selection += 1
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection == pages.count - 1 ? "Get Started" : "Continue")

                    if selection == pages.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(pages[selection].accentColor)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .animation(.easeInOut(duration: 0.35), value: selection)

            // Skip button
            Button {
                appViewModel.completeOnboarding()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Page Indicator

    private var customPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? pages[selection].accentColor : AppTheme.textSecondary.opacity(0.2))
                    .frame(width: index == selection ? 28 : 8, height: 8)
                    .animation(.spring(duration: 0.4, bounce: 0.2), value: selection)
            }
        }
    }
}

// MARK: - Hero Illustration View

private struct OnboardingHeroView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var floatPhase = false
    @State private var iconsAppeared = false
    @State private var ringPulse = false

    var body: some View {
        ZStack {
            // Concentric decorative rings
            concentricRings

            // Central glowing orb
            centralOrb

            // Floating icons around the center
            floatingIcons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimations()
        }
        .onChange(of: isActive) {
            if isActive {
                iconsAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    startAnimations()
                }
            }
        }
    }

    // MARK: - Concentric Rings

    private var concentricRings: some View {
        ZStack {
            // Outermost ring — dashed, subtle
            Circle()
                .stroke(page.accentColor.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(floatPhase ? 360 : 0))
                .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: floatPhase)

            // Middle ring
            Circle()
                .stroke(page.accentColor.opacity(0.08), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(ringPulse ? 1.04 : 0.98)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: ringPulse)

            // Inner ring — thicker
            Circle()
                .stroke(page.accentColor.opacity(0.1), lineWidth: 1.5)
                .frame(width: 160, height: 160)
                .scaleEffect(ringPulse ? 0.97 : 1.03)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3), value: ringPulse)
        }
    }

    // MARK: - Central Orb

    private var centralOrb: some View {
        ZStack {
            // Glow behind orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            page.accentColor.opacity(0.2),
                            page.accentColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)

            // Glassmorphic circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            page.accentColor.opacity(0.15),
                            page.accentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 110)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    page.accentColor.opacity(0.3),
                                    page.accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            // Main icon
            Image(systemName: page.icons.first?.systemName ?? "star.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [page.accentColor, page.accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: isActive)
        }
        .offset(y: floatPhase ? -4 : 4)
        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: floatPhase)
    }

    // MARK: - Floating Icons

    private var floatingIcons: some View {
        ForEach(Array(page.icons.dropFirst().enumerated()), id: \.offset) { index, icon in
            floatingIconBubble(icon: icon, index: index)
        }
    }

    private func floatingIconBubble(icon: OnboardingIcon, index: Int) -> some View {
        ZStack {
            // Frosted background
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: icon.size + 20, height: icon.size + 20)
                .overlay(
                    Circle()
                        .stroke(page.accentColor.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: page.accentColor.opacity(0.1), radius: 8, x: 0, y: 4)

            Image(systemName: icon.systemName)
                .font(.system(size: icon.size * 0.55, weight: .semibold))
                .foregroundStyle(page.accentColor)
        }
        .offset(x: icon.offset.width * 2.2, y: icon.offset.height * 2.2)
        .rotationEffect(.degrees(icon.rotation))
        .offset(y: floatPhase ? -6 : 6)
        .animation(
            .easeInOut(duration: 2.5 + Double(index) * 0.3)
            .repeatForever(autoreverses: true)
            .delay(icon.delay),
            value: floatPhase
        )
        .scaleEffect(iconsAppeared ? 1 : 0.3)
        .opacity(iconsAppeared ? 1 : 0)
        .animation(
            .spring(duration: 0.6, bounce: 0.4).delay(icon.delay + 0.2),
            value: iconsAppeared
        )
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation {
            iconsAppeared = true
            floatPhase = true
            ringPulse = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AppViewModel())
}
