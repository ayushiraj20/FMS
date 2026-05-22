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

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Details") {
                    TextField("Display Name", text: $viewModel.displayName)
                    TextField("Plate Number", text: $viewModel.plateNumber)
                    TextField("Model", text: $viewModel.model)
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(VehicleStatus.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    TextField("Odometer", text: $viewModel.odometer)
                        .keyboardType(.numberPad)
                }

                Section("Assignment") {
                    Picker("Assigned Driver", selection: $viewModel.assignedDriverID) {
                        Text("Unassigned").tag(Optional<UUID>.none)
                        ForEach(viewModel.drivers) { driver in
                            Text(driver.name).tag(Optional(driver.id))
                        }
                    }
                    DatePicker("Next Service", selection: $viewModel.nextServiceDate, displayedComponents: .date)
                    VStack(alignment: .leading) {
                        Text("Fuel Level")
                        Slider(value: $viewModel.fuelLevel, in: 0...100, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Utilization")
                        Slider(value: $viewModel.utilization, in: 0...100, step: 1)
                    }
                }
            }
            .navigationTitle(viewModel.selectedVehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.selectedVehicle == nil ? "Add" : "Save") {
                        viewModel.saveVehicle()
                        dismiss()
                    }
                    .disabled(viewModel.displayName.isEmpty || viewModel.plateNumber.isEmpty || viewModel.model.isEmpty || Int(viewModel.odometer) == nil)
                }
            }
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

                    // Mock AI Insights
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "target")
                                .foregroundStyle(Color(hex: "#ff3b30"))
                            Text("ETA Delay 45 min")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(Color(hex: "#ff3b30"))
                            Text("Route Deviation")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: "#ff3b30"))
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
                        
                        GeometryReader { barGeo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(hex: "#2A2A2A"))
                                Capsule()
                                    .fill(Color(hex: "#ff3b30"))
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
