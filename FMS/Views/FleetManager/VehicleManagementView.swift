import SwiftUI

struct VehicleManagementView: View {
    @State private var viewModel: VehicleManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: VehicleManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                VStack(spacing: 20) {
                    // Custom Search Bar
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("Search vehicles...", text: $viewModel.searchText)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(12)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: {}) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.title2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal)

                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            filterPill(title: "All", count: viewModel.allCount, status: nil)
                            filterPill(title: "Active", count: viewModel.activeCount, status: .active)
                            filterPill(title: "In Transit", count: viewModel.inTransitCount, status: .inService)
                            filterPill(title: "Idle", count: viewModel.idleCount, status: .idle)
                        }
                        .padding(.horizontal)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))

                // Vehicle List
                ForEach(viewModel.filteredVehicles) { vehicle in
                    ZStack {
                        VehicleCardView(vehicle: vehicle)
                        NavigationLink(destination: VehicleDetailView(viewModel: viewModel, vehicleID: vehicle.id)) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteVehicle(vehicle)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            viewModel.prepareForEdit(vehicle)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppTheme.brand)
                    }
                }
                
                Color.clear
                    .frame(height: 100) // Space for FAB
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, 10)

            // Floating Action Button
            Button(action: {
                viewModel.prepareForAdd()
            }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.brand)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.brand.opacity(0.7), radius: 15, y: 0)
            }
            .padding(.bottom, 24)
            .padding(.trailing, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("Vehicles")
        .sheet(isPresented: $viewModel.isPresentingForm) {
            VehicleFormSheet(viewModel: viewModel)
        }
    }

    private func filterPill(title: String, count: Int, status: VehicleStatus?) -> some View {
        let isSelected = viewModel.selectedStatusFilter == status
        return Button {
            withAnimation {
                viewModel.selectedStatusFilter = status
            }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .frame(minWidth: 70)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? AppTheme.surfaceSecondary : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.textSecondary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
    }
}

private struct VehicleCardView: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 16) {
            // Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 80, height: 80)
                Image(systemName: "box.truck.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vehicle.plateNumber)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                }

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                HStack {
                    Text(mockRoute)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text("\(vehicle.utilization)%")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch vehicle.status {
        case .active: return Color(hex: "#00a2ff") // Blue
        case .inService: return Color(hex: "#cddb32") // Yellow-green
        case .idle: return Color(hex: "#34c759") // Green
        case .outOfService: return Color(hex: "#ff3b30") // Red
        }
    }

    private var statusText: String {
        switch vehicle.status {
        case .active: return "On Route"
        case .inService: return "In Transit!"
        case .idle: return "Idle"
        case .outOfService: return "Maintenance"
        }
    }

    private var mockRoute: String {
        switch vehicle.status {
        case .active: return "Mumbai → Pune"
        case .inService: return "Pune → Nashik"
        case .idle: return "Nagpur Yard"
        case .outOfService: return "Workshop"
        }
    }
}

private struct VehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VehicleManagementViewModel

