import SwiftUI

struct RootAppView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        AppScaffold {
            Group {
                switch appViewModel.flowState {
                case .splash:
                    SplashView()
                case .onboarding:
                    OnboardingView()
                case .login:
                    LoginView()
                case .demoRoleSelection:
                    DemoRoleSelectionView()
                case .forcePasswordReset:
                    PasswordResetView()
                case .mfaVerification:
                    MFAVerificationView()
                case .authenticated:
                    MainTabView()
                }
            }
        }
        .task {
            if appViewModel.flowState == .splash {
                await appViewModel.startApp()
            }
        }
    }
}

#Preview {
    RootAppView()
        .environment(AppViewModel())
}
