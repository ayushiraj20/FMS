import Foundation
import SwiftUI

import Observation

@Observable
@MainActor
final class UserManagementViewModel {
    private let service: MockDataService
    private let currentOrgID: UUID?

    // List State
    var searchText = ""
    var selectedRoleFilter: UserRole? = nil
    var isPresentingCreateUser = false

    // Form Fields
    var newUserName = ""
    var newUserRole: UserRole = .driver
    var newUserEmail = ""
    var newUserPhone = ""
    var newUserTitle = ""

    // Status State
    var isCreating = false
    var errorMessage: String? = nil

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var filteredUsers: [User] {
        service.users
            .filter { $0.role != .fleetManager }
            .filter { user in
                if let filter = selectedRoleFilter {
                    return user.role == filter
                }
                return true
            }
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

    func refresh() async {
        await service.syncWithDatabase()
    }
}
