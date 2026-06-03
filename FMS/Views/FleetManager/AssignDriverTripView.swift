import SwiftUI
import MapKit

struct AssignDriverTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
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
    @State private var startDate: Date = Date().addingTimeInterval(7200)
    @State private var endDate: Date = Date().addingTimeInterval(7200 * 3)
    @State private var cargoType: CargoType = .generalGoods

    // Map & Location Search
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
            span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
        )
    )
    @State private var locationService = LocationSearchService()
    @State private var assignmentRoutePlan: TripRoutePlan?
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var activeField: LocationField? = nil
    @State private var routeCalculated: Bool = false

    enum LocationField { case origin, destination }

    // Driver/Vehicle search & selection
    @State private var driverSearch: String = ""
    @State private var vehicleSearch: String = ""
    @State private var selectedDriver: User? = nil
    @State private var selectedVehicle: Vehicle? = nil
    @State private var validationMessage: String? = nil

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

    // All drivers without an active trip — duty status is shown as info, not a filter.
    // This lets Fleet Managers pre-assign trips to off-duty drivers.
    private var availableDrivers: [User] {
        let all = service.driversEligibleForTripAssignment(
            organizationID: appViewModel.currentOrganization?.id
        ).filter { user in
            selectedVehicle.map { service.isDriver(user, compatibleWith: $0) } ?? true
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
        }
    }

    // ──────────────────────────────────────────────
    // STEP 1: Add Trip — Map + Location Search
    // ──────────────────────────────────────────────
    private var addTripView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Map preview with route
                    ZStack(alignment: .topTrailing) {
                        Map(position: $cameraPosition) {
                            if let assignmentRoutePlan {
                                TripRoutesMapContent(plan: assignmentRoutePlan)
                            } else if !locationService.routeCoordinates.isEmpty {
                                MapPolyline(coordinates: locationService.routeCoordinates)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(hex: "#007AFF"), AppTheme.brand],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                                    )
                            }

                            // Origin marker
                            if let coord = originCoordinate {
                                Annotation("Pickup", coordinate: coord) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#007AFF"))
                                            .frame(width: 28, height: 28)
                                            .shadow(color: Color(hex: "#007AFF").opacity(0.4), radius: 6)
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }

                            // Destination marker
                            if let coord = destinationCoordinate {
                                Annotation("Drop-off", coordinate: coord) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#FF3B30"))
                                            .frame(width: 28, height: 28)
                                            .shadow(color: Color(hex: "#FF3B30").opacity(0.4), radius: 6)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                        .frame(height: 220)
                        .clipShape(Rectangle())

                        // Route info overlay
                        if routeCalculated && locationService.routeDistanceKM > 0 {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "road.lanes")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("\(Int(locationService.routeDistanceKM)) km")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Divider().frame(height: 14)
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(formatETAString(locationService.routeETAMinutes))
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.9))
                            .background(AppTheme.brand.opacity(0.7))
                            .clipShape(Capsule())
                            .padding(12)
                        }
                    }

                    VStack(spacing: 16) {

                        // ROUTE INFORMATION with search
                        formSection(icon: "map", iconColor: Color(hex: "#007AFF"), title: "ROUTE INFORMATION") {
                            VStack(spacing: 0) {
                                // Pickup field
                                locationSearchField(
                                    icon: "pin.fill",
                                    iconColor: Color(hex: "#007AFF"),
                                    placeholder: "Search pickup location...",
                                    text: $tripStartLocation,
                                    field: .origin
                                )

                                // Pickup suggestions
                                if activeField == .origin && !locationService.suggestions.isEmpty {
                                    suggestionsListView(for: .origin)
                                }

                                Divider().padding(.leading, 44)

                                // Drop field
                                locationSearchField(
                                    icon: "mappin",
                                    iconColor: Color(hex: "#FF3B30"),
                                    placeholder: "Search drop-off location...",
                                    text: $tripDestination,
                                    field: .destination
                                )

                                // Drop suggestions
                                if activeField == .destination && !locationService.suggestions.isEmpty {
                                    suggestionsListView(for: .destination)
                                }
                            }
                        }

                        // Route calculation status
                        if locationService.isCalculatingRoute {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Calculating route...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.border, lineWidth: 0.5)
                            )
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
                                               in: Date().addingTimeInterval(7200)...,
                                               displayedComponents: [.date])
                                        .labelsHidden()
                                        .tint(AppTheme.brand)
                                    DatePicker("", selection: $startDate,
                                               in: Date().addingTimeInterval(7200)...,
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

                                Text("Trip must be scheduled at least 2 hours from now")
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
                                HStack {
                                    TextField("Distance in km", text: $distanceStr)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .keyboardType(.decimalPad)
                                    if routeCalculated && locationService.routeDistanceKM > 0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.success)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                Divider().padding(.leading, 16)
                                inlineTextField(placeholder: "Notes / driver instructions", text: $notes)
                            }
                        }

                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }

            // Next Step CTA
            VStack(spacing: 0) {
                Divider()
                Button {
                    guard !tripStartLocation.isEmpty && !tripDestination.isEmpty else { return }
                    currentStep = .selectVehicle
                } label: {
                    HStack(spacing: 8) {
                        if routeCalculated {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                        }
                        Text(routeCalculated ? "Continue — \(Int(locationService.routeDistanceKM)) km route" : "Select Vehicle")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                (tripStartLocation.isEmpty || tripDestination.isEmpty)
                                ? Color(.systemGray4)
                                : AppTheme.brand
                            )
                    )
                    .shadow(color: (tripStartLocation.isEmpty || tripDestination.isEmpty) ? .clear : AppTheme.brand.opacity(0.3), radius: 8, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .disabled(tripStartLocation.isEmpty || tripDestination.isEmpty)
            }
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Add New Trip")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Location Search Field
    private func locationSearchField(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        field: LocationField
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            TextField(placeholder, text: text, onEditingChanged: { isEditing in
                if isEditing {
                    activeField = field
                } else {
                    // Delay to allow tap on suggestion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if activeField == field {
                            activeField = nil
                            locationService.clearSuggestions()
                        }
                    }
                }
            })
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textPrimary)
            .onChange(of: text.wrappedValue) { _, newValue in
                if activeField == field {
                    locationService.search(query: newValue)
                }
            }

            // Clear button
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                    switch field {
                    case .origin:
                        originCoordinate = nil
                    case .destination:
                        destinationCoordinate = nil
                    }
                    routeCalculated = false
                    assignmentRoutePlan = nil
                    locationService.clearRoute()
                    locationService.clearSuggestions()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            // Geocoded indicator
            let hasCoord = field == .origin ? originCoordinate != nil : destinationCoordinate != nil
            if hasCoord {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Suggestions List
    private func suggestionsListView(for field: LocationField) -> some View {
        VStack(spacing: 0) {
            ForEach(locationService.suggestions.prefix(5), id: \.self) { suggestion in
                Button {
                    selectSuggestion(suggestion, for: field)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundStyle(field == .origin ? Color(hex: "#007AFF") : Color(hex: "#FF3B30"))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                if suggestion != locationService.suggestions.prefix(5).last {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(AppTheme.surfaceSecondary.opacity(0.5))
    }

    // MARK: - Select Suggestion
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion, for field: LocationField) {
        let displayText = suggestion.subtitle.isEmpty ? suggestion.title : "\(suggestion.title), \(suggestion.subtitle)"

        switch field {
        case .origin:
            tripStartLocation = displayText
        case .destination:
            tripDestination = displayText
        }

        activeField = nil
        locationService.clearSuggestions()

        // Geocode the selected suggestion
        Task {
            if let coordinate = await locationService.geocode(suggestion) {
                switch field {
                case .origin:
                    originCoordinate = coordinate
                case .destination:
                    destinationCoordinate = coordinate
                }

                // If both coordinates are set, calculate route
                if let origin = originCoordinate, let dest = destinationCoordinate {
                    await calculateAndDisplayRoute(from: origin, to: dest)
                } else if let coord = (field == .origin ? originCoordinate : destinationCoordinate) {
                    // Zoom to the single location
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Calculate & Display Route
    private func calculateAndDisplayRoute(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) async {
        await locationService.calculateRoute(from: origin, to: dest)
        assignmentRoutePlan = await TripRoutePlanningService.planRoutes(
            tripID: UUID(),
            origin: origin,
            destination: dest
        )

        if let assignmentRoutePlan {
            routeCalculated = true
            distanceStr = String(format: "%.1f", assignmentRoutePlan.mainDistanceKM)
            // Auto-set end date: start + ETA + 2hr buffer
            let etaSeconds = locationService.routeETAMinutes * 60
            let bufferSeconds: Double = 7200 // 2 hour buffer
            endDate = startDate.addingTimeInterval(etaSeconds + bufferSeconds)
        } else if locationService.routeDistanceKM > 0 {
            routeCalculated = true
            distanceStr = String(format: "%.1f", locationService.routeDistanceKM)
            // Auto-set end date: start + ETA + 2hr buffer
            let etaSeconds = locationService.routeETAMinutes * 60
            let bufferSeconds: Double = 7200 // 2 hour buffer
            endDate = startDate.addingTimeInterval(etaSeconds + bufferSeconds)

            // Fit map to show the entire route
            withAnimation(.easeInOut(duration: 0.8)) {
                let midLat = (origin.latitude + dest.latitude) / 2
                let midLng = (origin.longitude + dest.longitude) / 2
                let latDelta = abs(origin.latitude - dest.latitude) * 1.5 + 0.1
                let lngDelta = abs(origin.longitude - dest.longitude) * 1.5 + 0.1
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
                    span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.1), longitudeDelta: max(lngDelta, 0.1))
                ))
            }
        }
    }

    // MARK: - Format ETA
    private func formatETAString(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    // MARK: - Reusable Form Components
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
                Text("\(availableDrivers.count) eligible driver\(availableDrivers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Off-duty drivers can be pre-assigned")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.brand.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            List {
                ForEach(availableDrivers) { driver in
                    Button {
                        selectedDriver = driver
                        currentStep = .confirm
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
                HStack(spacing: 3) {
                    Circle()
                        .fill(isOnDuty ? AppTheme.success : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(isOnDuty ? "On Duty" : "Off Duty")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isOnDuty ? AppTheme.success : Color.orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((isOnDuty ? AppTheme.success : Color.orange).opacity(0.12))
                .clipShape(Capsule())

                Text("No active trip")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
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
                        selectedDriver = nil
                        currentStep = .selectDriver
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

                Text(service.requiredLicenseSummary(for: vehicle))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
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

                // Route map preview
                if assignmentRoutePlan != nil || !locationService.routeCoordinates.isEmpty {
                    Map(position: .constant(cameraPosition)) {
                        if let assignmentRoutePlan {
                            TripRoutesMapContent(plan: assignmentRoutePlan, showLabels: false)
                        } else {
                            MapPolyline(coordinates: locationService.routeCoordinates)
                                .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }

                        if let coord = originCoordinate {
                            Annotation("", coordinate: coord) {
                                Circle()
                                    .fill(Color(hex: "#007AFF"))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                        if let coord = destinationCoordinate {
                            Annotation("", coordinate: coord) {
                                Circle()
                                    .fill(Color(hex: "#FF3B30"))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
                    .allowsHitTesting(false)

                    if assignmentRoutePlan != nil {
                        TripRouteLegendView()
                            .padding(.top, 4)
                    }
                }

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
                                Text(tripStartLocation).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
                                Text("Pickup").font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tripDestination).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textPrimary).lineLimit(2)
                                Text("Drop-off").font(.caption).foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        Label(cargoType.rawValue, systemImage: "shippingbox")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        if routeCalculated {
                            Label("\(Int(locationService.routeDistanceKM)) km", systemImage: "road.lanes")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Label(formatETAString(locationService.routeETAMinutes), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
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
                        subtitle: "\(service.driverLicenseSummary(for: driver)) · \(driver.phone)"
                    )
                }

                // Vehicle chip
                if let vehicle = selectedVehicle {
                    confirmChip(
                        icon: "truck.box.fill",
                        color: AppTheme.brand,
                        title: vehicle.displayName,
                        subtitle: "\(vehicle.model) · \(vehicle.plateNumber) · Requires \(service.requiredLicenseSummary(for: vehicle))"
                    )
                }

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.error.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
        // The 2-hour buffer is enforced by the DatePicker minimum.
        // At confirm time, just ensure the start is still in the future.
        return selectedDriver != nil &&
        selectedVehicle != nil &&
        !tripStartLocation.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tripDestination.trimmingCharacters(in: .whitespaces).isEmpty &&
        startDate > Date() &&
        selectedPairIsCompatible
    }

    private var selectedPairIsCompatible: Bool {
        guard let driver = selectedDriver, let vehicle = selectedVehicle else { return false }
        return service.isDriver(driver, compatibleWith: vehicle)
    }

    // MARK: - Handler
    private func handleAssignment() {
        guard let driver = selectedDriver, let vehicle = selectedVehicle else { return }
        guard startDate > Date() else {
            validationMessage = "Trip start time must be in the future."
            return
        }
        guard service.isDriver(driver, compatibleWith: vehicle) else {
            validationMessage = "\(driver.name) is not licensed for \(vehicle.vehicleType)."
            return
        }
        let dist = Double(distanceStr) ?? 0.0

        Task {
            await service.addTripAssignment(
                driver: driver,
                vehicle: vehicle,
                origin: tripStartLocation,
                destination: tripDestination,
                routeDetails: routeDetails.isEmpty ? nil : routeDetails,
                notes: notes.isEmpty ? nil : notes,
                startDate: startDate,
                endDate: endDate,
                distanceKM: dist,
                originLat: originCoordinate?.latitude,
                originLng: originCoordinate?.longitude,
                destinationLat: destinationCoordinate?.latitude,
                destinationLng: destinationCoordinate?.longitude
            )

            successMessage = "Assigned \(vehicle.displayName) to \(driver.name) with ideal route and one hidden alternate route."
            withAnimation { isShowingToast = true }
        }

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