    private var isEditing: Bool { viewModel.selectedVehicle != nil }
    private var canSave: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.plateNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.model.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(viewModel.odometer) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Hero icon
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.brand.opacity(0.15))
                                    .frame(width: 72, height: 72)
                                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(AppTheme.brand)
                            }
                            Text(isEditing ? "Edit Vehicle Info" : "Add New Vehicle")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(isEditing ? "Update the details below and tap Save." : "Fill in the details to register a new vehicle.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 8)

                        // ── Vehicle Details Card ──
                        formSection(title: "Vehicle Details", icon: "car.fill") {
                            formField(label: "Display Name", placeholder: "e.g. Truck Alpha", text: $viewModel.displayName)
                            divider
                            formField(label: "Plate Number", placeholder: "e.g. MH12AB1234", text: $viewModel.plateNumber)
                            divider
                            formField(label: "Model", placeholder: "e.g. Tata Ace", text: $viewModel.model)
                            divider
                            formField(label: "Odometer (km)", placeholder: "e.g. 52000", text: $viewModel.odometer, keyboard: .numberPad)
                            divider

                            // Status picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Status")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(VehicleStatus.allCases, id: \.self) { s in
                                            let selected = viewModel.status == s
                                            Button { viewModel.status = s } label: {
                                                Text(s.rawValue)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(selected ? .white : AppTheme.textSecondary)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selected ? AppTheme.brand : AppTheme.surfaceSecondary)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(selected ? AppTheme.brand : AppTheme.border, lineWidth: 1))
                                                    .animation(.easeInOut(duration: 0.2), value: selected)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Assignment Card ──
                        formSection(title: "Assignment & Metrics", icon: "person.badge.key.fill") {

                            // Driver picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Assigned Driver")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        driverChip(name: "Unassigned", id: nil)
                                        ForEach(viewModel.drivers) { d in
                                            driverChip(name: d.name, id: d.id)
                                        }
                                    }
                                }
                            }
                            divider

                            // Next Service Date
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Next Service Date")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                DatePicker("", selection: $viewModel.nextServiceDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(AppTheme.brand)
                            }
                            divider

                            // Fuel level slider
                            sliderRow(
                                label: "Fuel Level",
                                icon: "fuelpump.fill",
                                value: $viewModel.fuelLevel,
                                color: viewModel.fuelLevel > 50 ? Color(hex: "#34c759") : viewModel.fuelLevel > 20 ? Color(hex: "#ffcc00") : Color(hex: "#ff3b30")
                            )
                            divider

                            // Utilization slider
                            sliderRow(
                                label: "Utilization",
                                icon: "chart.bar.fill",
                                value: $viewModel.utilization,
                                color: AppTheme.brand
                            )
                        }

                        // Save button
                        Button {
                            viewModel.saveVehicle()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(isEditing ? "Save Changes" : "Add Vehicle")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                canSave
                                ? LinearGradient(colors: [AppTheme.brand, AppTheme.brand.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppTheme.surfaceSecondary, AppTheme.surfaceSecondary], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: canSave ? AppTheme.brand.opacity(0.4) : .clear, radius: 10, y: 4)
                            .animation(.easeInOut(duration: 0.2), value: canSave)
                        }
                        .disabled(!canSave)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }

    // MARK: – Helpers

    private var divider: some View {
        Divider().background(AppTheme.border)
    }

    private func formSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.brand)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            VStack(spacing: 14) {
                content()
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
        }
    }

    private func driverChip(name: String, id: UUID?) -> some View {
        let selected = viewModel.assignedDriverID == id
        return Button { viewModel.assignedDriverID = id } label: {
            HStack(spacing: 6) {
                if id != nil {
                    AvatarView(name: name, size: 20)
                } else {
                    Image(systemName: "person.slash")
                        .font(.caption2)
                        .foregroundStyle(selected ? .white : AppTheme.textSecondary)
                }
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? .white : AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? AppTheme.brand : AppTheme.surfaceSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? AppTheme.brand : AppTheme.border, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
    }

    private func sliderRow(label: String, icon: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(color)
        }
    }
}

private struct VehicleDetailView: View {
    @Bindable var viewModel: VehicleManagementViewModel
    let vehicleID: UUID

    enum VehicleActionSheet: String, Identifiable {
        case liveView, tripDetails, ping, more
        var id: String { rawValue }
    }

