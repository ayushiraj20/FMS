import SwiftUI
import MapKit

struct AssignDriverTripView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MockDataService

    // Step management
    enum AssignStep { case addTrip, selectDriver, selectVehicle, confirm }
    @State private var currentStep: AssignStep = .addTrip

    // Trip form fields
    @State private var tripStartLocation: String = ""
    @State private var tripDestination: String = ""
    @State private var routeDetails: String = ""
    @State private var notes: String = ""
    @State private var distanceStr: String = ""
    @State private var startDate: Date = Date().addingTimeInterval(3600 * 4)
    @State private var endDate: Date = Date().addingTimeInterval(3600 * 8)
    @State private var cargoType: CargoType = .generalGoods

    // Map
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 19.076, longitude: 72.877),
            span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
        )
    )

    // Driver/Vehicle search & selection
    @State private var driverSearch: String = ""
    @State private var vehicleSearch: String = ""
    @State private var selectedDriver: User? = nil
    @State private var selectedVehicle: Vehicle? = nil

    // Toast
    @State private var isShowingToast: Bool = false
    @State private var successMessage: String = ""

    enum CargoType: String, CaseIterable {
        case generalGoods   = "General Goods"
        case perishable     = "Perishable"
        case hazardous      = "Hazardous"
        case fragile        = "Fragile"
        case oversized      = "Oversized"
        case refrigerated   = "Refrigerated"
    }

    // Available drivers: role == .driver and not already assigned to a vehicle
    private var availableDrivers: [User] {
        let all = service.users.filter { user in
            user.role == .driver && !service.vehicles.contains { $0.assignedDriverID == user.id }
        }
        guard !driverSearch.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(driverSearch) ||
            $0.phone.localizedCaseInsensitiveContains(driverSearch) ||
            $0.email.localizedCaseInsensitiveContains(driverSearch)
        }
    }

    // Available vehicles: status == .active and no assigned driver
    private var availableVehicles: [Vehicle] {
        let all = service.vehicles.filter { $0.status == .active && $0.assignedDriverID == nil }
        guard !vehicleSearch.isEmpty else { return all }
        return all.filter {
            $0.plateNumber.localizedCaseInsensitiveContains(vehicleSearch) ||
            $0.displayName.localizedCaseInsensitiveContains(vehicleSearch) ||
            $0.model.localizedCaseInsensitiveContains(vehicleSearch)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch currentStep {
                    case .addTrip:       addTripView
                    case .selectDriver:  selectDriverView
                    case .selectVehicle: selectVehicleView
                    case .confirm:       confirmView
                    }
                }

                if isShowingToast {
                    successToast(message: successMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // ──────────────────────────────────────────────
    // STEP 1: Add Trip (matches screenshot design)
    // ──────────────────────────────────────────────
    private var addTripView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Map preview
                    Map(position: $cameraPosition)
                        .frame(height: 180)
                        .clipShape(Rectangle())

                    VStack(spacing: 16) {

                        // ROUTE INFORMATION
                        formSection(icon: "map", iconColor: Color(hex: "#007AFF"), title: "ROUTE INFORMATION") {
                            VStack(spacing: 0) {
                                routeField(
                                    icon: "pin.fill",
                                    iconColor: Color(hex: "#007AFF"),
                                    placeholder: "Enter pickup location (address, landmark...)",
                                    text: $tripStartLocation,
                                    showLocationButton: true
                                )
                                Divider().padding(.leading, 44)
                                routeField(
                                    icon: "mappin",
                                    iconColor: Color(hex: "#FF3B30"),
                                    placeholder: "Enter dropoff location (address, landmark...)",
                                    text: $tripDestination,
                                    showLocationButton: false
                                )
                            }
                        }

                        // CARGO DETAILS
                        formSection(icon: "shippingbox.fill", iconColor: Color(hex: "#007AFF"), title: "CARGO DETAILS") {
                            Menu {
                                ForEach(CargoType.allCases, id: \.self) { type in
                                    Button(type.rawValue) { cargoType = type }
                                }
                            } label: {
                                HStack {
                                    Text(cargoType.rawValue)
                                        .font(.body)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }

                        // SCHEDULE
                        formSection(icon: "calendar", iconColor: Color(hex: "#007AFF"), title: "SCHEDULE") {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Start Date")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    DatePicker("", selection: $startDate,
                                               in: Date().addingTimeInterval(3600 * 4)...,
                                               displayedComponents: [.date])
                                        .labelsHidden()
                                        .tint(AppTheme.brand)
                                    DatePicker("", selection: $startDate,
                                               in: Date().addingTimeInterval(3600 * 4)...,
                                               displayedComponents: [.hourAndMinute])
                                        .labelsHidden()
                                        .tint(AppTheme.brand)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                Divider().padding(.horizontal, 16)

                                HStack {
                                    Text("End Date")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    DatePicker("", selection: $endDate,
                                               in: startDate...,
                                               displayedComponents: [.date])
                                        .labelsHidden()
                                        .tint(AppTheme.brand)
                                    DatePicker("", selection: $endDate,
                                               in: startDate...,
                                               displayedComponents: [.hourAndMinute])
                                        .labelsHidden()
                                        .tint(AppTheme.brand)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                Text("Trip must start at least 4 hours from now")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                        }

                        // OPTIONAL DETAILS
                        formSection(icon: "note.text", iconColor: AppTheme.textSecondary, title: "ADDITIONAL DETAILS") {
                            VStack(spacing: 0) {
                                inlineTextField(placeholder: "Route details (e.g. via NH 275)", text: $routeDetails)
                                Divider().padding(.leading, 16)
                                inlineTextField(placeholder: "Distance in km (optional)", text: $distanceStr)
                                    .keyboardType(.decimalPad)
                                Divider().padding(.leading, 16)
                                inlineTextField(placeholder: "Notes / driver instructions", text: $notes)
                            }
                        }

                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }

            // Calculate Route CTA
            Button {
                guard !tripStartLocation.isEmpty && !tripDestination.isEmpty else { return }
                currentStep = .selectDriver
            } label: {
                Text("Calculate Route")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.brand)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(tripStartLocation.isEmpty || tripDestination.isEmpty)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Add New Trip")
    }

    private func formSection<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(0.5)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }

    private func routeField(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        showLocationButton: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
            if showLocationButton {
                Image(systemName: "location.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#007AFF"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func inlineTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
    }

    // ──────────────────────────────────────────────
    // STEP 2: Select Driver (searchable, large list)
    // ──────────────────────────────────────────────
    private var selectDriverView: some View {
        VStack(spacing: 0) {
            // Search
            searchField(text: $driverSearch, placeholder: "Search by name, phone, or email...")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            HStack {
                Text("\(availableDrivers.count) available drivers")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            List {
                ForEach(availableDrivers) { driver in
                    Button {
                        selectedDriver = driver
                        currentStep = .selectVehicle
                    } label: {
                        driverRow(driver)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Select Driver")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { currentStep = .addTrip } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }

    private func driverRow(_ driver: User) -> some View {
        let isOnDuty = service.dutyStatus(for: driver.id) == .onDuty
        let empCode = "DR-\(abs(driver.id.hashValue % 900) + 100)"

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(driver.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 8) {
                    Text(empCode)
                        .font(.system(size: 11).monospaced())
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(driver.phone)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Available")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.success.opacity(0.12))
                    .clipShape(Capsule())

                HStack(spacing: 3) {
                    Circle()
                        .fill(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                        .frame(width: 5, height: 5)
                    Text(isOnDuty ? "On Duty" : "Off Duty")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ──────────────────────────────────────────────
    // STEP 3: Select Vehicle (searchable, large list)
    // ──────────────────────────────────────────────
    private var selectVehicleView: some View {
        VStack(spacing: 0) {
            searchField(text: $vehicleSearch, placeholder: "Search by plate, model, or name...")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            HStack {
                Text("\(availableVehicles.count) active vehicles")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            List {
                ForEach(availableVehicles) { vehicle in
                    Button {
                        selectedVehicle = vehicle
                        currentStep = .confirm
                    } label: {
                        vehicleRow(vehicle)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Select Vehicle")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { currentStep = .selectDriver } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.brand.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vehicle.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(vehicle.plateNumber)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.brand.opacity(0.1))
                        .clipShape(Capsule())
                }
                Text(vehicle.model)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Active")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.success.opacity(0.12))
                    .clipShape(Capsule())

                HStack(spacing: 3) {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(vehicle.fuelLevel > 20 ? AppTheme.success : AppTheme.error)
                    Text("\(vehicle.fuelLevel)%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ──────────────────────────────────────────────
    // STEP 4: Confirm & Assign
    // ──────────────────────────────────────────────
    private var confirmView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Route summary card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill").foregroundStyle(AppTheme.brand)
                        Text("Route Summary")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)
                    }

                    HStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 4) {
                            Circle().fill(Color(hex: "#007AFF")).frame(width: 10, height: 10)
                            Rectangle()
                                .fill(LinearGradient(colors: [Color(hex: "#007AFF"), AppTheme.brand], startPoint: .top, endPoint: .bottom))
                                .frame(width: 2, height: 30)
                            Circle().fill(AppTheme.brand).frame(width: 10, height: 10)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tripStartLocation).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textPrimary)
                                Text("Pickup").font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tripDestination).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textPrimary)
                                Text("Drop-off").font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        Label(cargoType.rawValue, systemImage: "shippingbox")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Label(startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))

                // Driver chip
                if let driver = selectedDriver {
                    confirmChip(
                        icon: "person.fill",
                        color: Color(hex: "#007AFF"),
                        title: driver.name,
                        subtitle: "Driver · \(driver.phone)"
                    )
                }

                // Vehicle chip
                if let vehicle = selectedVehicle {
                    confirmChip(
                        icon: "truck.box.fill",
                        color: AppTheme.brand,
                        title: vehicle.displayName,
                        subtitle: "\(vehicle.model) · \(vehicle.plateNumber)"
                    )
                }

                // Assign button
                Button(action: handleAssignment) {
                    Text("Confirm Assignment & Schedule Trip")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? AppTheme.brand : Color(.systemGray4))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: isFormValid ? AppTheme.brand.opacity(0.3) : .clear, radius: 8, y: 4)
                }
                .disabled(!isFormValid)
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Confirm & Assign")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { currentStep = .selectVehicle } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }

    private func confirmChip(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textPrimary)
                Text(subtitle).font(.caption).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
    }

    // MARK: - Shared Components
    private func searchField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.subheadline)
            TextField(placeholder, text: text)
                .foregroundStyle(AppTheme.textPrimary)
                .font(.subheadline)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        selectedDriver != nil &&
        selectedVehicle != nil &&
        !tripStartLocation.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tripDestination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Handler
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

        successMessage = "Assigned \(vehicle.displayName) to \(driver.name)"
        withAnimation { isShowingToast = true }

        Task {
            try? await Task.sleep(for: .seconds(2))
            isShowingToast = false
            dismiss()
        }
    }

    // MARK: - Toast
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
