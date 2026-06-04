import UIKit

@MainActor
struct FleetReportPDFGenerator {
    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 44
    private let contentWidth: CGFloat = 524
    private let brand = UIColor(red: 0.09, green: 0.38, blue: 0.92, alpha: 1)
    private let brandLight = UIColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1)
    private let cardBorder = UIColor.separator.withAlphaComponent(0.35)

    func generate(snapshot: FleetReportSnapshot, organizationName: String) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var layout = PDFLayout(
                context: context,
                pageRect: pageRect,
                margin: margin,
                contentWidth: contentWidth,
                brand: brand,
                brandLight: brandLight,
                cardBorder: cardBorder
            )

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            layout.beginCover(
                title: AppBranding.reportProductName,
                organization: organizationName,
                generated: dateFormatter.string(from: snapshot.generatedAt)
            )

            layout.drawSectionHeader("Executive Summary", subtitle: "Fleet health at a glance")
            layout.drawKPIGrid([
                ("Vehicles", "\(snapshot.summary.totalVehicles)", "Active \(snapshot.summary.activeVehicles)"),
                ("Utilization", "\(Int(snapshot.summary.averageUtilization.rounded()))%", "Fleet average"),
                ("Odometer", "\(Int(snapshot.summary.averageOdometer.rounded())) km", "Per vehicle avg"),
                ("Open issues", "\(snapshot.summary.openWorkOrders)", "\(snapshot.summary.unresolvedDefects) defects")
            ])
            layout.drawNarrative(
                "This \(AppBranding.name) report is generated from your live fleet database. Use the charts below to review utilization, maintenance backlog, compliance exposure, and fuel spend."
            )
            if let chart = FleetReportChartRenderer.fleetOverviewChart(
                active: snapshot.summary.activeVehicles,
                total: max(snapshot.summary.totalVehicles, 1),
                utilizationPercent: Int(snapshot.summary.averageUtilization.rounded())
            ) {
                layout.drawChartImage(chart, height: 168)
            }

            layout.drawSectionHeader("Inventory Reorder Plan", subtitle: "Parts that need ordering")
            let reorderRows = snapshot.inventory.forecastRows.filter { $0.reorderQuantity > 0 }
            if reorderRows.isEmpty {
                layout.drawInfoBanner("All spare parts are above minimum stock levels.")
            } else {
                layout.drawTable(
                    headers: ["Part", "On hand", "Order", "Priority"],
                    rows: Array(reorderRows.prefix(12).map { row in
                        [
                            "\(row.name)\n\(row.partNumber)",
                            "\(row.onHand) / \(row.minimumRequired)",
                            "\(row.reorderQuantity)",
                            row.severity.rawValue
                        ]
                    }),
                    severityColumn: 3
                )
            }

            layout.drawSectionHeader("Inventory Summary")
            layout.drawStatRow([
                ("Part types", "\(snapshot.inventory.totalPartTypes)"),
                ("Units on hand", "\(snapshot.inventory.totalQuantity)"),
                ("Low stock", "\(snapshot.inventory.lowStockCount)"),
                ("Out of stock", "\(snapshot.inventory.outOfStockCount)")
            ])

            layout.drawSectionHeader("Maintenance", subtitle: "Work orders & vehicle service")
            layout.drawKPIGrid([
                ("Total orders", "\(snapshot.maintenance.totalWorkOrders)", nil),
                ("Open", "\(snapshot.maintenance.openWorkOrders)", nil),
                ("Overdue", "\(snapshot.maintenance.overdueWorkOrders)", nil),
                ("Est. cost", currency(snapshot.maintenance.totalEstimatedCost), nil)
            ])
            if let chart = FleetReportChartRenderer.maintenanceChart(
                open: snapshot.maintenance.openWorkOrders,
                overdue: snapshot.maintenance.overdueWorkOrders,
                completed: snapshot.maintenance.completedWorkOrders,
                critical: snapshot.maintenance.criticalWorkOrders
            ) {
                layout.drawChartImage(chart, height: 168)
            }
            if !snapshot.maintenance.rows.isEmpty {
                layout.drawTable(
                    headers: ["Vehicle", "Open WO", "Defects", "Service", "Status"],
                    rows: Array(snapshot.maintenance.rows.prefix(15).map { row in
                        [
                            "\(row.vehicleName)\n\(row.plateNumber)",
                            "\(row.openWorkOrders)",
                            "\(row.unresolvedDefects)",
                            serviceDueText(row.daysToService),
                            row.severity.rawValue
                        ]
                    }),
                    severityColumn: 4
                )
            }

            layout.drawSectionHeader("Fuel", subtitle: "Spend & efficiency")
            layout.drawStatRow([
                ("Total spend", currency(snapshot.fuel.totalSpend)),
                ("Verified", currency(snapshot.fuel.verifiedSpend)),
                ("Pending txns", "\(snapshot.fuel.pendingTransactions)"),
                ("Potential saving", "\(Int(snapshot.fuel.potentialLitresSavedMonthly.rounded())) L/mo")
            ])
            if let chart = FleetReportChartRenderer.fuelChart(
                verifiedSpend: snapshot.fuel.verifiedSpend,
                totalSpend: snapshot.fuel.totalSpend,
                pendingCount: snapshot.fuel.pendingTransactions
            ) {
                layout.drawChartImage(chart, height: 168)
            }
            if !snapshot.fuel.highConsumptionVehicles.isEmpty {
                layout.drawTable(
                    headers: ["Vehicle", "Consumption", "Benchmark", "Save/mo"],
                    rows: Array(snapshot.fuel.highConsumptionVehicles.prefix(12).map { row in
                        [
                            "\(row.vehicleName)\n\(row.plateNumber)",
                            fuelText(row.consumption),
                            fuelText(row.benchmark),
                            "\(Int(row.potentialLitresSaved.rounded())) L"
                        ]
                    })
                )
            }

            layout.drawSectionHeader("Compliance", subtitle: "Documents & renewals")
            layout.drawKPIGrid([
                ("Documents", "\(snapshot.compliance.totalDocuments)", nil),
                ("Expired", "\(snapshot.compliance.expiredCount)", nil),
                ("Expiring", "\(snapshot.compliance.expiringSoonCount)", nil),
                ("Missing", "\(snapshot.compliance.missingCount)", nil)
            ])
            let validDocs = max(
                0,
                snapshot.compliance.totalDocuments
                    - snapshot.compliance.expiredCount
                    - snapshot.compliance.expiringSoonCount
                    - snapshot.compliance.missingCount
            )
            if let chart = FleetReportChartRenderer.complianceChart(
                expired: snapshot.compliance.expiredCount,
                expiring: snapshot.compliance.expiringSoonCount,
                missing: snapshot.compliance.missingCount,
                valid: validDocs
            ) {
                layout.drawChartImage(chart, height: 188)
            }
            if !snapshot.compliance.alerts.isEmpty {
                layout.drawTable(
                    headers: ["Document", "Vehicle", "Due", "Status"],
                    rows: Array(snapshot.compliance.alerts.prefix(15).map { alert in
                        let due = alert.dueDate.map { dateFormatter.string(from: $0) } ?? "—"
                        return [
                            alert.documentType.rawValue,
                            alert.plateNumber,
                            due,
                            alert.severity.rawValue
                        ]
                    }),
                    severityColumn: 3
                )
            }

            layout.drawSectionHeader("Routing", subtitle: "Trip patterns & utilization")
            layout.drawStatRow([
                ("Avg trip", "\(Int(snapshot.routing.averageTripDistance.rounded())) km"),
                ("Idle vehicles", "\(snapshot.routing.idleVehicles)"),
                ("Overloaded", "\(snapshot.routing.overloadedVehicles)")
            ])
            layout.drawInfoBanner(snapshot.routing.recommendation)
            if let chart = FleetReportChartRenderer.topRoutesChart(
                routes: snapshot.routing.repeatedRoutes.map { ($0.routeName, $0.tripCount) }
            ) {
                layout.drawChartImage(chart, height: min(220, CGFloat(80 + snapshot.routing.repeatedRoutes.prefix(5).count * 32)))
            }
            if !snapshot.routing.repeatedRoutes.isEmpty {
                layout.drawTable(
                    headers: ["Route", "Trips", "Avg distance"],
                    rows: Array(snapshot.routing.repeatedRoutes.prefix(10).map { route in
                        [
                            route.routeName,
                            "\(route.tripCount)",
                            "\(Int(route.averageDistance.rounded())) km"
                        ]
                    })
                )
            }

            layout.drawSectionHeader("Recommendations", subtitle: "Prioritized actions")
            for recommendation in snapshot.recommendations {
                layout.drawRecommendationCard(
                    title: recommendation.title,
                    detail: recommendation.detail,
                    severity: recommendation.severity.rawValue
                )
            }

            layout.drawFooter()
        }

        let fileName = "TrackNGo-Fleet-Report-\(Int(snapshot.generatedAt.timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: Data.WritingOptions.atomic)
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
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "Today" }
        return "\(days)d left"
    }
}

