import SwiftUI
import MapKit

// MARK: - Trip Segment
enum TripSegment: String, CaseIterable {
    case ongoing   = "Ongoing"
    case scheduled = "Scheduled"
    case completed = "Completed"

    var icon: String {
        switch self {
        case .ongoing:   return "arrow.triangle.2.circlepath"
        case .scheduled: return "clock.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .ongoing:   return AppTheme.brand
        case .scheduled: return Color(hex: "#007AFF")
        case .completed: return AppTheme.success
        }
    }

    var matchingStatuses: [TripStatus] {
        switch self {
        case .ongoing:   return [.inProgress]
        case .scheduled: return [.scheduled]
        case .completed: return [.completed, .cancelled]
        }
    }
}

// MARK: - Main View
struct FleetManagerTripsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedSegment: TripSegment = .ongoing
    @State private var searchText: String = ""
    @State private var isPresentingAssignModal = false
    @State private var selectedTrip: Trip? = nil

    private func trips(for segment: TripSegment) -> [Trip] {
        let base = appViewModel.service.trips.filter {
            segment.matchingStatuses.contains($0.status)
        }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.origin.localizedCaseInsensitiveContains(searchText) ||
            $0.destination.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection

                    // Search bar (above segment control)
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    // iOS-style scrollable segmented control
                    iOSSegmentedControl
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    // Paged trip lists
                    TabView(selection: $selectedSegment) {
                        ForEach(TripSegment.allCases, id: \.self) { segment in
                            tripList(for: segment).tag(segment)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedSegment)
                }

                fabButton
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isPresentingAssignModal) {
                AssignDriverTripView(service: appViewModel.service)
            }
            .navigationDestination(item: $selectedTrip) { trip in
                AdminTripDetailView(trip: trip)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trips")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(appViewModel.service.trips.count) total trips")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if !trips(for: .ongoing).isEmpty {
                HStack(spacing: 5) {
                    Circle()
                        .fill(TripSegment.ongoing.accentColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(TripSegment.ongoing.accentColor.opacity(0.35), lineWidth: 4)
                                .scaleEffect(1.6)
                        )
                    Text("\(trips(for: .ongoing).count) Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TripSegment.ongoing.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TripSegment.ongoing.accentColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - iOS Native-style Segmented Control (scrollable)
    private var iOSSegmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(TripSegment.allCases, id: \.self) { segment in
                    iOSSegmentButton(segment)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(.systemGray5))
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func iOSSegmentButton(_ segment: TripSegment) -> some View {
        let isSelected = selectedSegment == segment
        let count = trips(for: segment).count

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedSegment = segment
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: segment.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(segment.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? segment.accentColor : Color(.systemGray))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? segment.accentColor.opacity(0.15)
                                      : Color(.systemGray4))
                        )
                }
            }
            .foregroundStyle(isSelected ? segment.accentColor : Color(.systemGray))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.clear)
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
                .font(.subheadline)
            TextField("Search by origin or destination...", text: $searchText)
                .foregroundStyle(AppTheme.textPrimary)
                .font(.subheadline)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
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

    // MARK: - Trip List
    private func tripList(for segment: TripSegment) -> some View {
        let items = trips(for: segment)
        return ScrollView {
            LazyVStack(spacing: 0) {
                if items.isEmpty {
                    emptyState(for: segment).padding(.top, 60)
                } else {
                    ForEach(items) { trip in
                        NavigationLink(value: trip) {
                            TripRowCard(
                                trip: trip,
                                driver: appViewModel.service.user(for: trip.driverID),
                                vehicle: appViewModel.service.vehicle(for: trip.vehicleID),
                                segment: segment
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    Spacer().frame(height: 100)
                }
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State
    private func emptyState(for segment: TripSegment) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(segment.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: segment.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(segment.accentColor.opacity(0.6))
            }
            Text("No \(segment.rawValue.lowercased()) trips")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(searchText.isEmpty ? "Trips will appear here once assigned." : "Try a different search.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - FAB
    private var fabButton: some View {
        Button { isPresentingAssignModal = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                Text("Assign Trip")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(AppTheme.brand)
            .clipShape(Capsule())
            .shadow(color: AppTheme.brand.opacity(0.45), radius: 12, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
    }
}

// MARK: - Trip Row Card
struct TripRowCard: View {
    let trip: Trip
    let driver: User?
    let vehicle: Vehicle?
    let segment: TripSegment

    @State private var isPressed = false

    private var statusColor: Color { segment.accentColor }

    private var statusLabel: String {
        switch trip.status {
        case .inProgress: return "Ongoing"
        case .completed:  return "Completed"
        case .scheduled:  return "Scheduled"
        case .cancelled:  return "Cancelled"
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f.string(from: trip.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Status pill + date
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Route
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(Color(hex: "#007AFF")).frame(width: 8, height: 8)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#007AFF"), statusColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 28)
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(trip.origin)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text("Pickup")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(trip.destination)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text("Drop-off")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(String(format: "%.0f km", trip.distanceKM))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Safety score row (if available)
            if let score = trip.safetyScore {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(score >= 80 ? AppTheme.success : AppTheme.warning)
                    Text("Safety \(score)/100")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    if let notes = trip.notes, !notes.isEmpty {
                        Spacer()
                        Text(notes)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }

            Divider().padding(.horizontal, 14)

            // Driver + vehicle footer
            HStack(spacing: 0) {
                if let driver = driver {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceSecondary)
                                .frame(width: 24, height: 24)
                            Text(String(driver.name.prefix(1)).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(driver.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.warning)
                        Text("No driver assigned")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                Spacer()
                if let vehicle = vehicle {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(vehicle.plateNumber)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .scaleEffect(isPressed ? 0.975 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

// MARK: - Admin Trip Detail View
struct AdminTripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    private var driver: User? { appViewModel.service.user(for: trip.driverID) }
    private var vehicle: Vehicle? { appViewModel.service.vehicle(for: trip.vehicleID) }
    private var checkpoints: [TripCheckpoint] {
        appViewModel.service.checkpoints(for: trip.id)
    }

    private let routeCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777),
        CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297),
        CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091),
        CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    ]

    @State private var cameraPosition: MapCameraPosition = .automatic

    private let collapsedHeight: CGFloat = 340

    private var statusAccent: Color {
        switch trip.status {
        case .inProgress: return AppTheme.brand
        case .scheduled:  return Color(hex: "#007AFF")
        case .completed:  return AppTheme.success
        case .cancelled:  return AppTheme.error
        }
    }

    private var statusLabel: String {
        switch trip.status {
        case .inProgress: return "Ongoing"
        case .completed:  return "Completed"
        case .scheduled:  return "Scheduled"
        case .cancelled:  return "Cancelled"
        }
    }

    private var formattedStart: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f.string(from: trip.startDate)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(statusAccent, lineWidth: 4)
                Annotation("", coordinate: routeCoordinates.first!) {
                    ZStack {
                        Circle().fill(.white).frame(width: 22, height: 22).shadow(radius: 4)
                        Circle().fill(Color(hex: "#007AFF")).frame(width: 12, height: 12)
                    }
                }
                Annotation("", coordinate: routeCoordinates.last!) {
                    ZStack {
                        Circle().fill(.white).frame(width: 22, height: 22).shadow(radius: 4)
                        Circle().fill(statusAccent).frame(width: 12, height: 12)
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle().fill(statusAccent).frame(width: 8, height: 8)
                                Text(statusLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(statusAccent)
                            }
                            Spacer()
                            Text("Trip · \(trip.id.uuidString.prefix(8).uppercased())")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        routeBlock
                        Divider()
                        statsRow
                        Divider()

                        if driver != nil || vehicle != nil {
                            assignmentSection
                            Divider()
                        }

                        if !checkpoints.isEmpty {
                            checkpointsSection
                            Divider()
                        }

                        if let notes = trip.notes, !notes.isEmpty {
                            notesSection(notes)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: collapsedHeight)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .navigationBarHidden(true)
        .task {
            let center = CLLocationCoordinate2D(latitude: 18.8, longitude: 73.15)
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            ))
        }
    }

    private var routeBlock: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 4) {
                Circle().fill(Color(hex: "#007AFF")).frame(width: 12, height: 12)
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "#007AFF"), statusAccent], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 42)
                Circle().fill(statusAccent).frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.origin).font(.headline).foregroundStyle(.primary)
                    Text(formattedStart).font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.destination).font(.headline).foregroundStyle(.primary)
                    if let end = trip.endDate {
                        let f = DateFormatter()
                        let _ = { f.dateFormat = "EEE, MMM d · h:mm a" }()
                        Text(f.string(from: end)).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("End time TBD").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(icon: "road.lanes",         label: "Distance",     value: String(format: "%.1f km", trip.distanceKM))
            Divider().frame(height: 36)
            statCell(icon: "shield.fill",        label: "Safety Score", value: trip.safetyScore.map { "\($0)/100" } ?? "—")
            Divider().frame(height: 36)
            statCell(icon: "mappin.and.ellipse", label: "Stops",        value: "\(checkpoints.count)")
        }
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(statusAccent)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignment")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 12) {
                if let driver = driver {
                    assignmentChip(icon: "person.fill", label: driver.name, sublabel: driver.title, color: Color(hex: "#007AFF"))
                }
                if let vehicle = vehicle {
                    assignmentChip(icon: "car.fill", label: vehicle.plateNumber, sublabel: vehicle.model, color: statusAccent)
                }
            }
        }
    }

    private func assignmentChip(icon: String, label: String, sublabel: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(sublabel).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checkpoints")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            ForEach(checkpoints.sorted { $0.sortOrder < $1.sortOrder }) { cp in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(cp.status == .completed ? AppTheme.success.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: cp.status == .completed ? "checkmark" : "clock")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(cp.status == .completed ? AppTheme.success : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cp.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                        if let arrival = cp.arrivalTime {
                            let f = DateFormatter()
                            let _ = { f.dateFormat = "h:mm a" }()
                            Text("Arrived \(f.string(from: arrival))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("#\(cp.sortOrder + 1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
