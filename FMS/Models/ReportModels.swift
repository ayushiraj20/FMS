import Foundation

enum FleetReportSeverity: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case watch = "Watch"
    case action = "Action"
    case critical = "Critical"

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .normal: return 0
        case .watch: return 1
        case .action: return 2
        case .critical: return 3
        }
    }
}

struct FleetReportSnapshot: Identifiable {
    let id = UUID()
    let generatedAt: Date
    let summary: FleetReportSummary
    let maintenance: MaintenanceReportSummary
    let inventory: InventoryReportSummary
    let fuel: FuelReportSummary
    let compliance: ComplianceReportSummary
    let routing: RoutingReportSummary
    let recommendations: [FleetReportRecommendation]
}

struct FleetReportSummary {
    let totalVehicles: Int
    let activeVehicles: Int
    let averageUtilization: Double
    let averageOdometer: Double
    let openWorkOrders: Int
    let unresolvedDefects: Int
}

struct MaintenanceReportSummary {
    let totalWorkOrders: Int
    let openWorkOrders: Int
    let completedWorkOrders: Int
    let overdueWorkOrders: Int
    let criticalWorkOrders: Int
    let totalEstimatedCost: Double
    let averageEstimatedCost: Double
    let upcomingServiceCount: Int
    let rows: [MaintenanceReportRow]
}

struct MaintenanceReportRow: Identifiable {
    let id = UUID()
    let vehicleID: UUID
    let vehicleName: String
    let plateNumber: String
    let nextServiceDate: Date
    let daysToService: Int
    let openWorkOrders: Int
    let unresolvedDefects: Int
    let estimatedCost: Double
    let severity: FleetReportSeverity
    let recommendation: String
}

struct InventoryReportSummary {
    let totalPartTypes: Int
    let totalQuantity: Int
    let lowStockCount: Int
    let outOfStockCount: Int
    let forecastRows: [SparePartForecastReport]
}

struct SparePartForecastReport: Identifiable {
    let id: UUID
    let name: String
    let partNumber: String
    let category: String
    let onHand: Int
    let minimumRequired: Int
    let forecastMonthlyUsage: Double
    let daysOfCover: Int
    let reorderQuantity: Int
    let orderByDate: Date?
    let severity: FleetReportSeverity
}

struct FuelReportSummary {
    let totalSpend: Double
    let verifiedSpend: Double
    let pendingTransactions: Int
    let averageConsumption: Double
    let benchmarkConsumption: Double
    let potentialLitresSavedMonthly: Double
    let highConsumptionVehicles: [FuelVehicleReport]
}

struct FuelVehicleReport: Identifiable {
    let id: UUID
    let vehicleName: String
    let plateNumber: String
    let consumption: Double
    let benchmark: Double
    let monthlyDistanceEstimate: Double
    let potentialLitresSaved: Double
    let severity: FleetReportSeverity
}

struct ComplianceReportSummary {
    let totalDocuments: Int
    let expiredCount: Int
    let expiringSoonCount: Int
    let missingCount: Int
    let alerts: [ComplianceAlertReport]
}

struct ComplianceAlertReport: Identifiable {
    let id = UUID()
    let vehicleID: UUID
    let vehicleName: String
    let plateNumber: String
    let documentType: DocumentType
    let status: String
    let dueDate: Date?
    let severity: FleetReportSeverity
    let alertKey: String
}

struct RoutingReportSummary {
    let averageTripDistance: Double
    let repeatedRoutes: [RouteOptimizationReport]
    let idleVehicles: Int
    let overloadedVehicles: Int
    let recommendation: String
}

struct RouteOptimizationReport: Identifiable {
    let id = UUID()
    let routeName: String
    let tripCount: Int
    let averageDistance: Double
    let assignedVehicleCount: Int
    let severity: FleetReportSeverity
}

struct FleetReportRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let severity: FleetReportSeverity
    let iconName: String
}
