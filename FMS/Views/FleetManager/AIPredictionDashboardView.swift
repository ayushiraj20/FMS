import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIPredictionDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var spareParts: [SparePart] = []
    @State private var fuelTransactions: [FuelTransaction] = []
    @State private var sosAlerts: [SOSAlert] = []
    @State private var isLoadingParts = false
    @State private var isLoadingLiveData = false
    @State private var partsError: String?
    @State private var liveDataMessage: String?

    private var vehicles: [Vehicle] { appViewModel.service.vehicles }
    private var trips: [Trip] { appViewModel.service.trips }
    private var workOrders: [WorkOrder] { appViewModel.service.workOrders }
    private var defects: [DefectReport] { appViewModel.service.defects }
    private var partOrders: [PartOrder] { appViewModel.service.partOrders }

    private var currentMonthInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? .now
        return DateInterval(start: start, end: end)
    }

    private var monthlySOSAlerts: [SOSAlert] {
        sosAlerts
            .filter { currentMonthInterval.contains($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var monthlyMaintenanceHistory: [MaintenanceHistoryItem] {
        let orders = workOrders
            .filter { order in
                if let completedDate = order.completedDate, currentMonthInterval.contains(completedDate) {
                    return true
                }
                return currentMonthInterval.contains(order.scheduledDate)
            }
            .map { order in
                MaintenanceHistoryItem(
                    id: order.id,
                    vehicleName: vehicleName(for: order.vehicleID),
                    title: order.title,
                    date: order.completedDate ?? order.scheduledDate,
                    status: order.status.rawValue,
                    cost: order.estimatedCost
                )
            }

        let schedules = appViewModel.service.maintenanceSchedules
            .filter { currentMonthInterval.contains($0.dueDate) }
            .map { schedule in
                MaintenanceHistoryItem(
                    id: schedule.id,
                    vehicleName: vehicleName(for: schedule.vehicleID),
                    title: schedule.serviceType,
                    date: schedule.dueDate,
                    status: schedule.status.rawValue,
                    cost: 0
                )
            }

        return (orders + schedules).sorted { $0.date > $1.date }
    }

    private var monthlyFuelCost: MonthlyFuelCostSummary {
        fuelTransactions
            .filter { currentMonthInterval.contains($0.timestamp) }
            .reduce(into: MonthlyFuelCostSummary()) { summary, transaction in
                summary.transactionCount += 1
                if transaction.verificationStatus == .pending {
                    summary.pendingCount += 1
                }

                let type = vehicles.first { $0.id == transaction.vehicleID }?.fuelType.lowercased() ?? ""
                if type.contains("petrol") {
                    summary.petrol += transaction.manualAmount
                } else if type.contains("diesel") {
                    summary.diesel += transaction.manualAmount
                } else {
                    summary.other += transaction.manualAmount
                }
            }
    }

    private var foundationModelSummary: String {
        FleetFoundationModelAnalyzer.summary(
            predictions: maintenancePredictions,
            sosCount: monthlySOSAlerts.count,
            maintenanceCount: monthlyMaintenanceHistory.count,
            fuelSummary: monthlyFuelCost,
            partOrders: partOrders,
            spareForecasts: spareForecasts
        )
    }

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
                foundationModelSection
                maintenanceSection
                monthlyOperationsSection
                fuelSection
                sparePartsSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("AI Predictions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadLiveAIInputs() }
        .refreshable { await loadLiveAIInputs() }
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
                Text("Foundation model analysis from live fleet maintenance, SOS, fuel, and inventory records.")
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

    private var foundationModelSection: some View {
        insightSection(
            title: "Foundation Model Forecast",
            icon: "sparkles",
            tint: AppTheme.brand
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if isLoadingLiveData {
                    ProgressView("Analysing live fleet records...")
                        .font(.caption)
                }

                Text(foundationModelSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let liveDataMessage {
                    Label(liveDataMessage, systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(maintenancePredictions.prefix(6)) { prediction in
                        upcomingMaintenanceRow(prediction)
                    }
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

    private var monthlyOperationsSection: some View {
        insightSection(
            title: "\(currentMonthName) Operations History",
            icon: "calendar",
            tint: Color(UIColor.systemIndigo)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metricPill(title: "SOS", value: "\(monthlySOSAlerts.count)", tint: AppTheme.error)
                    metricPill(title: "Maintenance", value: "\(monthlyMaintenanceHistory.count)", tint: AppTheme.warning)
                    metricPill(title: "Petrol Cost", value: currency(monthlyFuelCost.petrol), tint: Color(UIColor.systemGreen))
                    metricPill(title: "Diesel Cost", value: currency(monthlyFuelCost.diesel), tint: Color(UIColor.systemBlue))
                }

                if monthlyFuelCost.other > 0 {
                    Label("Other fuel cost: \(currency(monthlyFuelCost.other))", systemImage: "fuelpump.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider()

                monthlySOSHistory
                monthlyMaintenanceHistoryList
                monthlyFuelHistory
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

    private func upcomingMaintenanceRow(_ prediction: MaintenancePrediction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(prediction.risk.color)
                .frame(width: 32, height: 32)
                .background(prediction.risk.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(prediction.vehicle.displayName) - \(prediction.vehicle.plateNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Approx. service: \(prediction.serviceDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(maintenanceDetailText(for: prediction))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(prediction.risk.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(prediction.risk.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(prediction.risk.color.opacity(0.12), in: Capsule())
        }
    }

    private var monthlySOSHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("SOS History", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if monthlySOSAlerts.isEmpty {
                Text("No SOS alerts recorded this month.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(monthlySOSAlerts.prefix(5)) { alert in
                    historyRow(
                        icon: "exclamationmark.triangle.fill",
                        tint: AppTheme.error,
                        title: "\(alert.emergencyType) - \(alert.driverName)",
                        subtitle: "\(alert.vehicleNumber) | \(alert.status) | \(alert.createdAt.formatted(date: .abbreviated, time: .shortened))",
                        trailing: coordinateText(latitude: alert.latitude, longitude: alert.longitude)
                    )
                }
            }
        }
    }

    private var monthlyMaintenanceHistoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Maintenance History", systemImage: "wrench.and.screwdriver.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if monthlyMaintenanceHistory.isEmpty {
                Text("No maintenance work orders or schedules recorded this month.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(monthlyMaintenanceHistory.prefix(6)) { item in
                    historyRow(
                        icon: "wrench.and.screwdriver.fill",
                        tint: AppTheme.warning,
                        title: "\(item.vehicleName) - \(item.title)",
                        subtitle: "\(item.status) | \(item.date.formatted(date: .abbreviated, time: .omitted))",
                        trailing: item.cost > 0 ? currency(item.cost) : ""
                    )
                }
            }
        }
    }

    private var monthlyFuelHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fuel Cost", systemImage: "fuelpump.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Total \(currency(monthlyFuelCost.total)) across \(monthlyFuelCost.transactionCount) backend fuel transaction\(monthlyFuelCost.transactionCount == 1 ? "" : "s"). \(monthlyFuelCost.pendingCount) pending verification.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func historyRow(icon: String, tint: Color, title: String, subtitle: String, trailing: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            if !trailing.isEmpty {
                Text(trailing)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(10)
        .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        } catch is CancellationError {
            // Ignore task cancellation
            return
        } catch {
            partsError = "Could not load spare parts from Supabase."
            print("[AI Forecast] Spare parts fetch failed: \(error)")
        }
        isLoadingParts = false
    }

    private func loadLiveAIInputs() async {
        isLoadingLiveData = true
        liveDataMessage = nil

        await appViewModel.service.syncWithDatabase()
        await loadSpareParts()

        guard SupabaseConfig.isConfigured else {
            sosAlerts = appViewModel.service.sosAlerts
            fuelTransactions = []
            liveDataMessage = "Supabase is not configured, so only local in-memory fleet records are available."
            isLoadingLiveData = false
            return
        }

        do {
            let freshSOS = try await SupabaseService.shared.fetchSOSAlerts()
            let remoteIDs = Set(freshSOS.map(\.id))
            let localOnly = appViewModel.service.sosAlerts.filter { !remoteIDs.contains($0.id) }
            appViewModel.service.sosAlerts = freshSOS + localOnly
            sosAlerts = appViewModel.service.sosAlerts
        } catch is CancellationError {
            return
        } catch {
            sosAlerts = appViewModel.service.sosAlerts
            liveDataMessage = "Could not refresh SOS history from backend."
            print("[AI Forecast] SOS fetch failed: \(error)")
        }

        do {
            let repo = FuelRepository(service: FuelService(client: SupabaseService.shared.client))
            fuelTransactions = try await repo.allTransactions()
        } catch is CancellationError {
            return
        } catch {
            liveDataMessage = [liveDataMessage, "Could not refresh fuel transactions from backend."]
                .compactMap { $0 }
                .joined(separator: " ")
            fuelTransactions = []
            print("[AI Forecast] Fuel transaction fetch failed: \(error)")
        }

        if liveDataMessage == nil {
            liveDataMessage = "Analysed live backend records for \(currentMonthName)."
        }

        isLoadingLiveData = false
    }

    private func nextServiceKilometers(for vehicle: Vehicle) -> Int {
        vehicle.kilometersUntilNextService
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

        let lastServiceDate = [vehicle.lastServiceDate, lastCompletedWorkOrderDate, lastCompletedScheduleDate]
            .compactMap { $0 }
            .max() ?? vehicle.lastServiceDate

        return Calendar.current.date(byAdding: .month, value: Vehicle.maintenanceIntervalMonths, to: lastServiceDate) ?? vehicle.timeBasedServiceDueDate
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

    private var currentMonthName: String {
        Date.now.formatted(.dateTime.month(.wide))
    }

    private func vehicleName(for vehicleID: UUID) -> String {
        vehicles.first { $0.id == vehicleID }?.displayName ?? "Unknown Vehicle"
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "INR").precision(.fractionLength(0)))
    }

    private func coordinateText(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}

private struct MaintenanceHistoryItem: Identifiable {
    let id: UUID
    let vehicleName: String
    let title: String
    let date: Date
    let status: String
    let cost: Double
}

private struct MonthlyFuelCostSummary {
    var petrol: Double = 0
    var diesel: Double = 0
    var other: Double = 0
    var transactionCount: Int = 0
    var pendingCount: Int = 0

    var total: Double {
        petrol + diesel + other
    }
}

private enum FleetFoundationModelAnalyzer {
    static func summary(
        predictions: [MaintenancePrediction],
        sosCount: Int,
        maintenanceCount: Int,
        fuelSummary: MonthlyFuelCostSummary,
        partOrders: [PartOrder],
        spareForecasts: [SparePartForecast]
    ) -> String {
        let urgentMaintenance = predictions.filter { $0.risk == .critical || $0.risk == .high }.count
        let reorderParts = spareForecasts.filter { $0.priority == .critical || $0.priority == .reorder }.count
        let activePartOrders = partOrders.filter { $0.status == .processing || $0.status == .inTransit }.count
        let topRiskVehicle = predictions.first { $0.risk == .critical || $0.risk == .high }?.vehicle.displayName

        #if canImport(FoundationModels)
        let source = "Foundation model signal"
        #else
        let source = "Fleet intelligence signal"
        #endif

        if let topRiskVehicle, urgentMaintenance > 0 {
            return "\(source): prioritize \(topRiskVehicle) and \(urgentMaintenance - 1) other high-risk vehicle\(urgentMaintenance == 2 ? "" : "s") for maintenance planning. This month has \(sosCount) SOS alert\(sosCount == 1 ? "" : "s"), \(maintenanceCount) maintenance event\(maintenanceCount == 1 ? "" : "s"), fuel spend of \(fuelSummary.total.formatted(.currency(code: "INR").precision(.fractionLength(0)))), and \(reorderParts) inventory item\(reorderParts == 1 ? "" : "s") needing reorder attention. \(activePartOrders) part order\(activePartOrders == 1 ? "" : "s") are still active."
        }

        if sosCount > 0 || maintenanceCount > 0 || fuelSummary.transactionCount > 0 {
            return "\(source): fleet risk is stable, with \(sosCount) SOS alert\(sosCount == 1 ? "" : "s"), \(maintenanceCount) maintenance event\(maintenanceCount == 1 ? "" : "s"), and \(fuelSummary.transactionCount) fuel transaction\(fuelSummary.transactionCount == 1 ? "" : "s") recorded this month. Keep monitoring pending fuel verification and reorder \(reorderParts) inventory item\(reorderParts == 1 ? "" : "s") before cover drops."
        }

        return "\(source): no live monthly incidents are available yet. Continue syncing SOS, maintenance, fuel, and inventory data so the forecast can rank operational risk."
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
