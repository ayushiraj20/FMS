import Foundation

struct FleetReportService {
    func generateFleetSnapshot(
        vehicles: [Vehicle],
        trips: [Trip],
        workOrders: [WorkOrder],
        defects: [DefectReport],
        documents: [VehicleDocument],
        spareParts: [SparePart],
        fuelReceipts: [FuelReceipt],
        fuelTransactions: [FuelTransaction]
    ) -> FleetReportSnapshot {
        let maintenance = generateMaintenanceSummary(
            vehicles: vehicles,
            workOrders: workOrders,
            defects: defects,
            schedules: [],
            assignedMaintenanceID: nil
        )
        let inventory = generateInventorySummary(
            spareParts: spareParts,
            vehicles: vehicles,
            workOrders: workOrders,
            defects: defects
        )
        let fuel = generateFuelSummary(
            vehicles: vehicles,
            trips: trips,
            fuelReceipts: fuelReceipts,
            fuelTransactions: fuelTransactions
        )
        let compliance = generateComplianceSummary(
            vehicles: vehicles,
            documents: documents
        )
        let routing = generateRoutingSummary(
            vehicles: vehicles,
            trips: trips
        )
        let summary = FleetReportSummary(
            totalVehicles: vehicles.count,
            activeVehicles: vehicles.filter { $0.status == .active || $0.status == .inService }.count,
            averageUtilization: average(vehicles.map { Double($0.utilization) }),
            averageOdometer: average(vehicles.map { Double($0.odometer) }),
            openWorkOrders: workOrders.filter { $0.status != .completed }.count,
            unresolvedDefects: defects.filter { !$0.isResolved }.count
        )

        return FleetReportSnapshot(
            generatedAt: .now,
            summary: summary,
            maintenance: maintenance,
            inventory: inventory,
            fuel: fuel,
            compliance: compliance,
            routing: routing,
            recommendations: recommendations(
                maintenance: maintenance,
                inventory: inventory,
                fuel: fuel,
                compliance: compliance,
                routing: routing
            )
        )
    }

    func generateMaintenanceSummary(
        vehicles: [Vehicle],
        workOrders: [WorkOrder],
        defects: [DefectReport],
        schedules: [MaintenanceSchedule],
        assignedMaintenanceID: UUID?
    ) -> MaintenanceReportSummary {
        let scopedOrders = assignedMaintenanceID.map { maintenanceID in
            workOrders.filter { $0.assignedMaintenanceID == maintenanceID }
        } ?? workOrders
        let activeOrders = scopedOrders.filter { $0.status != .completed }
        let completedOrders = scopedOrders.filter { $0.status == .completed }
        let upcomingScheduleCount = schedules.filter { $0.status == .upcoming }.count
        let rows = vehicles.map { vehicle in
            maintenanceRow(
                vehicle: vehicle,
                workOrders: scopedOrders,
                defects: defects
            )
        }
        .filter { assignedMaintenanceID == nil || $0.openWorkOrders > 0 || $0.unresolvedDefects > 0 }
        .sorted {
            if $0.severity.rank == $1.severity.rank {
                return $0.daysToService < $1.daysToService
            }
            return $0.severity.rank > $1.severity.rank
        }
        let totalCost = scopedOrders.reduce(0) { $0 + $1.estimatedCost }

        return MaintenanceReportSummary(
            totalWorkOrders: scopedOrders.count,
            openWorkOrders: activeOrders.count,
            completedWorkOrders: completedOrders.count,
            overdueWorkOrders: activeOrders.filter(\.isOverdue).count,
            criticalWorkOrders: activeOrders.filter { $0.priority == .critical }.count,
            totalEstimatedCost: totalCost,
            averageEstimatedCost: scopedOrders.isEmpty ? 0 : totalCost / Double(scopedOrders.count),
            upcomingServiceCount: upcomingScheduleCount,
            rows: rows
        )
    }

