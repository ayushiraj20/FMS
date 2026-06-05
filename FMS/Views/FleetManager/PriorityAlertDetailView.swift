import SwiftUI
import MapKit

struct DetailedPriorityAlert: Identifiable {
    let id = UUID()
    let index: Int
    let category: String
    let title: String
    let timestampText: String
    let description: String
    let recommendedAction: String
    let severity: String
    let severityColor: Color
    let latitude: Double
    let longitude: Double
    let locationName: String
    
    // Linked Entities (optional)
    let driverName: String
    let driverPhone: String
    let driverTitle: String
    let vehicleName: String
    let vehiclePlate: String
    let vehicleStatus: String
    let vehicleOdometer: String
    let vehicleFuel: String
    let extraDetails: [String: String]
}

struct PriorityAlertDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedAlert: DetailedPriorityAlert?
    let category: String
    let count: Int
    
    var body: some View {
        let listAlerts = getAlerts(appViewModel: appViewModel)
        ScrollView {
            VStack(spacing: 16) {
                if listAlerts.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Alerts",
                        message: "No active alerts in this category."
                    )
                } else {
                    ForEach(listAlerts) { alert in
                        Button {
                            selectedAlert = alert
                        } label: {
                            alertCard(alert: alert)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("\(category) (\(max(listAlerts.count, count)))")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAlert) { alert in
            AlertDetailSheet(alert: alert)
                .registersSheetPresentation()
        }
    }
    
    private func alertCard(alert: DetailedPriorityAlert) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Severity Tag and Timestamp)
                HStack {
                    Text(alert.severity.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(alert.severityColor)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(alert.timestampText)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: alert.category))
                            .foregroundStyle(alert.severityColor)
                            .font(.subheadline)
                        
                        Text(alert.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    
                    Text(alert.description)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Divider().background(AppTheme.border)
                
                // Driver and Vehicle Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        // Driver Info
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DRIVER")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(alert.driverName)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Vehicle Info
                        HStack(spacing: 6) {
                            Image(systemName: "box.truck.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VEHICLE")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(alert.vehiclePlate)
                                    .font(.caption.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Category-Specific Telemetry / Details
                    HStack(spacing: 16) {
                        if alert.category == "SOS Alerts" {
                            if let trigger = alert.extraDetails["Trigger Type"] {
                                labelValueView(label: "TRIGGER", value: trigger, systemImage: "bolt.fill", iconColor: .orange)
                            }
                            if let speed = alert.extraDetails["Last Speed"] {
                                labelValueView(label: "LAST SPEED", value: speed, systemImage: "gauge.medium", iconColor: .red)
                            }
                        } else if alert.category == "Critical" || alert.category == "Maintenance" {
                            if let temp = alert.extraDetails["Temp Sensor"] {
                                labelValueView(label: "TEMP SENSOR", value: temp, systemImage: "thermometer.medium", iconColor: .red)
                            } else if let diagnostic = alert.extraDetails["Diagnostic Code"] {
                                labelValueView(label: "DTC CODE", value: diagnostic, systemImage: "wrench.and.screwdriver.fill", iconColor: .orange)
                            }
                            
                            if let wear = alert.extraDetails["Pad Wear Status"] {
                                labelValueView(label: "PAD WEAR", value: wear, systemImage: "exclamationmark.circle.fill", iconColor: .orange)
                            } else if let padLife = alert.extraDetails["Pad Life"] {
                                labelValueView(label: "PAD LIFE", value: padLife, systemImage: "percent", iconColor: .orange)
                            }
                        } else if alert.category == "Off-Route" {
                            if let route = alert.extraDetails["Original Route"] {
                                labelValueView(label: "ASSIGNED ROUTE", value: route, systemImage: "map.fill", iconColor: .blue)
                            }
                            if let deviation = alert.extraDetails["Deviation Distance"] {
                                labelValueView(label: "DEVIATION", value: deviation, systemImage: "arrow.triangle.turn.up.right.diamond.fill", iconColor: .red)
                            }
                        } else if alert.category == "Geofence" {
                            if let zoneName = alert.extraDetails["Zone Name"] {
                                labelValueView(label: "ZONE", value: zoneName, systemImage: "mappin.and.ellipse", iconColor: .red)
                            }
                            if let bannedHours = alert.extraDetails["Banned Hours"] {
                                labelValueView(label: "BANNED HOURS", value: bannedHours, systemImage: "clock.fill", iconColor: .red)
                            }
                        }
                    }
                }
                
                Divider().background(AppTheme.border)
                
                // Location Address
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(alert.severityColor)
                    Text(alert.locationName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func labelValueView(label: String, value: String, systemImage: String, iconColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func iconName(for cat: String) -> String {
        switch cat {
        case "SOS Alerts": return "exclamationmark.triangle.fill"
        case "Critical": return "bell.fill"
        case "Maintenance": return "wrench.and.screwdriver.fill"
        case "Off-Route": return "location.slash.fill"
        case "Geofence": return "mappin.and.ellipse"
        default: return "bell.fill"
        }
    }
    
    private func getAlerts(appViewModel: AppViewModel) -> [DetailedPriorityAlert] {
        switch category {
        case "SOS Alerts":
            return appViewModel.service.sosAlerts.enumerated().map { (idx, alert) in
                let driver  = appViewModel.service.users.first   { $0.id == alert.driverID }
                let vehicle = appViewModel.service.vehicles.first { $0.id == alert.vehicleID }

                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full

                return DetailedPriorityAlert(
                    index: idx + 1,
                    category: category,
                    title: "SOS: \(alert.emergencyType) (\(alert.driverName))",
                    timestampText: formatter.localizedString(for: alert.createdAt, relativeTo: Date()),
                    description: "SOS Status: \(alert.status). \(alert.emergencyType) distress reported. Coordinates: (\(alert.latitude), \(alert.longitude)).",
                    recommendedAction: "Dispatch emergency services immediately. Attempt to contact driver at \(driver?.phone ?? "N/A").",
                    severity: alert.status == "CLOSED" ? "Closed" : "Active",
                    severityColor: alert.status == "CLOSED" ? .green : AppTheme.error,
                    latitude: alert.latitude,
                    longitude: alert.longitude,
                    locationName: "Coordinates: \(alert.latitude), \(alert.longitude)",
                    driverName: alert.driverName,
                    driverPhone: driver?.phone ?? "N/A",
                    driverTitle: driver?.title ?? "Driver",
                    vehicleName: vehicle?.displayName ?? "Vehicle",
                    vehiclePlate: alert.vehicleNumber,
                    vehicleStatus: vehicle?.status.displayName ?? "Active",
                    vehicleOdometer: "\(vehicle?.odometer ?? 0) km",
                    vehicleFuel: "\(vehicle?.fuelLevel ?? 0)%",
                    extraDetails: [
                        "Trigger Type": "Panic Button / App Trigger",
                        "Latitude":     "\(alert.latitude)",
                        "Longitude":    "\(alert.longitude)",
                        "Status":       alert.status
                    ]
                )
            }

        case "Critical":
            return appViewModel.service.workOrders
                .filter { $0.priority == .critical && $0.status != .completed }
                .enumerated().map { (idx, order) in
                    let vehicle = appViewModel.service.vehicles.first { $0.id == order.vehicleID }
                    let driver  = appViewModel.service.users.first    { $0.id == vehicle?.assignedDriverID }
                    let maint   = appViewModel.service.users.first    { $0.id == order.assignedMaintenanceID }

                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .full

                    return DetailedPriorityAlert(
                        index: idx + 1,
                        category: category,
                        title: order.title,
                        timestampText: formatter.localizedString(for: order.scheduledDate, relativeTo: Date()),
                        description: order.details,
                        recommendedAction: "Assign maintenance team and inspect vehicle immediately.",
                        severity: "Critical",
                        severityColor: AppTheme.error,
                        latitude: 19.0760, longitude: 72.8777,
                        locationName: vehicle?.displayName ?? "Unknown Vehicle",
                        driverName: driver?.name ?? "Unassigned",
                        driverPhone: driver?.phone ?? "N/A",
                        driverTitle: driver?.title ?? "Driver",
                        vehicleName: vehicle?.displayName ?? "Unknown",
                        vehiclePlate: vehicle?.plateNumber ?? "—",
                        vehicleStatus: vehicle?.status.displayName ?? "Active",
                        vehicleOdometer: "\(vehicle?.odometer ?? 0) km",
                        vehicleFuel: "\(vehicle?.fuelLevel ?? 0)%",
                        extraDetails: [
                            "Assigned To": maint?.name ?? "Unassigned",
                            "Est. Cost":   "₹\(Int(order.estimatedCost))"
                        ]
                    )
                }

        case "Maintenance":
            return appViewModel.service.maintenanceSchedules
                .filter { $0.status == .overdue || $0.status == .upcoming }
                .enumerated().map { (idx, schedule) in
                    let vehicle = appViewModel.service.vehicles.first { $0.id == schedule.vehicleID }

                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .full

                    return DetailedPriorityAlert(
                        index: idx + 1,
                        category: category,
                        title: schedule.serviceType,
                        timestampText: formatter.localizedString(for: schedule.dueDate, relativeTo: Date()),
                        description: "\(schedule.serviceType) is \(schedule.status == .overdue ? "overdue" : "upcoming") for \(vehicle?.displayName ?? "this vehicle").",
                        recommendedAction: "Schedule a workshop visit as soon as possible.",
                        severity: schedule.status == .overdue ? "Overdue" : "Scheduled Service",
                        severityColor: schedule.status == .overdue ? AppTheme.error : AppTheme.brand,
                        latitude: 19.0760, longitude: 72.8777,
                        locationName: vehicle?.displayName ?? "Unknown Vehicle",
                        driverName: vehicle.flatMap { v in appViewModel.service.users.first { $0.id == v.assignedDriverID } }?.name ?? "Unassigned",
                        driverPhone: "N/A",
                        driverTitle: "Driver",
                        vehicleName: vehicle?.displayName ?? "Unknown",
                        vehiclePlate: vehicle?.plateNumber ?? "—",
                        vehicleStatus: vehicle?.status.displayName ?? "Active",
                        vehicleOdometer: "\(vehicle?.odometer ?? 0) km",
                        vehicleFuel: "\(vehicle?.fuelLevel ?? 0)%",
                        extraDetails: [
                            "Service Type": schedule.serviceType,
                            "Due Date": schedule.dueDate.formatted(date: .abbreviated, time: .omitted)
                        ]
                    )
                }

        default:
            return []
        }
    }}

struct AlertDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let alert: DetailedPriorityAlert
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Badge & Title
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(alert.severity.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(alert.severityColor)
                                .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text(alert.timestampText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Text(alert.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal)
                    
                    // Map snippet
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Annotation(alert.title, coordinate: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)) {
                            ZStack {
                                Circle()
                                    .fill(alert.severityColor.opacity(0.25))
                                    .frame(width: 44, height: 44)
                                Image(systemName: iconName(for: alert.category))
                                    .font(.body)
                                    .foregroundStyle(alert.severityColor)
                                    .padding(8)
                                    .background(.white, in: Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Location Address
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(alert.severityColor)
                        
                        Text(alert.locationName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALERT DESCRIPTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text(alert.description)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Recommended Action
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECOMMENDED ACTION")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(alert.severityColor)
                        
                        Text(alert.recommendedAction)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(alert.severityColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(alert.severityColor.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Driver Info Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ASSIGNED DRIVER")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 14) {
                            AvatarView(name: alert.driverName, size: 48)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.driverName)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(alert.driverPhone)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Call Action Button
                            if alert.driverPhone != "N/A" {
                                Button {
                                    if let url = URL(string: "tel://\(alert.driverPhone.replacingOccurrences(of: " ", with: ""))") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "phone.fill")
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.success, in: Circle())
                                }
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // Vehicle Info Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VEHICLE DETAILS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.brand.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "box.truck.fill")
                                    .foregroundStyle(AppTheme.brand)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.vehiclePlate)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(alert.vehicleName)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(alert.vehicleFuel)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Fuel Level")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // Extra Diagnostics Grid
                    if !alert.extraDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TELEMETRY DIAGNOSTICS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(alert.extraDetails.keys.sorted()), id: \.self) { key in
                                    HStack {
                                        Text(key)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Spacer()
                                        Text(alert.extraDetails[key] ?? "")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                    if key != alert.extraDetails.keys.sorted().last {
                                        Divider().background(AppTheme.border)
                                    }
                                }
                            }
                            .padding()
                            .background(AppTheme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Acknowledge") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }
    
    private func iconName(for cat: String) -> String {
        switch cat {
        case "SOS Alerts": return "exclamationmark.triangle.fill"
        case "Critical": return "bell.fill"
        case "Maintenance": return "wrench.and.screwdriver.fill"
        case "Off-Route": return "location.slash.fill"
        case "Geofence": return "mappin.and.ellipse"
        default: return "bell.fill"
        }
    }
}

#Preview {
    NavigationStack {
        PriorityAlertDetailView(category: "SOS Alerts", count: 3)
            .environment(AppViewModel())
    }
}
