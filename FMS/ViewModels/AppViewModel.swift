import Foundation
import SwiftUI
import Supabase
import Observation
import AudioToolbox

enum RootFlowState {
    case splash
    case onboarding
    case login
    case demoRoleSelection
    case forcePasswordReset
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

    // SOS alert state for the Fleet Manager dashboard overlay
    var activeEmergencyAlert: SOSAlert? = nil

    // Persisted set of SOS alert IDs that the fleet manager has already resolved/dismissed.
    // Once an ID is in here, the banner will never re-appear for it—even across logins.
    @ObservationIgnored
    private var dismissedSOSAlertIDs: Set<UUID> {
        get {
            let strings = UserDefaults.standard.stringArray(forKey: "dismissedSOSAlertIDs") ?? []
            return Set(strings.compactMap { UUID(uuidString: $0) })
        }
        set {
            UserDefaults.standard.set(newValue.map { $0.uuidString }, forKey: "dismissedSOSAlertIDs")
        }
    }

    @ObservationIgnored private var sosChannel: RealtimeChannelV2? = nil
    @ObservationIgnored private var sosPostgresChangeSubscription: Any? = nil
    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>? = nil

    init() {
        // Register local observer for offline real-time compatibility
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LocalSOSTriggered"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let alert = notification.userInfo?["alert"] as? SOSAlert
            Task { @MainActor in
                if let alert = alert {
                    // Prepend to service.sosAlerts if not already present
                    if !self.service.sosAlerts.contains(where: { $0.id == alert.id }) {
                        self.service.sosAlerts.insert(alert, at: 0)
                    }
                    
                    // Show emergency banner if this user is a Fleet Manager and status is ACTIVE
                    if self.currentUser?.role == .fleetManager && alert.status == "ACTIVE" {
                        withAnimation(.spring()) {
                            self.activeEmergencyAlert = alert
                        }
                        
                        // Audio & Vibration Alert
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                        AudioServicesPlaySystemSound(1005)
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
    }

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

                    if matchedUser.isPasswordResetRequired {
                        flowState = .forcePasswordReset
                    } else {
                        // Load notifications filtered for this user's UUID immediately after login
                        await loadNotifications()

                        flowState = .authenticated
                        startAutoRefresh()

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
                            
                            self.subscribeToSOSAlerts()
                            self.checkActiveSOSAlerts()
                        }
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

        if user.isPasswordResetRequired {
            flowState = .forcePasswordReset
        } else {
            // Pre-load notifications filtered for this user's UUID
            notifications = service.notifications(for: user)

            flowState = .authenticated
            startAutoRefresh()

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
                
                self.subscribeToSOSAlerts()
                self.checkActiveSOSAlerts()
            }
        }

        isAuthenticating = false
    }

    // MARK: Demo Login

    func loginAsDemo(
        role: UserRole
    ) {
        if SupabaseConfig.isConfigured {
            isAuthenticating = true
            authErrorMessage = nil
            Task {
                await service.syncWithDatabase()
                if let user = service.users.first(where: { $0.role == role }) {
                    // Sign in to Supabase Auth so RLS permissions are granted
                    do {
                        let _ = try await SupabaseService.shared.client.auth.signIn(
                            email: user.email,
                            password: user.password
                        )
                        print("[Supabase Auth] Successfully authenticated as demo role: \(role.rawValue) (\(user.email))")
                    } catch {
                        print("[Supabase Auth ERROR] Failed to authenticate as demo role: \(error.localizedDescription)")
                    }
                    
                    currentUser = user
                    notifications = service.notifications(for: user)
                    
                    if let orgID = currentOrganization?.id {
                        await BroadcastService.shared.load(orgID: orgID)
                        BroadcastService.shared.subscribe(orgID: orgID)
                        self.subscribeToSOSAlerts()
                    }
                    self.checkActiveSOSAlerts()
                    flowState = .authenticated
                    startAutoRefresh()
                } else {
                    authErrorMessage = "No backend user profile found for role: \(role.rawValue). Please check database profiles table."
                }
                isAuthenticating = false
            }
            return
        }

        // Offline mode fallback:
        guard let user = service.users(for: role).first else { return }
        currentUser = user
        notifications = service.notifications(for: user)
        flowState = .authenticated
        startAutoRefresh()

        Task {
            if let orgID = currentOrganization?.id {
                await BroadcastService.shared.load(orgID: orgID)
                BroadcastService.shared.subscribe(orgID: orgID)
                self.subscribeToSOSAlerts()
            }
            self.checkActiveSOSAlerts()
        }
    }

    // MARK: Password Reset Completion

    func updatePasswordAndCompleteReset(newPassword: String) async throws {
        guard var user = currentUser else {
            throw NSError(domain: "AppViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "No current user session found."])
        }
        
        isAuthenticating = true
        authErrorMessage = nil
        
        do {
            if SupabaseConfig.isConfigured {
                // 1. Update password in Supabase Auth
                let _ = try await supabase.client.auth.update(user: UserAttributes(password: newPassword))
                
                // 2. Update isPasswordResetRequired to false in Profiles metadata
                user.isPasswordResetRequired = false
                try await supabase.updateProfile(user)
                
                // 3. Sync locally
                await service.syncWithDatabase()
                if let synced = service.users.first(where: { $0.id == user.id }) {
                    currentUser = synced
                } else {
                    currentUser = user
                }
                
                await loadNotifications()
            } else {
                // Offline/Mock mode update
                try? await Task.sleep(for: .seconds(0.8))
                
                user.password = newPassword
                user.isPasswordResetRequired = false
                service.updateUser(user)
                currentUser = user
                
                notifications = service.notifications(for: user)
            }
            
            startAutoRefresh()
            
            if let orgID = currentOrganization?.id {
                await BroadcastService.shared.load(orgID: orgID)
                BroadcastService.shared.subscribe(orgID: orgID)
                self.subscribeToSOSAlerts()
                self.checkActiveSOSAlerts()
            }
            
            withAnimation(.spring()) {
                flowState = .authenticated
            }
        } catch {
            authErrorMessage = error.localizedDescription
            isAuthenticating = false
            throw error
        }
        
        isAuthenticating = false
    }

    // MARK: Logout

    func logout() {

        BroadcastService.shared
            .unsubscribe()
        
        self.unsubscribeSOSAlerts()
        self.stopAutoRefresh()

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

    func refreshCurrentUser() {
        if let user = currentUser, let matched = service.users.first(where: { $0.id == user.id }) {
            currentUser = matched
        }
    }

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
                .from("profiles")
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

    // MARK: - SOS Realtime Subscription
    func subscribeToSOSAlerts() {
        guard SupabaseConfig.isConfigured else { return }
        
        unsubscribeSOSAlerts()
        
        let newChannel = SupabaseService.shared.client.channel("sos_alerts_channel")
        
        sosPostgresChangeSubscription = newChannel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "sos_alerts"
        ) { [weak self] payload in
            guard let self else { return }
            
            Task { @MainActor in
                do {
                    let alert = try payload.decodeRecord(as: SOSAlert.self, decoder: JSONDecoder())
                    
                    if !self.service.sosAlerts.contains(where: { $0.id == alert.id }) {
                        self.service.sosAlerts.insert(alert, at: 0)
                        
                        if self.currentUser?.role == .fleetManager && alert.status == "ACTIVE" {
                            withAnimation(.spring()) {
                                self.activeEmergencyAlert = alert
                            }
                            
                            // Audio & Vibration Alert
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            AudioServicesPlaySystemSound(1005)
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            
                            NotificationScheduler.scheduleBroadcastAlert(
                                title: "🚨 ACTIVE EMERGENCY: \(alert.driverName)",
                                body: "Vehicle: \(alert.vehicleNumber) | Emergency: \(alert.emergencyType). Tap to respond."
                            )
                        }
                    }
                } catch {
                    print("SOS Realtime decode error: \(error)")
                }
            }
        }
        
        let _ = newChannel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "sos_alerts"
        ) { [weak self] payload in
            guard let self else { return }
            
            Task { @MainActor in
                do {
                    let alert = try payload.decodeRecord(as: SOSAlert.self, decoder: JSONDecoder())
                    
                    if let idx = self.service.sosAlerts.firstIndex(where: { $0.id == alert.id }) {
                        self.service.sosAlerts[idx] = alert
                    }
                    
                    if alert.status == "CLOSED" {
                        if self.activeEmergencyAlert?.id == alert.id {
                            withAnimation(.spring()) {
                                self.activeEmergencyAlert = nil
                            }
                        }
                    } else if self.currentUser?.role == .fleetManager {
                        withAnimation(.spring()) {
                            self.activeEmergencyAlert = alert
                        }
                    }
                } catch {
                    print("SOS Realtime update decode error: \(error)")
                }
            }
        }
        
        Task {
            do {
                try await newChannel.subscribeWithError()
                print("Supabase SOS Realtime subscription active ✅")
            } catch {
                print("Supabase SOS Realtime subscribe error: \(error)")
            }
        }
        
        sosChannel = newChannel
    }
    
    func unsubscribeSOSAlerts() {
        if let channel = sosChannel {
            Task {
                await channel.unsubscribe()
            }
        }
        sosChannel = nil
        sosPostgresChangeSubscription = nil
    }
    
    func checkActiveSOSAlerts() {
        guard currentUser?.role == .fleetManager else { return }
        let dismissed = dismissedSOSAlertIDs
        if let firstActive = service.sosAlerts.first(where: { $0.status == "ACTIVE" && !dismissed.contains($0.id) }) {
            withAnimation(.spring()) {
                self.activeEmergencyAlert = firstActive
            }
        } else {
            withAnimation(.spring()) {
                self.activeEmergencyAlert = nil
            }
        }
    }

    /// Marks an SOS alert as dismissed by the fleet manager.
    /// Persists the dismissal so the banner never re-appears across sessions.
    func dismissSOSAlert(_ alertID: UUID) {
        var current = dismissedSOSAlertIDs
        current.insert(alertID)
        dismissedSOSAlertIDs = current
        if activeEmergencyAlert?.id == alertID {
            withAnimation(.spring()) {
                activeEmergencyAlert = nil
            }
        }
        // Also mark as CLOSED in Supabase
        if SupabaseConfig.isConfigured,
           let alert = service.sosAlerts.first(where: { $0.id == alertID }) {
            var closed = alert
            closed.status = "CLOSED"
            if let idx = service.sosAlerts.firstIndex(where: { $0.id == alertID }) {
                service.sosAlerts[idx] = closed
            }
            Task {
                try? await SupabaseService.shared.updateSOSAlert(closed)
            }
        }
    }

    /// Fetches the latest SOS alerts from Supabase and refreshes the local list
    /// and activeEmergencyAlert banner. Call on dashboard appear to catch missed
    /// realtime events.
    func refreshSOSAlerts() {
        guard SupabaseConfig.isConfigured else {
            checkActiveSOSAlerts()
            return
        }
        Task {
            do {
                let fresh = try await SupabaseService.shared.fetchSOSAlerts()
                let remoteIDs = Set(fresh.map { $0.id })
                let localOnly = self.service.sosAlerts.filter { !remoteIDs.contains($0.id) }
                self.service.sosAlerts = fresh + localOnly
                print("[SOS] Refreshed \(fresh.count) alert(s) from Supabase ✅")
                self.checkActiveSOSAlerts()
            } catch {
                print("[SOS] Refresh failed, using in-memory: \(error)")
                checkActiveSOSAlerts()
            }
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }
                guard flowState == .authenticated else { break }
                
                print("[AutoRefresh] Periodic synchronization starting...")
                await service.syncWithDatabase()
                refreshCurrentUser()
                refreshSOSAlerts()
                await loadNotifications()
            }
        }
        print("[AutoRefresh] Periodic synchronization started.")
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        print("[AutoRefresh] Periodic synchronization stopped.")
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
