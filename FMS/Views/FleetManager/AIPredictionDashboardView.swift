import SwiftUI

struct AIPredictionDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var spareParts: [SparePart] = []
    @State private var isLoadingParts = false
    @State private var partsError: String?

    private var vehicles: [Vehicle] { appViewModel.service.vehicles }
    private var trips: [Trip] { appViewModel.service.trips }
    private var workOrders: [WorkOrder] { appViewModel.service.workOrders }
    private var defects: [DefectReport] { appViewModel.service.defects }

    private var fleetMetrics: FleetAIMetrics {
        FleetAIMetrics(
            vehicleCount: vehicles.count,
            averageUtilization: average(vehicles.map { Double($0.utilization) }),
            averageOdometer: average(vehicles.map { Double($0.odometer) }),
            averageFuelLevel: average(vehicles.map { Double($0.fuelLevel) }),
            averageFuelConsumption: average(vehicles.map(\.fuelConsumption).filter { $0 > 0 }),
            activeRatio: ratio(
                vehicles.filter { $0.status == .active || $0.status == .inService }.count,
                vehicles.count
            )
        )
    }

    private var maintenancePredictions: [MaintenancePrediction] {
        vehicles.map { vehicle in
            let kmToInterval = nextServiceKilometers(for: vehicle)
            let dailyKm = estimatedDailyKilometers(for: vehicle)
            let daysByOdometer = dailyKm > 0 ? max(0, Int(ceil(Double(kmToInterval) / dailyKm))) : Int.max
            let dueDate = nextServiceDate(for: vehicle)
            let daysBySchedule = max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? Int.max)
            let openOrders = workOrders.filter { $0.vehicleID == vehicle.id && $0.status != .completed }
            let recentDefects = defects.filter { $0.vehicleID == vehicle.id && !$0.isResolved }
            let daysToService = min(daysByOdometer, daysBySchedule)
            let basis = kmToInterval <= 0 || daysByOdometer <= daysBySchedule
                ? "10,000 km interval"
                : "6-month interval"

            return MaintenancePrediction(
                vehicle: vehicle,
                kmToService: kmToInterval,
                estimatedDailyKm: dailyKm,
                daysToService: daysToService,
                serviceDueDate: dueDate,
                recommendationBasis: basis,
                openWorkOrders: openOrders.count,
                unresolvedDefects: recentDefects.count,
                risk: maintenanceRisk(daysToService: daysToService, kmToService: kmToInterval, openOrders: openOrders, defects: recentDefects)
            )
        }
        .sorted {
            if $0.risk.rank == $1.risk.rank { return $0.daysToService < $1.daysToService }
            return $0.risk.rank > $1.risk.rank
        }
    }

    private var fuelInsight: FuelOptimizationInsight {
        let consumingVehicles = vehicles.filter { $0.fuelConsumption > 0 }
        let weightedCurrent = average(consumingVehicles.map(\.fuelConsumption))
        let benchmark = average(consumingVehicles.map { benchmarkFuelConsumption(for: $0) })
        let monthlyKm = vehicles.reduce(0.0) { $0 + estimatedDailyKilometers(for: $1) * 30 }
        let excessRate = max(0, weightedCurrent - benchmark)
        let potentialLitres = monthlyKm * excessRate / 100
        let potentialPercent = weightedCurrent > 0 ? min(22, (excessRate / weightedCurrent) * 100) : 0
        let lowFuelCount = vehicles.filter { $0.fuelLevel < 25 }.count
        let highConsumptionVehicles = consumingVehicles
            .filter { $0.fuelConsumption > benchmarkFuelConsumption(for: $0) * 1.12 }
            .sorted { $0.fuelConsumption > $1.fuelConsumption }

        return FuelOptimizationInsight(
            averageConsumption: weightedCurrent,
            benchmarkConsumption: benchmark,
            estimatedMonthlyKm: monthlyKm,
            potentialLitresSaved: potentialLitres,
            potentialPercentSaved: potentialPercent,
            lowFuelVehicles: lowFuelCount,
            highConsumptionVehicles: Array(highConsumptionVehicles.prefix(3))
        )
    }

    private var routeInsight: RoutingInsight {
        let activeOrScheduledTrips = trips.filter { $0.status == .scheduled || $0.status == .inProgress }
        let routeGroups = Dictionary(grouping: activeOrScheduledTrips) { trip in
            "\(trip.origin.trimmingCharacters(in: .whitespacesAndNewlines)) -> \(trip.destination.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        let bestRoute = routeGroups
            .map { key, routeTrips in
                RouteCandidate(
                    routeName: key,
                    tripCount: routeTrips.count,
                    averageDistance: average(routeTrips.map(\.distanceKM).filter { $0 > 0 }),
                    scheduledDrivers: Set(routeTrips.map(\.driverID)).count
                )
            }
            .sorted {
                if $0.tripCount == $1.tripCount { return $0.averageDistance < $1.averageDistance }
                return $0.tripCount > $1.tripCount
            }
            .first

        let idleVehicles = vehicles.filter { $0.status == .idle || $0.assignedDriverID == nil }
        let overloadedVehicles = vehicles.filter { $0.utilization > 85 }
        let averageTripDistance = average(trips.map(\.distanceKM).filter { $0 > 0 })

        return RoutingInsight(
            bestRoute: bestRoute,
            averageTripDistance: averageTripDistance,
            idleVehicles: idleVehicles.count,
            overloadedVehicles: overloadedVehicles.count,
            recommendation: routingRecommendation(bestRoute: bestRoute, idleVehicles: idleVehicles, overloadedVehicles: overloadedVehicles)
        )
    }

    private var spareForecasts: [SparePartForecast] {
        spareParts.map { part in
            let monthlyUsage = forecastMonthlyUsage(for: part)
            let daysOfCover = monthlyUsage > 0 ? Int((Double(part.quantity) / monthlyUsage * 30).rounded()) : 90
            let reorderQuantity = max(0, Int(ceil(monthlyUsage * 1.5)) + part.minimumRequired - part.quantity)

            return SparePartForecast(
                part: part,
                forecastMonthlyUsage: monthlyUsage,
                daysOfCover: daysOfCover,
                reorderQuantity: reorderQuantity,
                priority: sparePartPriority(part: part, daysOfCover: daysOfCover, reorderQuantity: reorderQuantity)
            )
        }
        .sorted {
            if $0.priority.rank == $1.priority.rank { return $0.daysOfCover < $1.daysOfCover }
            return $0.priority.rank > $1.priority.rank
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                fleetOverview
                maintenanceSection
                fuelSection
                routingSection
                sparePartsSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("AI Predictions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSpareParts() }
        .refreshable { await loadSpareParts() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppTheme.brand, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Fleet Intelligence")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Predictive maintenance, fuel, routing, and inventory suggestions based on live fleet data.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fleetOverview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Fleet Average")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricTile(title: "Vehicles", value: "\(fleetMetrics.vehicleCount)", icon: "truck.box.fill", tint: Color(UIColor.systemBlue))
                    metricTile(title: "Avg Utilization", value: "\(Int(fleetMetrics.averageUtilization.rounded()))%", icon: "gauge.with.dots.needle.67percent", tint: AppTheme.success)
                    metricTile(title: "Avg Odometer", value: "\(Int(fleetMetrics.averageOdometer / 1_000))k km", icon: "speedometer", tint: Color(UIColor.systemPurple))
                    metricTile(title: "Avg Fuel Use", value: fuelConsumptionText(fleetMetrics.averageFuelConsumption), icon: "fuelpump.fill", tint: AppTheme.warning)
                }
            }
        }
    }

    private var maintenanceSection: some View {
        let urgent = maintenancePredictions.filter { $0.risk == .critical || $0.risk == .high }
        let averageKmToService = average(maintenancePredictions.map { Double($0.kmToService) })

        return insightSection(
            title: "Predictive Maintenance",
            icon: "wrench.and.screwdriver.fill",
            tint: Color(UIColor.systemBlue)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(maintenanceSummary(urgentCount: urgent.count, averageKmToService: averageKmToService))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(spacing: 10) {
                    ForEach(maintenancePredictions.prefix(4)) { prediction in
                        maintenanceRow(prediction)
                    }
                }
            }
        }
    }

    private var fuelSection: some View {
        insightSection(
            title: "Fuel Optimization",
            icon: "fuelpump.fill",
            tint: AppTheme.warning
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    metricPill(title: "Current", value: fuelConsumptionText(fuelInsight.averageConsumption), tint: AppTheme.warning)
                    metricPill(title: "Target", value: fuelConsumptionText(fuelInsight.benchmarkConsumption), tint: AppTheme.success)
                }

                Text(fuelRecommendation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                if !fuelInsight.highConsumptionVehicles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Vehicles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        ForEach(fuelInsight.highConsumptionVehicles) { vehicle in
                            Label("\(vehicle.displayName) is above benchmark at \(fuelConsumptionText(vehicle.fuelConsumption))", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private var routingSection: some View {
        insightSection(
            title: "Intelligent Routing",
            icon: "point.topleft.down.to.point.bottomright.curvepath",
            tint: Color(UIColor.systemTeal)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let bestRoute = routeInsight.bestRoute {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title3)
                            .foregroundStyle(Color(UIColor.systemTeal))
                            .frame(width: 34, height: 34)
                            .background(Color(UIColor.systemTeal).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bestRoute.routeName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(bestRoute.tripCount) upcoming trip\(bestRoute.tripCount == 1 ? "" : "s") · \(Int(bestRoute.averageDistance.rounded())) km avg")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                Text(routeInsight.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    metricPill(title: "Avg Trip", value: "\(Int(routeInsight.averageTripDistance.rounded())) km", tint: Color(UIColor.systemTeal))
                    metricPill(title: "Idle Capacity", value: "\(routeInsight.idleVehicles)", tint: Color(UIColor.systemBlue))
                }
            }
        }
    }

    private var sparePartsSection: some View {
        insightSection(
            title: "Spare Part Forecasting",
            icon: "shippingbox.fill",
            tint: Color(UIColor.systemPurple)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if isLoadingParts {
                    ProgressView("Loading inventory...")
                        .font(.caption)
                } else if let partsError {
                    Text(partsError)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.error)
                } else if spareForecasts.isEmpty {
                    Text("No spare parts inventory is available for forecasting yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text(spareForecastSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    VStack(spacing: 10) {
                        ForEach(spareForecasts.prefix(5)) { forecast in
                            sparePartRow(forecast)
                        }
                    }
                }
            }
        }
    }

    private func insightSection<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func maintenanceRow(_ prediction: MaintenancePrediction) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(prediction.risk.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(prediction.vehicle.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(maintenanceDetailText(for: prediction))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(prediction.risk.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(prediction.risk.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(prediction.risk.color.opacity(0.12), in: Capsule())
        }
    }

    private func sparePartRow(_ forecast: SparePartForecast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: forecast.part.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(forecast.priority.color)
                .frame(width: 32, height: 32)
                .background(forecast.priority.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(forecast.part.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(forecast.part.quantity) on hand · \(forecast.daysOfCover) days cover")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(forecast.reorderQuantity > 0 ? "Order \(forecast.reorderQuantity)" : "OK")
                .font(.caption2.weight(.bold))
                .foregroundStyle(forecast.priority.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(forecast.priority.color.opacity(0.12), in: Capsule())
        }
    }

    private func loadSpareParts() async {
        guard let orgID = appViewModel.currentOrganization?.id else { return }
        guard SupabaseConfig.isConfigured else {
            spareParts = []
            return
        }

        isLoadingParts = true
        partsError = nil
        do {
            spareParts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
        } catch {
            partsError = "Could not load spare parts from Supabase."
            print("[AI Forecast] Spare parts fetch failed: \(error)")
        }
        isLoadingParts = false
    }

    private func nextServiceKilometers(for vehicle: Vehicle) -> Int {
        let serviceInterval = serviceIntervalKilometers(for: vehicle)
        let travelledInInterval = vehicle.odometer % serviceInterval
        return serviceInterval - travelledInInterval
    }

    private func serviceIntervalKilometers(for _: Vehicle) -> Int {
        10_000
    }

    private func nextServiceDate(for vehicle: Vehicle) -> Date {
        let lastCompletedWorkOrderDate = workOrders
            .filter { $0.vehicleID == vehicle.id && $0.status == .completed }
            .compactMap(\.completedDate)
            .max()

        let lastCompletedScheduleDate = appViewModel.service.maintenanceSchedules
            .filter { $0.vehicleID == vehicle.id && $0.status == .completed }
            .map(\.dueDate)
            .max()

        let lastServiceDate = [lastCompletedWorkOrderDate, lastCompletedScheduleDate]
            .compactMap { $0 }
            .max() ?? Calendar.current.date(byAdding: .month, value: -6, to: vehicle.nextServiceDate) ?? vehicle.nextServiceDate

        let sixMonthDueDate = Calendar.current.date(byAdding: .month, value: 6, to: lastServiceDate) ?? vehicle.nextServiceDate
        return min(vehicle.nextServiceDate, sixMonthDueDate)
    }

    private func estimatedDailyKilometers(for vehicle: Vehicle) -> Double {
        let vehicleTrips = trips.filter {
            $0.vehicleID == vehicle.id &&
            $0.status == .completed &&
            $0.distanceKM > 0
        }

        if !vehicleTrips.isEmpty {
            let sorted = vehicleTrips.sorted { $0.startDate < $1.startDate }
            let firstDate = sorted.first?.startDate ?? Date()
            let lastDate = sorted.last?.endDate ?? sorted.last?.startDate ?? firstDate
            let activeDays = max(1, Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
            return vehicleTrips.reduce(0) { $0 + $1.distanceKM } / Double(activeDays)
        }

        let completedTrips = trips.filter { $0.status == .completed && $0.distanceKM > 0 }
        return completedTrips.isEmpty ? 0 : average(completedTrips.map(\.distanceKM))
    }

    private func maintenanceDetailText(for prediction: MaintenancePrediction) -> String {
        let dateText = prediction.serviceDueDate.formatted(date: .abbreviated, time: .omitted)
        let dayText = prediction.daysToService == Int.max
            ? "date-based"
            : "\(prediction.daysToService) day\(prediction.daysToService == 1 ? "" : "s")"

        return "\(prediction.kmToService) km or \(dayText) to service (\(prediction.recommendationBasis), due \(dateText))"
    }

    private func maintenanceRisk(
        daysToService: Int,
        kmToService: Int,
        openOrders: [WorkOrder],
        defects: [DefectReport]
    ) -> PredictionRisk {
        if daysToService <= 0 || kmToService <= 250 || openOrders.contains(where: { $0.priority == .critical }) {
            return .critical
        }
        if daysToService <= 14 || kmToService <= 1_500 || !defects.isEmpty {
            return .high
        }
        if daysToService <= 30 || kmToService <= 3_000 || !openOrders.isEmpty {
            return .medium
        }
        return .normal
    }

    private func benchmarkFuelConsumption(for vehicle: Vehicle) -> Double {
        let type = "\(vehicle.vehicleType) \(vehicle.model)".lowercased()
        if vehicle.fuelType.lowercased().contains("electric") { return 0 }
        if type.contains("heavy") || type.contains("truck") || type.contains("container") { return 24 }
        if type.contains("van") { return 11 }
        return 14
    }

    private func forecastMonthlyUsage(for part: SparePart) -> Double {
        let category = part.category.lowercased()
        let name = part.name.lowercased()
        let issueSignals = defects.filter { defect in
            let text = "\(defect.title ?? "") \(defect.description)".lowercased()
            return text.contains(category) || text.contains(name) || text.contains(partKeyword(for: part))
        }.count
        let workOrderSignals = workOrders.filter { order in
            let text = "\(order.title) \(order.details)".lowercased()
            return text.contains(category) || text.contains(name) || text.contains(partKeyword(for: part))
        }.count
        let fleetScale = max(1.0, Double(vehicles.count) / 4.0)
        let baseline = max(1.0, Double(part.minimumRequired) * 0.45)

        return max(1.0, (Double(issueSignals) * 0.8 + Double(workOrderSignals) * 0.6 + baseline) * fleetScale)
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

    private func sparePartPriority(part: SparePart, daysOfCover: Int, reorderQuantity: Int) -> ForecastPriority {
        if part.isOutOfStock || daysOfCover <= 7 { return .critical }
        if part.isLowStock || daysOfCover <= 21 || reorderQuantity > 0 { return .reorder }
        return .healthy
    }

    private func routingRecommendation(
        bestRoute: RouteCandidate?,
        idleVehicles: [Vehicle],
        overloadedVehicles: [Vehicle]
    ) -> String {
        if let bestRoute {
            let capacityText = idleVehicles.isEmpty
                ? "Keep current vehicle allocation stable"
                : "use \(idleVehicles.count) idle/unassigned vehicle\(idleVehicles.count == 1 ? "" : "s") as backup capacity"
            let loadText = overloadedVehicles.isEmpty
                ? "no vehicles are currently above the utilization threshold"
                : "rebalance trips away from \(overloadedVehicles.count) vehicle\(overloadedVehicles.count == 1 ? "" : "s") above 85% utilization"

            return "For future dispatches, prioritize \(bestRoute.routeName). It has the strongest upcoming demand signal; \(capacityText), and \(loadText)."
        }

        return "No scheduled route history is available yet. Start by recording origin, destination, and distance for trips; the model will rank routes once there is enough dispatch data."
    }

    private func maintenanceSummary(urgentCount: Int, averageKmToService: Double) -> String {
        if vehicles.isEmpty {
            return "No vehicles are available for prediction yet."
        }

        if urgentCount > 0 {
            return "\(urgentCount) vehicle\(urgentCount == 1 ? "" : "s") should be planned for service soon. Fleet average remaining service distance is \(Int(averageKmToService.rounded())) km."
        }

        return "No critical maintenance risk detected. Fleet average remaining service distance is \(Int(averageKmToService.rounded())) km."
    }

    private var fuelRecommendation: String {
        if vehicles.isEmpty {
            return "No vehicles are available for fuel optimization."
        }

        if fuelInsight.potentialLitresSaved > 0 {
            return "Potential monthly saving is about \(Int(fuelInsight.potentialLitresSaved.rounded())) litres (\(Int(fuelInsight.potentialPercentSaved.rounded()))%). Reduce idling, assign high-consumption vehicles to shorter routes, and keep tyre pressure/service checks aligned with dispatch."
        }

        return "Fleet fuel consumption is near benchmark. Keep current routing, tyre-pressure checks, and service cadence stable."
    }

    private var spareForecastSummary: String {
        let reorderCount = spareForecasts.filter { $0.priority == .critical || $0.priority == .reorder }.count
        if reorderCount == 0 {
            return "Inventory coverage looks healthy against the current defect and work-order trend."
        }
        return "\(reorderCount) spare part\(reorderCount == 1 ? "" : "s") should be reordered based on stock cover and current repair signals."
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private func fuelConsumptionText(_ value: Double) -> String {
        guard value > 0 else { return "N/A" }
        return String(format: "%.1f L/100km", value)
    }
}

private struct FleetAIMetrics {
    let vehicleCount: Int
    let averageUtilization: Double
    let averageOdometer: Double
    let averageFuelLevel: Double
    let averageFuelConsumption: Double
    let activeRatio: Double
}

private struct MaintenancePrediction: Identifiable {
    let vehicle: Vehicle
    let kmToService: Int
    let estimatedDailyKm: Double
    let daysToService: Int
    let serviceDueDate: Date
    let recommendationBasis: String
    let openWorkOrders: Int
    let unresolvedDefects: Int
    let risk: PredictionRisk

    var id: UUID { vehicle.id }
}

private enum PredictionRisk {
    case normal
    case medium
    case high
    case critical

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .medium: return "Watch"
        case .high: return "Plan"
        case .critical: return "Urgent"
        }
    }

    var color: Color {
        switch self {
        case .normal: return AppTheme.success
        case .medium: return Color(UIColor.systemBlue)
        case .high: return AppTheme.warning
        case .critical: return AppTheme.error
        }
    }

    var rank: Int {
        switch self {
        case .normal: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

private struct FuelOptimizationInsight {
    let averageConsumption: Double
    let benchmarkConsumption: Double
    let estimatedMonthlyKm: Double
    let potentialLitresSaved: Double
    let potentialPercentSaved: Double
    let lowFuelVehicles: Int
    let highConsumptionVehicles: [Vehicle]
}

private struct RoutingInsight {
    let bestRoute: RouteCandidate?
    let averageTripDistance: Double
    let idleVehicles: Int
    let overloadedVehicles: Int
    let recommendation: String
}

private struct RouteCandidate {
    let routeName: String
    let tripCount: Int
    let averageDistance: Double
    let scheduledDrivers: Int
}

private struct SparePartForecast: Identifiable {
    let part: SparePart
    let forecastMonthlyUsage: Double
    let daysOfCover: Int
    let reorderQuantity: Int
    let priority: ForecastPriority

    var id: UUID { part.id }
}

private enum ForecastPriority {
    case healthy
    case reorder
    case critical

    var color: Color {
        switch self {
        case .healthy: return AppTheme.success
        case .reorder: return AppTheme.warning
        case .critical: return AppTheme.error
        }
    }

    var rank: Int {
        switch self {
        case .healthy: return 0
        case .reorder: return 1
        case .critical: return 2
        }
    }
}

#Preview {
    NavigationStack {
        AIPredictionDashboardView()
            .environment(AppViewModel())
    }
}