    func generateInventorySummary(
        spareParts: [SparePart],
        vehicles: [Vehicle],
        workOrders: [WorkOrder],
        defects: [DefectReport]
    ) -> InventoryReportSummary {
        let forecasts = spareParts.map { part in
            sparePartForecast(
                part: part,
                vehicleCount: vehicles.count,
                workOrders: workOrders,
                defects: defects
            )
        }
        .sorted {
            if $0.severity.rank == $1.severity.rank {
                return $0.daysOfCover < $1.daysOfCover
            }
            return $0.severity.rank > $1.severity.rank
        }

        return InventoryReportSummary(
            totalPartTypes: spareParts.count,
            totalQuantity: spareParts.reduce(0) { $0 + $1.quantity },
            lowStockCount: spareParts.filter { $0.isLowStock || $0.isOutOfStock }.count,
            outOfStockCount: spareParts.filter(\.isOutOfStock).count,
            forecastRows: forecasts
        )
    }

    func generateFuelSummary(
        vehicles: [Vehicle],
        trips: [Trip],
        fuelReceipts: [FuelReceipt],
        fuelTransactions: [FuelTransaction]
    ) -> FuelReportSummary {
        let verifiedTransactions = fuelTransactions.filter { $0.verificationStatus == .verified }
        let transactionSpend = fuelTransactions.reduce(0) { $0 + $1.manualAmount }
        let verifiedSpend = verifiedTransactions.reduce(0) { $0 + $1.manualAmount }
        let receiptSpend = fuelReceipts.reduce(0) { $0 + $1.amount }
        let currentSpend = fuelTransactions.isEmpty ? receiptSpend : transactionSpend
        let verifiedOrReceiptSpend = fuelTransactions.isEmpty ? receiptSpend : verifiedSpend
        let consumingVehicles = vehicles.filter { $0.fuelConsumption > 0 }
        let vehicleReports = consumingVehicles.compactMap { vehicle -> FuelVehicleReport? in
            let benchmark = benchmarkFuelConsumption(for: vehicle)
            guard benchmark > 0, vehicle.fuelConsumption > benchmark * 1.05 else { return nil }
            let monthlyDistance = estimatedMonthlyDistance(vehicle: vehicle, trips: trips)
            let potentialLitres = max(0, (vehicle.fuelConsumption - benchmark) * monthlyDistance / 100)
            return FuelVehicleReport(
                id: vehicle.id,
                vehicleName: vehicle.displayName,
                plateNumber: vehicle.plateNumber,
                consumption: vehicle.fuelConsumption,
                benchmark: benchmark,
                monthlyDistanceEstimate: monthlyDistance,
                potentialLitresSaved: potentialLitres,
                severity: vehicle.fuelConsumption > benchmark * 1.25 ? .critical : .action
            )
        }
        .sorted { $0.potentialLitresSaved > $1.potentialLitresSaved }
        let averageConsumption = average(consumingVehicles.map(\.fuelConsumption))
        let benchmark = average(consumingVehicles.map { benchmarkFuelConsumption(for: $0) }.filter { $0 > 0 })

        return FuelReportSummary(
            totalSpend: currentSpend,
            verifiedSpend: verifiedOrReceiptSpend,
            pendingTransactions: fuelTransactions.filter { $0.verificationStatus == .pending }.count,
            averageConsumption: averageConsumption,
            benchmarkConsumption: benchmark,
            potentialLitresSavedMonthly: vehicleReports.reduce(0) { $0 + $1.potentialLitresSaved },
            highConsumptionVehicles: vehicleReports
        )
    }

