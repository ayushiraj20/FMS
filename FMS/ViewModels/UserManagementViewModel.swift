import Foundation
import SwiftUI
import Combine

@MainActor
final class UserManagementViewModel: ObservableObject {
    private let service: MockDataService
    private let currentOrgID: UUID?

    // List State
    @Published var searchText = ""
    @Published var isPresentingCreateUser = false

    // Form Fields
    @Published var newUserName = ""
    @Published var newUserRole: UserRole = .driver
    @Published var newUserEmail = ""
    @Published var newUserPhone = ""
    @Published var newUserTitle = ""

    // Status State
    @Published var isCreating = false
    @Published var errorMessage: String? = nil

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var filteredUsers: [User] {
        service.users
            .filter { $0.role != .fleetManager }
            .filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
    }

    func resetForm() {
        newUserName = ""
        newUserRole = .driver
        newUserEmail = ""
        newUserPhone = ""
        newUserTitle = ""
        errorMessage = nil
    }

    func createUser() async -> Bool {
        guard let orgID = currentOrgID else {
            errorMessage = "Unable to locate your organization."
            return false
        }

        isCreating = true
        errorMessage = nil

        do {
            try await service.addUser(
                name: newUserName,
                role: newUserRole,
                email: newUserEmail,
                phone: newUserPhone,
                title: newUserTitle,
                organizationID: orgID
            )
            isCreating = false
            resetForm()
            isPresentingCreateUser = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }
}