    @State private var activeSheet: VehicleActionSheet?
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(AppTheme.brand).frame(width: 24, height: 24)
                    Text("1").font(.caption.weight(.bold)).foregroundStyle(.white)
                }
                Text("Vehicle Details")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("(AI Prioritized)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .padding()

            if let vehicle = viewModel.vehicle(for: vehicleID) {
                VehicleCarouselCard(viewModel: viewModel, vehicle: vehicle, isSelected: true)
            } else {
                Spacer()
                Text("Vehicle not found")
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            // Action Bar
            HStack(spacing: 12) {
                actionButton(icon: "viewfinder", title: "Live View") { activeSheet = .liveView }
                actionButton(icon: "doc.text", title: "Trip Details") { activeSheet = .tripDetails }
                actionButton(icon: "antenna.radiowaves.left.and.right", title: "Ping") { activeSheet = .ping }
                actionButton(icon: "ellipsis", title: "More") { activeSheet = .more }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let vehicle = viewModel.vehicle(for: vehicleID) {
                        viewModel.prepareForEdit(vehicle)
                        showEditSheet = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleFormSheet(viewModel: viewModel)
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                ZStack {
                    AppTheme.background.ignoresSafeArea()
                    VStack {
                        Spacer()
                        Image(systemName: sheetIcon(for: sheet))
                            .font(.system(size: 60))
                            .foregroundStyle(Color("AccentColor"))
                            .padding(.bottom, 20)
                        Text(sheetTitle(for: sheet))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Details coming soon.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                }
                .navigationTitle(sheetTitle(for: sheet))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            activeSheet = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func sheetIcon(for sheet: VehicleActionSheet) -> String {
        switch sheet {
        case .liveView: return "viewfinder"
        case .tripDetails: return "doc.text"
        case .ping: return "antenna.radiowaves.left.and.right"
        case .more: return "ellipsis"
        }
    }

    private func sheetTitle(for sheet: VehicleActionSheet) -> String {
        switch sheet {
        case .liveView: return "Live View"
        case .tripDetails: return "Trip Details"
        case .ping: return "Ping Vehicle"
        case .more: return "More Options"
        }
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.surfaceSecondary)
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct VehicleCarouselCard: View {
    @Bindable var viewModel: VehicleManagementViewModel
    let vehicle: Vehicle
    let isSelected: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Mock Image area
                ZStack {
                    Rectangle()
                        .fill(AppTheme.surfaceSecondary)
                    
                    Image(systemName: "box.truck.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                }
                .frame(height: geometry.size.height * 0.45)
                .overlay(
                    LinearGradient(colors: [Color.black.opacity(0.1), AppTheme.cardBackground], startPoint: .top, endPoint: .bottom)
                )

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.plateNumber)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Driver \(viewModel.user(for: vehicle.assignedDriverID)?.name.components(separatedBy: " ").first ?? "Unassigned")")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if vehicle.status == .outOfService || vehicle.utilization < 50 {
                            Text("Critical")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(hex: "#ff3b30"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#ff3b30").opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color(hex: "#ff3b30").opacity(0.3), lineWidth: 1))
                        }
                    }

                    // Dynamic AI Insights & Alerts
                    VStack(alignment: .leading, spacing: 10) {
                        let activeAlerts = viewModel.alerts(for: vehicle.id)
                        let activeDefects = viewModel.defects(for: vehicle.id).filter { !$0.isResolved }
                        
                        if !activeAlerts.isEmpty || !activeDefects.isEmpty {
                            ForEach(activeAlerts.prefix(2)) { alert in
                                HStack(spacing: 8) {
                                    Image(systemName: alert.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                        .foregroundStyle(alert.severity == .critical ? Color(hex: "#ff3b30") : Color(hex: "#ffcc00"))
                                    Text(alert.alertDescription)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                            ForEach(activeDefects.prefix(2 - activeAlerts.count)) { defect in
                                HStack(spacing: 8) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .foregroundStyle(defect.severity == .critical || defect.severity == .high ? Color(hex: "#ff3b30") : Color(hex: "#ff9500"))
                                    Text(defect.title ?? defect.description)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            switch vehicle.status {
                            case .active, .inService:
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "#34c759"))
                                    Text("On Route — Optimal Performance")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(Color(hex: "#34c759"))
                                    Text("Eco-Driving Style Detected")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            case .idle:
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text("Parked — Idle Status")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "battery.100percent")
                                        .foregroundStyle(Color(hex: "#34c759"))
                                    Text("Battery Health: 98% (Optimal)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            case .outOfService:
                                HStack(spacing: 8) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .foregroundStyle(Color(hex: "#ff3b30"))
                                    Text("In Workshop for Diagnostics")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(Color(hex: "#ffcc00"))
                                    Text("Inspection Log Pending")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Fuel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fuel")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(vehicle.fuelLevel)%")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        let fuelColor: Color = {
                            if vehicle.fuelLevel > 50 { return Color(hex: "#34c759") } // Green
                            else if vehicle.fuelLevel > 20 { return Color(hex: "#ffcc00") } // Yellow
                            else { return Color(hex: "#ff3b30") } // Red
                        }()
                        
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "#2A2A2A"))
                                Capsule()
                                    .fill(fuelColor)
                                    .frame(width: barGeo.size.width * CGFloat(vehicle.fuelLevel) / 100.0)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? AppTheme.brand : AppTheme.border, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? AppTheme.brand.opacity(0.6) : .clear, radius: 15, y: 0)
            .padding(.horizontal, isSelected ? 20 : 40)
            .scaleEffect(isSelected ? 1.0 : 0.9)
            .opacity(isSelected ? 1.0 : 0.6)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
    }
}

private struct DocumentUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VehicleManagementViewModel
    let vehicleID: UUID

    var body: some View {
        NavigationStack {
            Form {
                Picker("Document Type", selection: $viewModel.docType) {
                    ForEach(DocumentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Document Number", text: $viewModel.docNumber)
                DatePicker("Expiry Date", selection: $viewModel.docExpiryDate, displayedComponents: .date)
            }
            .navigationTitle("Upload Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveDocument(for: vehicleID)
                        dismiss()
                    }
                    .disabled(viewModel.docNumber.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VehicleManagementView(service: MockDataService(), currentOrgID: UUID())
    }
}
