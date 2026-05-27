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
        let rajesh = appViewModel.service.users.first { $0.name.contains("Rajesh") }
        let maya = appViewModel.service.users.first { $0.name.contains("Maya") }
        let tataAce = appViewModel.service.vehicles.first { $0.plateNumber == "TRK-2847" }
        let tataPrima = appViewModel.service.vehicles.first { $0.plateNumber == "TX-14-LGT" }
        let ashokLeyland = appViewModel.service.vehicles.first { $0.plateNumber == "NV-11-CRG" }
        let eicher = appViewModel.service.vehicles.first { $0.plateNumber == "AZ-09-RTE" }
        
        switch category {
        case "SOS Alerts":
            return [
                DetailedPriorityAlert(
                    index: 1,
                    category: category,
                    title: "SOS: Driver Distress Triggered",
                    timestampText: "2 mins ago",
                    description: "Emergency SOS trigger received from driver cab. Immediate assistance required.",
                    recommendedAction: "Dispatch emergency breakdown services immediately. Attempt to contact driver via phone.",
                    severity: "Emergency",
                    severityColor: AppTheme.error,
                    latitude: 19.0856,
                    longitude: 72.9082,
                    locationName: "LBS Road, Ghatkopar West, Mumbai",
                    driverName: rajesh?.name ?? "Rajesh Kumar",
                    driverPhone: rajesh?.phone ?? "+91 98765 43210",
                    driverTitle: rajesh?.title ?? "Senior Driver",
                    vehicleName: tataAce?.displayName ?? "Tata Ace",
                    vehiclePlate: tataAce?.plateNumber ?? "TRK-2847",
                    vehicleStatus: tataAce?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataAce?.odometer ?? 128420) km",
                    vehicleFuel: "\(tataAce?.fuelLevel ?? 74)%",
                    extraDetails: [
                        "Trigger Type": "In-cab Hard SOS Button",
                        "Last Speed": "0 km/h",
                        "Collision Detected": "No"
                    ]
                ),
                DetailedPriorityAlert(
                    index: 2,
                    category: category,
                    title: "SOS: Panic Alert Confirmed",
                    timestampText: "7 mins ago",
                    description: "Panic alert button activated. GPS tracking indicates vehicle has halted unexpectedly.",
                    recommendedAction: "Alert local security patrol and notify region traffic coordinator.",
                    severity: "Emergency",
                    severityColor: AppTheme.error,
                    latitude: 19.0330,
                    longitude: 73.0297,
                    locationName: "Sion-Panvel Highway, Panvel",
                    driverName: maya?.name ?? "Maya Singh",
                    driverPhone: maya?.phone ?? "+91 98765 43211",
                    driverTitle: maya?.title ?? "Linehaul Driver",
                    vehicleName: tataPrima?.displayName ?? "Tata Prima 5530",
                    vehiclePlate: tataPrima?.plateNumber ?? "TX-14-LGT",
                    vehicleStatus: tataPrima?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataPrima?.odometer ?? 96870) km",
                    vehicleFuel: "\(tataPrima?.fuelLevel ?? 56)%",
                    extraDetails: [
                        "Trigger Type": "Mobile App SOS",
                        "Last Speed": "12 km/h",
                        "Collision Detected": "No"
                    ]
                ),
                DetailedPriorityAlert(
                    index: 3,
                    category: category,
                    title: "SOS: Hard Impact Detected",
                    timestampText: "12 mins ago",
                    description: "High G-force impact alert triggered automatically from vehicle sensors.",
                    recommendedAction: "Call emergency highway rescue and check active traffic camera feed.",
                    severity: "Emergency",
                    severityColor: AppTheme.error,
                    latitude: 18.7557,
                    longitude: 73.4091,
                    locationName: "Expressway near Adoshi Tunnel, Lonavala",
                    driverName: "Unknown Driver",
                    driverPhone: "N/A",
                    driverTitle: "Driver",
                    vehicleName: ashokLeyland?.displayName ?? "Ashok Leyland 4220",
                    vehiclePlate: ashokLeyland?.plateNumber ?? "NV-11-CRG",
                    vehicleStatus: ashokLeyland?.status.rawValue ?? "In Service",
                    vehicleOdometer: "\(ashokLeyland?.odometer ?? 167540) km",
                    vehicleFuel: "\(ashokLeyland?.fuelLevel ?? 23)%",
                    extraDetails: [
                        "Trigger Type": "G-Sensor Crash Detect",
                        "Last Speed": "48 km/h",
                        "Collision Detected": "Yes"
                    ]
                )
            ]
        case "Critical":
            return [
                DetailedPriorityAlert(
                    index: 1,
                    category: category,
                    title: "Brakes: High Heat Alert",
                    timestampText: "5 mins ago",
                    description: "Brake pad sensors report critical temperature levels exceeding safety threshold (380°C).",
                    recommendedAction: "Instruct driver to pull over immediately. Do not attempt to apply heavy brakes.",
                    severity: "Critical",
                    severityColor: AppTheme.error,
                    latitude: 18.5204,
                    longitude: 73.8567,
                    locationName: "Katraj Bypass, Pune",
                    driverName: maya?.name ?? "Maya Singh",
                    driverPhone: maya?.phone ?? "+91 98765 43211",
                    driverTitle: maya?.title ?? "Linehaul Driver",
                    vehicleName: tataPrima?.displayName ?? "Tata Prima 5530",
                    vehiclePlate: tataPrima?.plateNumber ?? "TX-14-LGT",
                    vehicleStatus: tataPrima?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataPrima?.odometer ?? 96870) km",
                    vehicleFuel: "\(tataPrima?.fuelLevel ?? 56)%",
                    extraDetails: [
                        "Pad Wear Status": "25% life remaining",
                        "Temp Sensor": "Rear Axle Left (382°C)"
                    ]
                ),
                DetailedPriorityAlert(
                    index: 2,
                    category: category,
                    title: "Engine: Coolant Temperature",
                    timestampText: "10 mins ago",
                    description: "Engine coolant temperature has breached safe limits (112°C). High risk of engine failure.",
                    recommendedAction: "Halt vehicle immediately and check coolant reservoir level. Avoid opening hot cap.",
                    severity: "Critical",
                    severityColor: AppTheme.error,
                    latitude: 19.0760,
                    longitude: 72.8777,
                    locationName: "Western Express Highway, Bandra",
                    driverName: rajesh?.name ?? "Rajesh Kumar",
                    driverPhone: rajesh?.phone ?? "+91 98765 43210",
                    driverTitle: rajesh?.title ?? "Senior Driver",
                    vehicleName: tataAce?.displayName ?? "Tata Ace",
                    vehiclePlate: tataAce?.plateNumber ?? "TRK-2847",
                    vehicleStatus: tataAce?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataAce?.odometer ?? 128420) km",
                    vehicleFuel: "\(tataAce?.fuelLevel ?? 74)%",
                    extraDetails: [
                        "Coolant Temp": "112.5°C",
                        "Fan Status": "Active (High Speed)"
                    ]
                )
            ]
        case "Maintenance":
            return [
                DetailedPriorityAlert(
                    index: 1,
                    category: category,
                    title: "Engine Fault P0115",
                    timestampText: "4 mins ago",
                    description: "DTC code P0115: Engine Coolant Temperature circuit malfunction detected.",
                    recommendedAction: "Schedule workshop visit, inspect wiring harness and replace ECT sensor.",
                    severity: "Service Required",
                    severityColor: AppTheme.brand,
                    latitude: 19.0712,
                    longitude: 72.9984,
                    locationName: "Vashi Workshop Bay 4, Navi Mumbai",
                    driverName: rajesh?.name ?? "Rajesh Kumar",
                    driverPhone: rajesh?.phone ?? "+91 98765 43210",
                    driverTitle: rajesh?.title ?? "Senior Driver",
                    vehicleName: ashokLeyland?.displayName ?? "Ashok Leyland 4220",
                    vehiclePlate: ashokLeyland?.plateNumber ?? "NV-11-CRG",
                    vehicleStatus: ashokLeyland?.status.rawValue ?? "In Service",
                    vehicleOdometer: "\(ashokLeyland?.odometer ?? 167540) km",
                    vehicleFuel: "\(ashokLeyland?.fuelLevel ?? 23)%",
                    extraDetails: [
                        "Diagnostic Code": "P0115",
                        "Sensor Circuit Voltage": "0.12V (Low)"
                    ]
                ),
                DetailedPriorityAlert(
                    index: 2,
                    category: category,
                    title: "Brake Wear Indicator Active",
                    timestampText: "9 mins ago",
                    description: "Front axle brake pad wear indicator triggered check warning light.",
                    recommendedAction: "Schedule replacement of brake pad linings within next 500 km.",
                    severity: "Scheduled Service",
                    severityColor: AppTheme.brand,
                    latitude: 19.0431,
                    longitude: 73.0163,
                    locationName: "APMC Market Road, Vashi",
                    driverName: maya?.name ?? "Maya Singh",
                    driverPhone: maya?.phone ?? "+91 98765 43211",
                    driverTitle: maya?.title ?? "Linehaul Driver",
                    vehicleName: tataPrima?.displayName ?? "Tata Prima 5530",
                    vehiclePlate: tataPrima?.plateNumber ?? "TX-14-LGT",
                    vehicleStatus: tataPrima?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataPrima?.odometer ?? 96870) km",
                    vehicleFuel: "\(tataPrima?.fuelLevel ?? 56)%",
                    extraDetails: [
                        "Axle Trigger": "Front Left Axle",
                        "Pad Life": "12% Remaining"
                    ]
                )
            ]
        case "Off-Route":
            return [
                DetailedPriorityAlert(
                    index: 1,
                    category: category,
                    title: "Off-Route Deviation Detected",
                    timestampText: "1 min ago",
                    description: "Vehicle has departed from the assigned route boundary by more than 4.5 km.",
                    recommendedAction: "Contact the trip controller or driver to verify detour reason (road closure / rest stop).",
                    severity: "Out of Bounds",
                    severityColor: AppTheme.warning,
                    latitude: 18.7302,
                    longitude: 73.6841,
                    locationName: "Talegaon Toll Plaza Road, Pune Highway",
                    driverName: maya?.name ?? "Maya Singh",
                    driverPhone: maya?.phone ?? "+91 98765 43211",
                    driverTitle: maya?.title ?? "Linehaul Driver",
                    vehicleName: eicher?.displayName ?? "Eicher Pro 2110",
                    vehiclePlate: eicher?.plateNumber ?? "AZ-09-RTE",
                    vehicleStatus: eicher?.status.rawValue ?? "Idle",
                    vehicleOdometer: "\(eicher?.odometer ?? 41120) km",
                    vehicleFuel: "\(eicher?.fuelLevel ?? 91)%",
                    extraDetails: [
                        "Original Route": "Mumbai → Pune Warehouse",
                        "Deviation Distance": "4.8 km",
                        "GPS Status": "Locked (9 Satellites)"
                    ]
                )
            ]
        case "Geofence":
            return [
                DetailedPriorityAlert(
                    index: 1,
                    category: category,
                    title: "Restricted Geofence Breach",
                    timestampText: "15 mins ago",
                    description: "Unauthorized entry into 'Mumbai Restricted Zone' during banned hours.",
                    recommendedAction: "Check compliance documents or dispatch authority. Coordinate with local traffic coordinator.",
                    severity: "Unauthorized",
                    severityColor: AppTheme.error,
                    latitude: 19.0178,
                    longitude: 72.8478,
                    locationName: "Dadar Circle, Mumbai",
                    driverName: rajesh?.name ?? "Rajesh Kumar",
                    driverPhone: rajesh?.phone ?? "+91 98765 43210",
                    driverTitle: rajesh?.title ?? "Senior Driver",
                    vehicleName: tataAce?.displayName ?? "Tata Ace",
                    vehiclePlate: tataAce?.plateNumber ?? "TRK-2847",
                    vehicleStatus: tataAce?.status.rawValue ?? "Active",
                    vehicleOdometer: "\(tataAce?.odometer ?? 128420) km",
                    vehicleFuel: "\(tataAce?.fuelLevel ?? 74)%",
                    extraDetails: [
                        "Zone Name": "Mumbai Restricted Zone",
                        "Permit Required": "Zone Entry Type A",
                        "Banned Hours": "08:00 AM - 08:00 PM"
                    ]
                )
            ]
        default:
            return []
        }
    }
}

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
                    Button("Dismiss") {
                        dismiss()
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