    func generateComplianceSummary(
        vehicles: [Vehicle],
        documents: [VehicleDocument]
    ) -> ComplianceReportSummary {
        let alerts = vehicles.flatMap { vehicle in
            complianceAlerts(vehicle: vehicle, documents: documents.filter { $0.vehicleID == vehicle.id })
        }
        .sorted {
            if $0.severity.rank == $1.severity.rank {
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            return $0.severity.rank > $1.severity.rank
        }

        return ComplianceReportSummary(
            totalDocuments: documents.count,
            expiredCount: alerts.filter { $0.status == "Expired" }.count,
            expiringSoonCount: alerts.filter { $0.status == "Expiring Soon" }.count,
            missingCount: alerts.filter { $0.status == "Missing" }.count,
            alerts: alerts
        )
    }

    func generateRoutingSummary(
        vehicles: [Vehicle],
        trips: [Trip]
    ) -> RoutingReportSummary {
        let activeTrips = trips.filter { $0.status == .scheduled || $0.status == .inProgress || $0.status == .completed }
        let grouped = Dictionary(grouping: activeTrips) { trip in
            "\(trip.origin.trimmedReportText) -> \(trip.destination.trimmedReportText)"
        }
        let routes = grouped.map { key, routeTrips in
            RouteOptimizationReport(
                routeName: key,
                tripCount: routeTrips.count,
                averageDistance: average(routeTrips.map(\.distanceKM).filter { $0 > 0 }),
                assignedVehicleCount: Set(routeTrips.map(\.vehicleID)).count,
                severity: routeTrips.count >= 3 ? .action : .watch
            )
        }
        .filter { $0.tripCount > 1 }
        .sorted {
            if $0.tripCount == $1.tripCount {
                return $0.averageDistance < $1.averageDistance
            }
            return $0.tripCount > $1.tripCount
        }
        let idleVehicles = vehicles.filter { $0.status == .idle || $0.assignedDriverID == nil }.count
        let overloadedVehicles = vehicles.filter { $0.utilization >= 85 }.count

        return RoutingReportSummary(
            averageTripDistance: average(trips.map(\.distanceKM).filter { $0 > 0 }),
            repeatedRoutes: routes,
            idleVehicles: idleVehicles,
            overloadedVehicles: overloadedVehicles,
            recommendation: routingRecommendation(routes: routes, idleVehicles: idleVehicles, overloadedVehicles: overloadedVehicles)
        )
    }

    private func maintenanceRow(
        vehicle: Vehicle,
        workOrders: [WorkOrder],
        defects: [DefectReport]
    ) -> MaintenanceReportRow {
        let vehicleOrders = workOrders.filter { $0.vehicleID == vehicle.id }
        let openOrders = vehicleOrders.filter { $0.status != .completed }
        let unresolved = defects.filter { $0.vehicleID == vehicle.id && !$0.isResolved }
        let daysToService = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: vehicle.nextServiceDate)).day ?? 0
        let hasCriticalOrder = openOrders.contains { $0.priority == .critical }
        let hasHighDefect = unresolved.contains { $0.severity == .high || $0.severity == .critical }
        let severity: FleetReportSeverity
        if daysToService < 0 || hasCriticalOrder || hasHighDefect {
            severity = .critical
        } else if daysToService <= 14 || !unresolved.isEmpty || openOrders.count >= 2 {
            severity = .action
        } else if daysToService <= 30 || !openOrders.isEmpty {
            severity = .watch
        } else {
            severity = .normal
        }