// MARK: - Layout engine

private struct PDFLayout {
    let context: UIGraphicsPDFRendererContext
    let pageRect: CGRect
    let margin: CGFloat
    let contentWidth: CGFloat
    let brand: UIColor
    let brandLight: UIColor
    let cardBorder: UIColor

    var y: CGFloat = 0
    var pageNumber = 0

    mutating func beginCover(title: String, organization: String, generated: String) {
        context.beginPage()
        pageNumber += 1
        y = 0

        let bandHeight: CGFloat = 200
        brand.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageRect.width, height: bandHeight)).fill()

        let iconRect = CGRect(x: margin, y: 48, width: 120, height: 44)
        UIColor.white.withAlphaComponent(0.2).setFill()
        UIBezierPath(roundedRect: iconRect, cornerRadius: 14).fill()
        drawText(AppBranding.name, in: iconRect.insetBy(dx: 4, dy: 18), font: .boldSystemFont(ofSize: 11), color: .white, alignment: .center)

        drawText(title, at: CGPoint(x: margin, y: 124), font: .boldSystemFont(ofSize: 26), color: .white, maxWidth: contentWidth)
        drawText(organization, at: CGPoint(x: margin, y: 158), font: .systemFont(ofSize: 15, weight: .medium), color: UIColor.white.withAlphaComponent(0.9), maxWidth: contentWidth)
        drawText("Generated \(generated)", at: CGPoint(x: margin, y: 182), font: .systemFont(ofSize: 12), color: UIColor.white.withAlphaComponent(0.75), maxWidth: contentWidth)

        y = bandHeight + 28
        drawText(AppBranding.tagline, at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 13), color: .secondaryLabel, maxWidth: contentWidth)
        y += 36
    }

    mutating func drawSectionHeader(_ title: String, subtitle: String? = nil) {
        ensureSpace(56)
        y += 12

        let accent = CGRect(x: margin, y: y + 4, width: 4, height: 22)
        brand.setFill()
        UIBezierPath(roundedRect: accent, cornerRadius: 2).fill()

        drawText(title, at: CGPoint(x: margin + 12, y: y), font: .boldSystemFont(ofSize: 17), color: .label, maxWidth: contentWidth - 12)
        y += 22
        if let subtitle {
            drawText(subtitle, at: CGPoint(x: margin + 12, y: y), font: .systemFont(ofSize: 11), color: .secondaryLabel, maxWidth: contentWidth - 12)
            y += 18
        } else {
            y += 4
        }
    }

    mutating func drawKPIGrid(_ items: [(String, String, String?)]) {
        ensureSpace(88)
        let gap: CGFloat = 10
        let cardW = (contentWidth - gap) / 2
        let cardH: CGFloat = 64
        var index = 0
        let rowY = y

        for item in items.prefix(4) {
            let col = index % 2
            let row = index / 2
            let x = margin + CGFloat(col) * (cardW + gap)
            let cardY = rowY + CGFloat(row) * (cardH + gap)
            drawMetricCard(
                frame: CGRect(x: x, y: cardY, width: cardW, height: cardH),
                label: item.0,
                value: item.1,
                caption: item.2
            )
            index += 1
        }
        y = rowY + CGFloat((min(items.count, 4) + 1) / 2) * (cardH + gap) + 6
    }

    mutating func drawStatRow(_ pairs: [(String, String)]) {
        ensureSpace(44)
        let chipGap: CGFloat = 8
        var x = margin
        let chipH: CGFloat = 32
        for pair in pairs {
            let labelW = (pair.0 as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 9)]).width
            let valueW = (pair.1 as NSString).size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 11)]).width
            let chipW = min(max(labelW, valueW) + 24, contentWidth / 2 - 4)
            if x + chipW > margin + contentWidth {
                x = margin
                y += chipH + chipGap
                ensureSpace(chipH + 8)
            }
            let frame = CGRect(x: x, y: y, width: chipW, height: chipH)
            brandLight.setFill()
            UIBezierPath(roundedRect: frame, cornerRadius: 8).fill()
            cardBorder.setStroke()
            UIBezierPath(roundedRect: frame, cornerRadius: 8).stroke()
            drawText(pair.0.uppercased(), in: frame.insetBy(dx: 8, dy: 4), font: .systemFont(ofSize: 8, weight: .semibold), color: .secondaryLabel)
            drawText(pair.1, in: frame.insetBy(dx: 8, dy: 14), font: .boldSystemFont(ofSize: 11), color: .label)
            x += chipW + chipGap
        }
        y += 40
    }

    mutating func drawNarrative(_ text: String) {
        let font = UIFont.systemFont(ofSize: 11)
        let textH = textHeight(text, font: font, width: contentWidth)
        ensureSpace(textH + 10)
        drawText(text, at: CGPoint(x: margin, y: y), font: font, color: .secondaryLabel, maxWidth: contentWidth)
        y += textH + 10
    }

    mutating func drawChartImage(_ image: UIImage, height: CGFloat) {
        ensureSpace(height + 8)
        let frame = CGRect(x: margin, y: y, width: contentWidth, height: height)
        UIColor.secondarySystemGroupedBackground.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).fill()
        cardBorder.setStroke()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).stroke()
        let inset = frame.insetBy(dx: 8, dy: 8)
        image.draw(in: inset)
        y += height + 14
    }

    mutating func drawInfoBanner(_ text: String) {
        let innerPad: CGFloat = 12
        let font = UIFont.systemFont(ofSize: 12)
        let textH = textHeight(text, font: font, width: contentWidth - innerPad * 2)
        let boxH = textH + innerPad * 2
        ensureSpace(boxH + 8)
        let frame = CGRect(x: margin, y: y, width: contentWidth, height: boxH)
        brandLight.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).fill()
        brand.withAlphaComponent(0.35).setStroke()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).lineWidth = 1
        UIBezierPath(roundedRect: frame, cornerRadius: 10).stroke()
        drawText(text, in: frame.insetBy(dx: innerPad, dy: innerPad), font: font, color: .label)
        y += boxH + 10
    }

    mutating func drawTable(headers: [String], rows: [[String]], severityColumn: Int? = nil) {
        let colCount = headers.count
        let colW = contentWidth / CGFloat(colCount)
        let headerH: CGFloat = 28
        let rowH: CGFloat = 34
        let tableH = headerH + CGFloat(rows.count) * rowH + 8
        ensureSpace(tableH)

        let tableFrame = CGRect(x: margin, y: y, width: contentWidth, height: tableH - 4)
        cardBorder.setStroke()
        UIBezierPath(roundedRect: tableFrame, cornerRadius: 8).stroke()

        let headerFrame = CGRect(x: margin, y: y, width: contentWidth, height: headerH)
        brand.setFill()
        UIBezierPath(
            roundedRect: headerFrame,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 8, height: 8)
        ).fill()

        for (i, header) in headers.enumerated() {
            let cell = CGRect(x: margin + CGFloat(i) * colW + 6, y: y + 6, width: colW - 10, height: headerH - 10)
            drawText(header.uppercased(), in: cell, font: .systemFont(ofSize: 8, weight: .bold), color: .white)
        }
        y += headerH

        for (rowIndex, row) in rows.enumerated() {
            if rowIndex % 2 == 1 {
                UIColor.secondarySystemFill.withAlphaComponent(0.5).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: rowH)).fill()
            }
            for (i, cellText) in row.enumerated() {
                let cell = CGRect(x: margin + CGFloat(i) * colW + 6, y: y + 5, width: colW - 10, height: rowH - 8)
                let color: UIColor
                if severityColumn == i {
                    color = severityColor(for: cellText)
                } else {
                    color = .label
                }
                drawText(cellText, in: cell, font: .systemFont(ofSize: 9), color: color)
            }
            y += rowH
        }
        y += 12
    }

    mutating func drawRecommendationCard(title: String, detail: String, severity: String) {
        let titleFont = UIFont.boldSystemFont(ofSize: 12)
        let detailFont = UIFont.systemFont(ofSize: 10)
        let detailH = textHeight(detail, font: detailFont, width: contentWidth - 80)
        let cardH = max(52, detailH + 28)
        ensureSpace(cardH + 8)

        let frame = CGRect(x: margin, y: y, width: contentWidth, height: cardH)
        UIColor.secondarySystemGroupedBackground.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).fill()
        cardBorder.setStroke()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).stroke()

        let pillColor = severityColor(for: severity)
        let pill = CGRect(x: frame.maxX - 72, y: frame.minY + 10, width: 62, height: 18)
        pillColor.withAlphaComponent(0.15).setFill()
        UIBezierPath(roundedRect: pill, cornerRadius: 9).fill()
        drawText(severity, in: pill, font: .systemFont(ofSize: 8, weight: .semibold), color: pillColor, alignment: .center)

        drawText(title, at: CGPoint(x: frame.minX + 12, y: frame.minY + 10), font: titleFont, color: .label, maxWidth: contentWidth - 88)
        drawText(detail, at: CGPoint(x: frame.minX + 12, y: frame.minY + 28), font: detailFont, color: .secondaryLabel, maxWidth: contentWidth - 24)
        y += cardH + 8
    }

    mutating func drawFooter() {
        ensureSpace(24)
        let footer = AppBranding.confidentialFooter
        drawText(footer, at: CGPoint(x: margin, y: pageRect.height - margin - 10), font: .systemFont(ofSize: 9), color: .tertiaryLabel, maxWidth: contentWidth, alignment: .center)
    }

    mutating func drawMetricCard(frame: CGRect, label: String, value: String, caption: String?) {
        brandLight.setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).fill()
        cardBorder.setStroke()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).stroke()
        drawText(label.uppercased(), in: frame.insetBy(dx: 10, dy: 8), font: .systemFont(ofSize: 8, weight: .semibold), color: .secondaryLabel)
        drawText(value, in: frame.insetBy(dx: 10, dy: 22), font: .boldSystemFont(ofSize: 18), color: brand)
        if let caption {
            drawText(caption, in: frame.insetBy(dx: 10, dy: 44), font: .systemFont(ofSize: 9), color: .secondaryLabel)
        }
    }

    mutating func ensureSpace(_ required: CGFloat) {
        if y + required > pageRect.height - margin - 28 {
            drawPageFooter()
            context.beginPage()
            pageNumber += 1
            y = margin
            drawPageHeader()
        }
    }

    mutating func drawPageHeader() {
        let h: CGFloat = 36
        brand.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageRect.width, height: h)).fill()
        drawText(AppBranding.reportProductName, at: CGPoint(x: margin, y: 10), font: .boldSystemFont(ofSize: 11), color: .white, maxWidth: contentWidth * 0.7)
        drawText("Page \(pageNumber)", at: CGPoint(x: pageRect.width - margin - 60, y: 10), font: .systemFont(ofSize: 10), color: UIColor.white.withAlphaComponent(0.85), maxWidth: 60, alignment: .right)
        y = h + 16
    }

    mutating func drawPageFooter() {
        let footerY = pageRect.height - margin + 4
        drawText("Page \(pageNumber)", at: CGPoint(x: margin, y: footerY), font: .systemFont(ofSize: 9), color: .tertiaryLabel, maxWidth: contentWidth, alignment: .right)
    }

    func severityColor(for raw: String) -> UIColor {
        switch raw.lowercased() {
        case "critical": return .systemRed
        case "action": return .systemOrange
        case "watch": return .systemYellow
        default: return .systemGreen
        }
    }

    func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        return ceil(attr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
    }

    func drawText(
        _ text: String,
        at origin: CGPoint,
        font: UIFont,
        color: UIColor,
        maxWidth: CGFloat,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        let h = textHeight(text, font: font, width: maxWidth)
        attr.draw(in: CGRect(x: origin.x, y: origin.y, width: maxWidth, height: h))
    }

    func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
        attr.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
}
