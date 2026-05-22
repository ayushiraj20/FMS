import Foundation
import SwiftUI
import Combine
import Supabase

enum RootFlowState {
    case splash
    case onboarding
    case login
    case demoRoleSelection
    case authenticated
}

@MainActor
final class AppViewModel: ObservableObject {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @Published var flowState: RootFlowState = .splash
    @Published var currentUser: User?
    @Published var isAuthenticating = false
    @Published var authErrorMessage: String?

    @Published var organizationName = "NorthStar Logistics"
    @Published var profileNotificationsEnabled = true
    @Published var biometricUnlockEnabled = false

    let service = MockDataService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        service.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    func startApp() async {
        try? await Task.sleep(for: .seconds(1.5))
        flowState = hasSeenOnboarding ? .login : .onboarding
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        flowState = .login
    }

    func login(email: String, password: String) async {
        authErrorMessage = nil
        isAuthenticating = true

        if SupabaseConfig.isConfigured {
            do {
                let session = try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
                let authUser = session.user
                
                await service.syncWithDatabase()
                
                if let matchedUser = service.users.first(where: { $0.id == authUser.id }) {
                    currentUser = matchedUser
                    organizationName = service.organizations.first(where: { $0.id == matchedUser.organizationID })?.name ?? organizationName
                    flowState = .authenticated
                } else {
                    authErrorMessage = "Could not find profile for authenticated user."
                }
            } catch {
                authErrorMessage = error.localizedDescription
            }
            isAuthenticating = false
            return
        }

        try? await Task.sleep(for: .seconds(0.8))

        guard let user = service.authenticate(email: email, password: password) else {
            isAuthenticating = false
            authErrorMessage = "Invalid email or password. Please try again."
            return
        }

        currentUser = user
        organizationName = service.organizations.first(where: { $0.id == user.organizationID })?.name ?? organizationName
        isAuthenticating = false
        flowState = .authenticated
    }

    func register(name: String, email: String, password: String, phone: String, role: UserRole) async {
        authErrorMessage = nil
        isAuthenticating = true

        if SupabaseConfig.isConfigured {
            do {
                let session = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
                let authUser = session.user
                
                var organization = service.organizations.first
                if organization == nil {
                    let defaultOrg = Organization(
                        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
                        name: "NorthStar Logistics",
                        industry: "Regional Distribution",
                        fleetSize: 24,
                        complianceScore: 96
                    )
                    try? await SupabaseService.shared.addOrganization(defaultOrg)
                    service.organizations = [defaultOrg]
                    organization = defaultOrg
                }
                
                guard let finalOrg = organization else {
                    authErrorMessage = "Unable to locate or create organization record."
                    isAuthenticating = false
                    return
                }
                
                var newUser = User(
                    id: authUser.id,
                    organizationID: finalOrg.id,
                    name: name,
                    role: role,
                    email: email,
                    password: password,
                    phone: phone,
                    title: role == .fleetManager ? "Fleet Manager" : role == .driver ? "Driver" : "Maintenance Personnel",
                    assignedVehicleID: nil
                )
                
                if role == .driver {
                    if let availableVehicle = service.vehicles.first(where: { $0.assignedDriverID == nil }) {
                        newUser.assignedVehicleID = availableVehicle.id
                        
                        var updatedVehicle = availableVehicle
                        updatedVehicle.assignedDriverID = newUser.id
                        updatedVehicle.status = .active
                        
                        // Link the vehicle in Supabase
                        try? await SupabaseService.shared.updateVehicle(updatedVehicle)
                    }
                }
                
                try await SupabaseService.shared.addProfile(newUser)
                
                await service.syncWithDatabase()
                currentUser = newUser
                organizationName = finalOrg.name
                flowState = .authenticated
            } catch {
                authErrorMessage = error.localizedDescription
            }
            isAuthenticating = false
            return
        }

        try? await Task.sleep(for: .seconds(0.8))

        if service.users.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            isAuthenticating = false
            authErrorMessage = "An account with this email already exists."
            return
        }

        guard let organization = service.organizations.first else {
            isAuthenticating = false
            authErrorMessage = "Unable to create account right now."
            return
        }

        try? await service.addUser(
            name: name,
            role: role,
            email: email,
            phone: phone,
            title: role == .fleetManager ? "Fleet Manager" : role == .driver ? "Driver" : "Maintenance Personnel",
            organizationID: organization.id
        )

        guard let user = service.authenticate(email: email, password: "demo123") else {
            isAuthenticating = false
            authErrorMessage = "Account created, but automatic sign in failed."
            return
        }

        if password != "demo123",
           let index = service.users.firstIndex(where: { $0.id == user.id }) {
            service.users[index].password = password
        }

        currentUser = service.authenticate(email: email, password: password)
        organizationName = organization.name
        isAuthenticating = false
        flowState = .authenticated
    }

    func showDemoRoles() {
        authErrorMessage = nil
        flowState = .demoRoleSelection
    }

    func loginAsDemo(role: UserRole) {
        guard let user = service.users(for: role).first else { return }
        currentUser = user
        flowState = .authenticated
    }

    func logout() {
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.client.auth.signOut()
            }
        }
        currentUser = nil
        flowState = .login
    }

    var unreadNotificationsCount: Int {
        service.notifications(for: currentUser).filter { !$0.isRead }.count
    }

    var currentRole: UserRole? {
        currentUser?.role
    }

    var currentOrganization: Organization? {
        guard let orgID = currentUser?.organizationID else { return service.organizations.first }
        return service.organizations.first(where: { $0.id == orgID })
    }
}
