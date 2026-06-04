import SwiftUI

struct RootAppView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showNotificationsSheet = false

    var body: some View {
        AppScaffold {
            ZStack(alignment: .top) {
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
                
                if appViewModel.showInAppBanner, let notification = appViewModel.inAppBannerNotification {
                    InAppNotificationBanner(notification: notification) {
                        appViewModel.dismissInAppBanner()
                    } onTap: {
                        appViewModel.dismissInAppBanner()
                        showNotificationsSheet = true
                    }
                    .zIndex(100)
                }
            }
        }
        .sheet(isPresented: $showNotificationsSheet) {
            NavigationStack {
                NotificationsView()
            }
            .environment(appViewModel)
            .registersSheetPresentation()
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
