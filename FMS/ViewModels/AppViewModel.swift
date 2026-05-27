import Foundation
import SwiftUI
import Supabase
import Observation

enum RootFlowState {
    case splash
    case onboarding
    case login
    case demoRoleSelection
    case authenticated
}

@Observable
@MainActor
final class AppViewModel {

    @ObservationIgnored
    private var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    var flowState: RootFlowState = .splash
    var currentUser: User?
    var isAuthenticating = false
    var authErrorMessage: String?

    var organizationName = "NorthStar Logistics"
    var profileNotificationsEnabled = true
    var biometricUnlockEnabled = false
    var notifications: [AppNotification] = []
    let service = MockDataService()
    let supabase = SupabaseService.shared

    // MARK: App Launch

    func startApp() async {

        try? await Task.sleep(
            for: .seconds(1.5)
        )

        flowState =
        hasSeenOnboarding
        ? .login
        : .onboarding
    }

    func completeOnboarding() {

        hasSeenOnboarding = true
        flowState = .login
    }

    // MARK: Login

    func login(
        email: String,
        password: String
    ) async {

        authErrorMessage = nil
        isAuthenticating = true

        if SupabaseConfig.isConfigured {

            do {

                let session =
                try await
                SupabaseService.shared
                    .client
                    .auth
                    .signIn(
                        email: email,
                        password: password
                    )

                let authUser =
                session.user

                await service
                    .syncWithDatabase()

                if let matchedUser =
                    service.users.first(
                        where: {
                            $0.id ==
                            authUser.id
                        }
                    ) {

                    currentUser = matchedUser

                    organizationName =
                    service.organizations
                        .first(
                            where: {
                                $0.id ==
                                matchedUser.organizationID
                            }
                        )?.name
                    ?? organizationName

                    // Load notifications filtered for this user's UUID immediately after login
                    await loadNotifications()

                    flowState = .authenticated

                    // START BROADCAST

                    if let orgID =
                    currentOrganization?.id {

                        await BroadcastService.shared
                            .load(
                                orgID: orgID
                            )

                        BroadcastService.shared
                            .subscribe(
                                orgID: orgID
                            )
                    }

                } else {

                    authErrorMessage =
                    "Could not find profile for authenticated user."
                }

            } catch {

                authErrorMessage =
                error.localizedDescription
            }

            isAuthenticating = false
            return
        }

        try? await Task.sleep(
            for: .seconds(0.8)
        )

        guard let user =
        service.authenticate(
            email: email,
            password: password
        )
        else {

            isAuthenticating = false

            authErrorMessage =
            "Invalid email or password."

            return
        }

        currentUser = user

        organizationName =
        service.organizations
            .first(
                where: {
                    $0.id ==
                    user.organizationID
                }
            )?.name
        ?? organizationName

        // Pre-load notifications filtered for this user's UUID
        notifications = service.notifications(for: user)

        flowState = .authenticated

        // START BROADCAST

        if let orgID =
        currentOrganization?.id {

            await BroadcastService.shared
                .load(
                    orgID: orgID
                )

            BroadcastService.shared
                .subscribe(
                    orgID: orgID
                )
        }

        isAuthenticating = false
    }

    // MARK: Demo Login

    func loginAsDemo(
        role: UserRole
    ) {

        guard let user =
        service.users(
            for: role
        ).first

        else {

            return
        }

        currentUser = user
        // Pre-load notifications filtered for this demo user's UUID
        notifications = service.notifications(for: user)
        flowState = .authenticated

        Task {

            if let orgID =
            currentOrganization?.id {

                await
                BroadcastService.shared
                    .load(
                        orgID: orgID
                    )

                BroadcastService.shared
                    .subscribe(
                        orgID: orgID
                    )
            }
        }
    }

    // MARK: Logout

    func logout() {

        BroadcastService.shared
            .unsubscribe()

        if SupabaseConfig
            .isConfigured {

            Task {

                try? await
                SupabaseService.shared
                    .client
                    .auth
                    .signOut()
            }
        }

        currentUser = nil

        flowState = .login
    }

    // MARK: Profile Update

    func updateProfile(
        name: String,
        phone: String,
        title: String,
        email: String? = nil
    ) async {

        guard var user = currentUser else { return }

        user.name = name
        user.phone = phone
        user.title = title

        if let email {
            user.email = email
        }

        // 1. Save to Supabase
        do {
            struct ProfileUpdate: Encodable {
                let name: String
                let phone: String?
                let title: String?
            }

            let update = ProfileUpdate(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                title: title.isEmpty ? nil : title
            )

            try await SupabaseService.shared.client
                .from("users")
                .update(update)
                .eq("id", value: user.id)
                .execute()

            print("Profile updated in Supabase ✅")
        } catch {
            print("Profile update failed: \(error)")
        }

        // 2. Update local state
        if let idx = service.users.firstIndex(where: { $0.id == user.id }) {
            service.users[idx] = user
        }

        currentUser = user
    }

    // MARK: Helpers
    
    var assignedVehicle: Vehicle? {
        guard let currentUser else { return nil }
        return service.vehicles.first { $0.assignedDriverID == currentUser.id }
    }

    var unreadNotificationsCount: Int {
        // Always filter by the current user's UUID — never show unread count for other users
        return notifications.filter { !$0.isRead }.count
    }
    var currentRole: UserRole? {

        currentUser?.role
    }

    var currentOrganization:
    Organization? {

        guard let orgID =
        currentUser?.organizationID

        else {

            return service
                .organizations
                .first
        }

        return service
            .organizations
            .first(
                where: {
                    $0.id ==
                    orgID
                }
            )
    }
    func loadNotifications() async {
        guard let user = currentUser else { return }

        if SupabaseConfig.isConfigured {
            do {
                // Fetch from Supabase using the logged-in user's UUID
                notifications = try await supabase.fetchNotificationsForUser(
                    userID: user.id,
                    roleRawValue: user.role.rawValue
                )
            } catch {
                // Fallback to local MockDataService cache (already UUID-filtered)
                notifications = service.notifications(for: user)
                print("[Notifications] Supabase fetch failed, using local cache: \(error.localizedDescription)")
            }
        } else {
            // No Supabase — use local cache directly, filtered by UUID
            notifications = service.notifications(for: user)
        }
    }

    func markNotificationAsRead(id: UUID) async {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
        
        let notification = notifications[index]
        service.markNotificationRead(notification)
        
        if SupabaseConfig.isConfigured {
            try? await supabase.updateNotification(notification)
        }
    }
}
