import SwiftUI

struct AssignDriverTripView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MockDataService
    
    // Form Inputs State
    @State private var selectedDriver: User? = nil
    @State private var selectedVehicle: Vehicle? = nil
    
    @State private var tripStartLocation: String = ""
    @State private var tripDestination: String = ""
    @State private var routeDetails: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600 * 4) // +4 hours
    @State private var distanceStr: String = ""
    
    // Toast state
    @State private var isShowingToast: Bool = false
    @State private var successMessage: String = ""
    
    // Fetch available drivers (role is driver, and they have no vehicle assigned in vehicles list)
    private var availableDrivers: [User] {
        service.users.filter { user in
            user.role == .driver && !service.vehicles.contains { $0.assignedDriverID == user.id }
        }
    }
    
    // Fetch available vehicles (status == Active and assignedDriverID == nil)
    private var availableVehicles: [Vehicle] {
        service.vehicles.filter { vehicle in
            vehicle.status == .active && vehicle.assignedDriverID == nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // SECTION 1: AVAILABLE DRIVERS
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Select Available Driver")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            if availableDrivers.isEmpty {
                                Text("No available drivers without vehicle pairings.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(availableDrivers) { driver in
                                            driverCard(driver: driver)
                                                .onTapGesture {
                                                    withAnimation {
                                                        selectedDriver = (selectedDriver?.id == driver.id) ? nil : driver
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // SECTION 2: AVAILABLE VEHICLES
                        VStack(alignment: .leading, spacing: 10) {
                            Text("2. Select Active Vehicle")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            if availableVehicles.isEmpty {
                                Text("No active unassigned vehicles left.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(availableVehicles) { vehicle in
                                            vehicleCard(vehicle: vehicle)
                                                .onTapGesture {
                                                    withAnimation {
                                                        selectedVehicle = (selectedVehicle?.id == vehicle.id) ? nil : vehicle
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // SECTION 3: TRIP SCHEDULING FORM
                        VStack(alignment: .leading, spacing: 16) {
                            Text("3. Trip Scheduling Details")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            VStack(spacing: 12) {
                                customTextField(label: "Trip Start Location *", placeholder: "e.g. Mysuru Warehouse", text: $tripStartLocation)
                                customTextField(label: "Trip Destination *", placeholder: "e.g. Bengaluru Hub", text: $tripDestination)
                                customTextField(label: "Route Details", placeholder: "e.g. via NH 275 and outer ring road", text: $routeDetails)
                                customTextField(label: "Distance (km) [Optional]", placeholder: "e.g. 140", text: $distanceStr)
                                    .keyboardType(.decimalPad)
                                
                                DatePicker("Start Date & Time", selection: $startDate, in: Date()...)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.vertical, 6)
                                
                                DatePicker("End Date & Time", selection: $endDate, in: startDate...)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.vertical, 6)
                                
                                customTextField(label: "Notes / Driver Instructions", placeholder: "e.g. Deliver load by 6 PM. Check engine temperature.", text: $notes)
                            }
                            .padding(16)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal)
                        
                        // SUBMIT BUTTON
                        Button(action: handleAssignment) {
                            Text("Confirm Assignment & Schedule Trip")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isFormValid ? AppTheme.brand : Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: isFormValid ? AppTheme.brand.opacity(0.3) : Color.clear, radius: 8, y: 4)
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 80)
                    }
                    .padding(.top)
                }
                
                // Success Toast Overlay
                if isShowingToast {
                    successToast(message: successMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("New Driver Assignment & Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        selectedDriver != nil &&
        selectedVehicle != nil &&
        !tripStartLocation.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tripDestination.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Handlers
    private func handleAssignment() {
        guard let driver = selectedDriver, let vehicle = selectedVehicle else { return }
        
        let dist = Double(distanceStr) ?? 0.0
        
        service.addTripAssignment(
            driver: driver,
            vehicle: vehicle,
            origin: tripStartLocation,
            destination: tripDestination,
            routeDetails: routeDetails.isEmpty ? nil : routeDetails,
            notes: notes.isEmpty ? nil : notes,
            startDate: startDate,
            endDate: endDate,
            distanceKM: dist
        )
        
        // Show Toast
        successMessage = "Assigned \(vehicle.displayName) to \(driver.name)"
        withAnimation {
            isShowingToast = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            isShowingToast = false
            dismiss()
        }
    }
    
    // MARK: - UI Components
    
    private func driverCard(driver: User) -> some View {
        let isSelected = selectedDriver?.id == driver.id
        let empCode = "DR-\(abs(driver.id.hashValue % 900) + 100)"
        let isOnDuty = service.dutyStatus(for: driver.id) == .onDuty
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.brand)
                }
                
                Spacer()
                
                // Selection Circle
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.brand : AppTheme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(driver.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(empCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            HStack {
                // Duty Status Badges
                HStack(spacing: 3) {
                    Circle()
                        .fill(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                        .frame(width: 5, height: 5)
                    Text(isOnDuty ? "On Duty" : "Off Duty")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                }
                
                Spacer()
                
                Text("Available")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.success)
            }
        }
        .frame(width: 145, height: 125)
        .padding(12)
        .background(isSelected ? AppTheme.brand.opacity(0.06) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? AppTheme.brand : AppTheme.border, lineWidth: isSelected ? 1.5 : 0.5)
        )
    }
    
    private func vehicleCard(vehicle: Vehicle) -> some View {
        let isSelected = selectedVehicle?.id == vehicle.id
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.brand.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: "truck.box.fill")
                        .foregroundStyle(AppTheme.brand)
                }
                
                Spacer()
                
                // Selection Circle
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.brand : AppTheme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(vehicle.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(vehicle.plateNumber)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            HStack {
                // Fuel level indicator
                HStack(spacing: 3) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(vehicle.fuelLevel > 20 ? AppTheme.success : AppTheme.error)
                    Text("\(vehicle.fuelLevel)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Text(vehicle.status.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.brand)
            }
        }
        .frame(width: 145, height: 125)
        .padding(12)
        .background(isSelected ? AppTheme.brand.opacity(0.06) : AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? AppTheme.brand : AppTheme.border, lineWidth: isSelected ? 1.5 : 0.5)
        )
    }
    
    private func customTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            
            TextField(placeholder, text: text)
                .font(.subheadline)
                .padding(12)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
    
    private func successToast(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Capsule().fill(AppTheme.success))
            .shadow(color: AppTheme.success.opacity(0.4), radius: 10, y: 4)
            .padding(.top, 20)
            Spacer()
        }
    }
}
