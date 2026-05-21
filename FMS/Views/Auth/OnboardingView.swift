import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}

struct OnboardingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selection = 0

    private let pages = [
        OnboardingPage(title: "Operate with total visibility", subtitle: "Monitor fleet health, compliance, and trip performance from one premium control center.", icon: "chart.bar.xaxis"),
        OnboardingPage(title: "Keep drivers road-ready", subtitle: "Support inspections, trip workflows, and instant defect reporting with a mobile-first experience.", icon: "checklist.checked"),
        OnboardingPage(title: "Modernize maintenance execution", subtitle: "Assign work orders, track repair progress, and stay ahead of service schedules.", icon: "wrench.adjustable")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.brand.opacity(0.14))
                                .frame(width: 190, height: 190)
                            Image(systemName: page.icon)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(AppTheme.brand)
                        }

                        VStack(spacing: 12) {
                            Text(page.title)
                                .font(.largeTitle.weight(.bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(page.subtitle)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 24)
                        }
                    }
                    .tag(index)
                    .padding(.horizontal)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 460)

            VStack(spacing: 12) {
                Button(selection == pages.count - 1 ? "Get Started" : "Continue") {
                    if selection == pages.count - 1 {
                        appViewModel.completeOnboarding()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selection += 1
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Skip") {
                    appViewModel.completeOnboarding()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
}