        return MaintenanceReportRow(
            vehicleID: vehicle.id,
            vehicleName: vehicle.displayName,
            plateNumber: vehicle.plateNumber,
            nextServiceDate: vehicle.nextServiceDate,
            daysToService: daysToService,
            openWorkOrders: openOrders.count,
            unresolvedDefects: unresolved.count,
            estimatedCost: vehicleOrders.reduce(0) { $0 + $1.estimatedCost },
            severity: severity,
            recommendation: maintenanceRecommendation(severity: severity, daysToService: daysToService, openOrders: openOrders.count, defects: unresolved.count)
        )
    }

    private func sparePartForecast(
        part: SparePart,
        vehicleCount: Int,
        workOrders: [WorkOrder],
        defects: [DefectReport]
    ) -> SparePartForecastReport {
        let demandText = "\(part.name) \(part.category) \(partKeyword(for: part))".lowercased()
        let orderSignals = workOrders.filter { order in
            let text = "\(order.title) \(order.details)".lowercased()
            return demandText.components(separatedBy: " ").contains(where: { !$0.isEmpty && text.contains($0) })
        }.count
        let defectSignals = defects.filter { defect in
            let text = "\(defect.title ?? "") \(defect.description)".lowercased()
            return demandText.components(separatedBy: " ").contains(where: { !$0.isEmpty && text.contains($0) })
        }.count
        let fleetScale = max(1, Double(vehicleCount) / 4)
        let baseline = max(1, Double(part.minimumRequired) * 0.4)
        let monthlyUsage = max(1, (Double(orderSignals) * 0.7 + Double(defectSignals) * 0.9 + baseline) * fleetScale)
        let daysOfCover = monthlyUsage > 0 ? Int((Double(part.quantity) / monthlyUsage * 30).rounded()) : 90
        let reorderQuantity = max(0, Int(ceil(monthlyUsage * 1.5)) + part.minimumRequired - part.quantity)
        let severity: FleetReportSeverity
        if part.isOutOfStock || daysOfCover <= 7 {
            severity = .critical
        } else if part.isLowStock || daysOfCover <= 21 || reorderQuantity > 0 {
            severity = .action
        } else if daysOfCover <= 45 {
            severity = .watch
        } else {
            severity = .normal
        }

        return SparePartForecastReport(
            id: part.id,
            name: part.name,
            partNumber: part.partNumber,
            category: part.category,
            onHand: part.quantity,
            minimumRequired: part.minimumRequired,
            forecastMonthlyUsage: monthlyUsage,
            daysOfCover: daysOfCover,
            reorderQuantity: reorderQuantity,
            severity: severity
        )
    }

    private func complianceAlerts(
        vehicle: Vehicle,
        documents: [VehicleDocument]
    ) -> [ComplianceAlertReport] {
        DocumentType.allCases.compactMap { documentType in
            guard let document = documents.first(where: { $0.type == documentType }) else {
                return ComplianceAlertReport(
                    vehicleID: vehicle.id,
                    vehicleName: vehicle.displayName,
                    plateNumber: vehicle.plateNumber,
                    documentType: documentType,
                    status: "Missing",
                    dueDate: nil,
                    severity: .action,
                    alertKey: "\(vehicle.id.uuidString)-\(documentType.rawValue)-missing"
                )
            }

            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: document.expiryDate)).day ?? 0
            if days < 0 {
                return ComplianceAlertReport(
                    vehicleID: vehicle.id,
                    vehicleName: vehicle.displayName,
                    plateNumber: vehicle.plateNumber,
                    documentType: documentType,
                    status: "Expired",
                    dueDate: document.expiryDate,
                    severity: .critical,
                    alertKey: "\(document.id.uuidString)-expired"
                )
            }
            if days <= 30 {
                return ComplianceAlertReport(
                    vehicleID: vehicle.id,
                    vehicleName: vehicle.displayName,
                    plateNumber: vehicle.plateNumber,
                    documentType: documentType,
                    status: "Expiring Soon",
                    dueDate: document.expiryDate,
                    severity: days <= 7 ? .critical : .action,
                    alertKey: "\(document.id.uuidString)-expiring-\(days)"
                )
            }
            return nil
        }
    }

    private func recommendations(
        maintenance: MaintenanceReportSummary,
        inventory: InventoryReportSummary,
        fuel: FuelReportSummary,
        compliance: ComplianceReportSummary,
        routing: RoutingReportSummary
    ) -> [FleetReportRecommendation] {
        var result: [FleetReportRecommendation] = []

        if maintenance.criticalWorkOrders > 0 || maintenance.overdueWorkOrders > 0 {
            result.append(FleetReportRecommendation(
                title: "Prioritize critical maintenance",
                detail: "\(maintenance.criticalWorkOrders) critical and \(maintenance.overdueWorkOrders) overdue work order\(maintenance.overdueWorkOrders == 1 ? "" : "s") need scheduling attention.",
                severity: .critical,
                iconName: "wrench.and.screwdriver.fill"
            ))
        }
        if inventory.lowStockCount > 0 {
            result.append(FleetReportRecommendation(
                title: "Reorder spare parts",
                detail: "\(inventory.lowStockCount) part type\(inventory.lowStockCount == 1 ? "" : "s") are below threshold or forecast to run short.",
                severity: inventory.outOfStockCount > 0 ? .critical : .action,
                iconName: "shippingbox.fill"
            ))
        }
        if fuel.potentialLitresSavedMonthly > 0 {
            result.append(FleetReportRecommendation(
                title: "Reduce fuel variance",
                detail: "Potential monthly saving is about \(Int(fuel.potentialLitresSavedMonthly.rounded())) litres by shifting high-consumption vehicles and tightening service checks.",
                severity: .action,
                iconName: "fuelpump.fill"
            ))
        }
        if compliance.expiredCount + compliance.expiringSoonCount + compliance.missingCount > 0 {
            result.append(FleetReportRecommendation(
                title: "Resolve compliance alerts",
                detail: "\(compliance.alerts.count) document issue\(compliance.alerts.count == 1 ? "" : "s") need review before dispatch risk increases.",
                severity: compliance.expiredCount > 0 ? .critical : .action,
                iconName: "doc.text.fill"
            ))
        }
        if routing.overloadedVehicles > 0 || routing.idleVehicles > 0 {
            result.append(FleetReportRecommendation(
                title: "Rebalance route capacity",
                detail: routing.recommendation,
                severity: routing.overloadedVehicles > 0 ? .action : .watch,
                iconName: "point.topleft.down.to.point.bottomright.curvepath"
            ))
        }

        if result.isEmpty {
            result.append(FleetReportRecommendation(
                title: "Fleet is operating within target",
                detail: "No critical report signals were detected in maintenance, fuel, inventory, routing, or compliance.",
                severity: .normal,
                iconName: "checkmark.seal.fill"
            ))
        }

        return result.sorted { $0.severity.rank > $1.severity.rank }
    }

    private func maintenanceRecommendation(severity: FleetReportSeverity, daysToService: Int, openOrders: Int, defects: Int) -> String {
        switch severity {
        case .critical:
            return "Hold or prioritize service before dispatch."
        case .action:
            return "Plan workshop slot within the next service window."
        case .watch:
            return "Monitor usage and keep parts ready."
        case .normal:
            return "Continue current schedule."
        }
    }

    private func routingRecommendation(routes: [RouteOptimizationReport], idleVehicles: Int, overloadedVehicles: Int) -> String {
        guard let route = routes.first else {
            return "Record more route history to rank route demand and vehicle allocation."
        }
        if overloadedVehicles > 0 && idleVehicles > 0 {
            return "Use \(idleVehicles) idle vehicle\(idleVehicles == 1 ? "" : "s") to support \(route.routeName) and reduce load on \(overloadedVehicles) high-utilization vehicle\(overloadedVehicles == 1 ? "" : "s")."
        }
        if overloadedVehicles > 0 {
            return "Reduce assignments on \(overloadedVehicles) vehicle\(overloadedVehicles == 1 ? "" : "s") above 85% utilization, starting with \(route.routeName)."
        }
        if idleVehicles > 0 {
            return "Keep \(idleVehicles) idle vehicle\(idleVehicles == 1 ? "" : "s") available as backup for repeated route \(route.routeName)."
        }
        return "Current route capacity is balanced. Keep monitoring \(route.routeName)."
    }

    private func estimatedMonthlyDistance(vehicle: Vehicle, trips: [Trip]) -> Double {
        let vehicleTrips = trips.filter { $0.vehicleID == vehicle.id && $0.distanceKM > 0 }
        if vehicleTrips.isEmpty {
            return max(300, Double(vehicle.utilization) * 30)
        }
        return max(300, average(vehicleTrips.map(\.distanceKM)) * max(8, Double(vehicleTrips.count)))
    }

    private func benchmarkFuelConsumption(for vehicle: Vehicle) -> Double {
        let text = "\(vehicle.vehicleType) \(vehicle.model)".lowercased()
        if vehicle.fuelType.lowercased().contains("electric") { return 0 }
        if text.contains("heavy") || text.contains("container") { return 24 }
        if text.contains("truck") { return 18 }
        if text.contains("van") { return 11 }
        return 14
    }

    private func partKeyword(for part: SparePart) -> String {
        let text = "\(part.name) \(part.category)".lowercased()
        if text.contains("brake") { return "brake" }
        if text.contains("tyre") || text.contains("tire") || text.contains("wheel") { return "tyre" }
        if text.contains("engine") || text.contains("oil") || text.contains("filter") { return "engine" }
        if text.contains("light") || text.contains("lamp") { return "light" }
        if text.contains("battery") || text.contains("electrical") { return "electrical" }
        return text.components(separatedBy: " ").first ?? text
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

private extension String {
    var trimmedReportText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
