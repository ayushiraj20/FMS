import SwiftUI

struct RootAppView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

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
        .environmentObject(AppViewModel())
}
