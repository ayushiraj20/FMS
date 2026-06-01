import UIKit

struct FleetReportPDFGenerator {
    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 40
    private let lineSpacing: CGFloat = 6

    func generate(snapshot: FleetReportSnapshot, organizationName: String) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var y = margin
            var pageOpen = false

            func beginPageIfNeeded(requiredHeight: CGFloat) {
                if !pageOpen || y + requiredHeight > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                    pageOpen = true
                }
            }

            func drawLine(_ text: String, font: UIFont, color: UIColor = .label, indent: CGFloat = 0) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let maxWidth = pageRect.width - (margin * 2) - indent
                let attributed = NSAttributedString(string: text, attributes: attributes)
                let bounding = attributed.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                beginPageIfNeeded(requiredHeight: ceil(bounding.height) + lineSpacing)
                attributed.draw(
                    in: CGRect(
                        x: margin + indent,
                        y: y,
                        width: maxWidth,
                        height: ceil(bounding.height)
                    )
                )
                y += ceil(bounding.height) + lineSpacing
            }

            func drawSectionTitle(_ title: String) {
                y += 8
                drawLine(title, font: .boldSystemFont(ofSize: 16), color: .systemBlue)
                y += 2
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            drawLine("Fleet Operations Report", font: .boldSystemFont(ofSize: 24))
            drawLine(organizationName, font: .systemFont(ofSize: 14), color: .secondaryLabel)
            drawLine("Generated \(dateFormatter.string(from: snapshot.generatedAt))", font: .systemFont(ofSize: 12), color: .secondaryLabel)

            drawSectionTitle("Executive Summary")
            drawLine("Total vehicles: \(snapshot.summary.totalVehicles) | Active: \(snapshot.summary.activeVehicles)", font: .systemFont(ofSize: 12))
            drawLine("Average utilization: \(Int(snapshot.summary.averageUtilization.rounded()))% | Average odometer: \(Int(snapshot.summary.averageOdometer.rounded())) km", font: .systemFont(ofSize: 12))
            drawLine("Open work orders: \(snapshot.summary.openWorkOrders) | Unresolved defects: \(snapshot.summary.unresolvedDefects)", font: .systemFont(ofSize: 12))

            drawSectionTitle("Inventory Reorder Plan")
            let reorderRows = snapshot.inventory.forecastRows.filter { $0.reorderQuantity > 0 }
            if reorderRows.isEmpty {
                drawLine("No spare parts currently require reordering.", font: .systemFont(ofSize: 12), color: .secondaryLabel)
            } else {
                drawLine("Part | Part # | On Hand | Min | Order Qty | Order By | Priority", font: .boldSystemFont(ofSize: 11))
                for row in reorderRows {
                    let when = row.orderByDate.map { dateFormatter.string(from: $0) } ?? "Immediate"
                    drawLine(
                        "\(row.name) | \(row.partNumber) | \(row.onHand) | \(row.minimumRequired) | \(row.reorderQuantity) | \(when) | \(row.severity.rawValue)",
                        font: .systemFont(ofSize: 11),
                        indent: 8
                    )
                    drawLine(
                        "Forecast usage: \(String(format: "%.1f", row.forecastMonthlyUsage))/mo | Days of cover: \(row.daysOfCover) | Category: \(row.category)",
                        font: .systemFont(ofSize: 10),
                        color: .secondaryLabel,
                        indent: 12
                    )
                }
            }

            drawSectionTitle("Inventory Summary")
            drawLine("Part types: \(snapshot.inventory.totalPartTypes) | Total units on hand: \(snapshot.inventory.totalQuantity)", font: .systemFont(ofSize: 12))
            drawLine("Low stock: \(snapshot.inventory.lowStockCount) | Out of stock: \(snapshot.inventory.outOfStockCount)", font: .systemFont(ofSize: 12))

            drawSectionTitle("Maintenance")
            drawLine("Total orders: \(snapshot.maintenance.totalWorkOrders) | Open: \(snapshot.maintenance.openWorkOrders) | Overdue: \(snapshot.maintenance.overdueWorkOrders)", font: .systemFont(ofSize: 12))
            drawLine("Critical: \(snapshot.maintenance.criticalWorkOrders) | Estimated cost: \(currency(snapshot.maintenance.totalEstimatedCost))", font: .systemFont(ofSize: 12))
            for row in snapshot.maintenance.rows.prefix(20) {
                drawLine(
                    "\(row.vehicleName) (\(row.plateNumber)) | \(row.openWorkOrders) open | \(row.unresolvedDefects) defects | \(serviceDueText(row.daysToService)) | \(row.severity.rawValue)",
                    font: .systemFont(ofSize: 11),
                    indent: 8
                )
            }

            drawSectionTitle("Fuel")
            drawLine("Total spend: \(currency(snapshot.fuel.totalSpend)) | Verified: \(currency(snapshot.fuel.verifiedSpend))", font: .systemFont(ofSize: 12))
            drawLine("Pending transactions: \(snapshot.fuel.pendingTransactions) | Potential monthly saving: \(Int(snapshot.fuel.potentialLitresSavedMonthly.rounded())) L", font: .systemFont(ofSize: 12))
            for row in snapshot.fuel.highConsumptionVehicles.prefix(15) {
                drawLine(
                    "\(row.vehicleName) (\(row.plateNumber)) | \(fuelText(row.consumption)) vs \(fuelText(row.benchmark)) | Save \(Int(row.potentialLitresSaved.rounded())) L/mo",
                    font: .systemFont(ofSize: 11),
                    indent: 8
                )
            }

            drawSectionTitle("Compliance")
            drawLine("Documents: \(snapshot.compliance.totalDocuments) | Expired: \(snapshot.compliance.expiredCount) | Expiring soon: \(snapshot.compliance.expiringSoonCount) | Missing: \(snapshot.compliance.missingCount)", font: .systemFont(ofSize: 12))
            for alert in snapshot.compliance.alerts.prefix(20) {
                let due = alert.dueDate.map { dateFormatter.string(from: $0) } ?? "N/A"
                drawLine(
                    "\(alert.documentType.rawValue) - \(alert.plateNumber) | \(alert.status) | Due \(due) | \(alert.severity.rawValue)",
                    font: .systemFont(ofSize: 11),
                    indent: 8
                )
            }

            drawSectionTitle("Routing")
            drawLine("Average trip distance: \(Int(snapshot.routing.averageTripDistance.rounded())) km | Idle vehicles: \(snapshot.routing.idleVehicles) | Overloaded: \(snapshot.routing.overloadedVehicles)", font: .systemFont(ofSize: 12))
            drawLine(snapshot.routing.recommendation, font: .systemFont(ofSize: 11), color: .secondaryLabel)
            for route in snapshot.routing.repeatedRoutes.prefix(12) {
                drawLine(
                    "\(route.routeName) | \(route.tripCount) trips | \(Int(route.averageDistance.rounded())) km avg",
                    font: .systemFont(ofSize: 11),
                    indent: 8
                )
            }

            drawSectionTitle("Recommendations")
            for recommendation in snapshot.recommendations {
                drawLine("\(recommendation.title) [\(recommendation.severity.rawValue)]", font: .boldSystemFont(ofSize: 12), indent: 8)
                drawLine(recommendation.detail, font: .systemFont(ofSize: 11), color: .secondaryLabel, indent: 12)
            }
        }

        let fileName = "Fleet-Report-\(Int(snapshot.generatedAt.timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "INR").precision(.fractionLength(0)))
    }

    private func fuelText(_ value: Double) -> String {
        value > 0 ? "\(String(format: "%.1f", value)) L/100km" : "N/A"
    }

    private func serviceDueText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days)) days overdue" }
        if days == 0 { return "Due today" }
        return "\(days) days to service"
    }
}
