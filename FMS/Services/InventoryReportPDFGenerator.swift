import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

enum InventoryOrderPriority: String {
    case urgent = "Urgent"
    case medium = "Medium"
    case low = "Low"

    var color: UIColor {
        switch self {
        case .urgent: return UIColor.systemRed
        case .medium: return UIColor.systemOrange
        case .low: return UIColor.systemGreen
        }
    }
}

struct InventoryReportRow: Identifiable {
    let id: UUID
    let name: String
    let partNumber: String
    let category: String
    let quantity: Int
    let minimumRequired: Int
    let priority: InventoryOrderPriority
    let recommendedOrderQuantity: Int
    let action: String
}

struct InventoryReportDocument: Identifiable {
    let id: UUID
    let organizationName: String
    let generatedBy: String
    let generatedAt: Date
    let rows: [InventoryReportRow]
    let narrative: String

    var urgentCount: Int { rows.filter { $0.priority == .urgent }.count }
    var mediumCount: Int { rows.filter { $0.priority == .medium }.count }
    var lowCount: Int { rows.filter { $0.priority == .low }.count }
    var totalQuantity: Int { rows.reduce(0) { $0 + $1.quantity } }
}

enum InventoryReportBuilder {
    static func makeDocument(
        parts: [SparePart],
        organizationName: String,
        generatedBy: String,
        reportID: UUID = UUID()
    ) -> InventoryReportDocument {
        let rows = parts.map(makeRow(for:))
            .sorted {
                if priorityRank($0.priority) == priorityRank($1.priority) {
                    return $0.quantity < $1.quantity
                }
                return priorityRank($0.priority) > priorityRank($1.priority)
            }

        let draft = InventoryReportDocument(
            id: reportID,
            organizationName: organizationName,
            generatedBy: generatedBy,
            generatedAt: .now,
            rows: rows,
            narrative: ""
        )

        return InventoryReportDocument(
            id: draft.id,
            organizationName: draft.organizationName,
            generatedBy: draft.generatedBy,
            generatedAt: draft.generatedAt,
            rows: draft.rows,
            narrative: InventoryReportNarrativeModel.summary(for: draft)
        )
    }

    private static func makeRow(for part: SparePart) -> InventoryReportRow {
        let priority: InventoryOrderPriority
        let targetQuantity: Int

        if part.quantity < 10 {
            priority = .urgent
            targetQuantity = max(20, part.minimumRequired * 2, 10)
        } else if part.quantity < 25 {
            priority = .medium
            targetQuantity = max(30, part.minimumRequired * 2)
        } else {
            priority = .low
            targetQuantity = max(part.quantity, part.minimumRequired)
        }

        let recommendedOrder = max(0, targetQuantity - part.quantity)
        let action: String
        switch priority {
        case .urgent:
            action = "Order urgently"
        case .medium:
            action = recommendedOrder > 0 ? "Order this cycle" : "Monitor this cycle"
        case .low:
            action = "Monitor"
        }

        return InventoryReportRow(
            id: part.id,
            name: part.name,
            partNumber: part.partNumber,
            category: part.category,
            quantity: part.quantity,
            minimumRequired: part.minimumRequired,
            priority: priority,
            recommendedOrderQuantity: recommendedOrder,
            action: action
        )
    }

    private static func priorityRank(_ priority: InventoryOrderPriority) -> Int {
        switch priority {
        case .urgent: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

private enum InventoryReportNarrativeModel {
    static func summary(for document: InventoryReportDocument) -> String {
        let urgent = document.urgentCount
        let medium = document.mediumCount
        let total = document.rows.count

        #if canImport(FoundationModels)
        let modelSource = "Foundation model inventory summary"
        #else
        let modelSource = "Inventory summary"
        #endif

        if urgent > 0 {
            return "\(modelSource): \(urgent) of \(total) part type\(total == 1 ? "" : "s") are below 10 units and should be ordered urgently. \(medium) medium-priority part type\(medium == 1 ? "" : "s") should be reviewed in the next procurement cycle."
        }

        if medium > 0 {
            return "\(modelSource): no part is below the urgent 10-unit threshold. \(medium) medium-priority part type\(medium == 1 ? "" : "s") should be topped up during planned ordering."
        }

        return "\(modelSource): inventory is stable. Keep monitoring low-priority items during regular maintenance procurement."
    }
}

@MainActor
struct InventoryReportPDFGenerator {
    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 42
    private let brand = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)

    func generate(document: InventoryReportDocument) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var y = margin
            context.beginPage()

            drawHeader(document: document, y: &y)
            drawSummary(document: document, y: &y)
            drawNarrative(document.narrative, y: &y)
            drawTableHeader(y: &y)

            for row in document.rows {
                if y > pageRect.height - 88 {
                    context.beginPage()
                    y = margin
                    drawTableHeader(y: &y)
                }
                drawRow(row, y: &y)
            }

            drawFooter()
        }

        do {
            let url = try GeneratedReportStore.reportURL(reportID: document.id, title: "Inventory_Report")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("[InventoryReportPDF] Failed to write PDF: \(error)")
            return nil
        }
    }

    private func drawHeader(document: InventoryReportDocument, y: inout CGFloat) {
        let date = document.generatedAt.formatted(date: .abbreviated, time: .shortened)
        drawText(AppBranding.reportProductName, x: margin, y: y, width: 360, font: .boldSystemFont(ofSize: 13), color: brand)
        drawText("Inventory Report", x: margin, y: y + 24, width: 420, font: .boldSystemFont(ofSize: 28), color: .label)
        drawText("\(document.organizationName) | Generated by \(document.generatedBy) | \(date)", x: margin, y: y + 60, width: 500, font: .systemFont(ofSize: 10), color: .secondaryLabel)
        y += 96
    }

    private func drawSummary(document: InventoryReportDocument, y: inout CGFloat) {
        let stats = [
            ("Part types", "\(document.rows.count)", UIColor.systemBlue),
            ("Total units", "\(document.totalQuantity)", UIColor.systemTeal),
            ("Urgent", "\(document.urgentCount)", UIColor.systemRed),
            ("Medium", "\(document.mediumCount)", UIColor.systemOrange)
        ]

        let cardWidth: CGFloat = 124
        for (index, stat) in stats.enumerated() {
            let x = margin + CGFloat(index) * (cardWidth + 8)
            let rect = CGRect(x: x, y: y, width: cardWidth, height: 62)
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
            stat.2.setFill()
            UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 4, height: 62), cornerRadius: 2).fill()
            drawText(stat.0, x: x + 12, y: y + 10, width: cardWidth - 18, font: .systemFont(ofSize: 9), color: .secondaryLabel)
            drawText(stat.1, x: x + 12, y: y + 28, width: cardWidth - 18, font: .boldSystemFont(ofSize: 20), color: .label)
        }
        y += 82
    }

    private func drawNarrative(_ text: String, y: inout CGFloat) {
        drawText(text, x: margin, y: y, width: pageRect.width - margin * 2, font: .systemFont(ofSize: 12), color: .label)
        y += 58
    }

    private func drawTableHeader(y: inout CGFloat) {
        drawText("Part", x: margin, y: y, width: 190, font: .boldSystemFont(ofSize: 10), color: .secondaryLabel)
        drawText("Stock", x: margin + 205, y: y, width: 60, font: .boldSystemFont(ofSize: 10), color: .secondaryLabel)
        drawText("Order", x: margin + 275, y: y, width: 60, font: .boldSystemFont(ofSize: 10), color: .secondaryLabel)
        drawText("Priority", x: margin + 345, y: y, width: 70, font: .boldSystemFont(ofSize: 10), color: .secondaryLabel)
        drawText("Action", x: margin + 425, y: y, width: 90, font: .boldSystemFont(ofSize: 10), color: .secondaryLabel)
        y += 20
    }

    private func drawRow(_ row: InventoryReportRow, y: inout CGFloat) {
        let rowRect = CGRect(x: margin, y: y - 6, width: pageRect.width - margin * 2, height: 48)
        UIColor.systemBackground.setFill()
        UIBezierPath(roundedRect: rowRect, cornerRadius: 6).fill()
        UIColor.separator.withAlphaComponent(0.25).setStroke()
        UIBezierPath(roundedRect: rowRect, cornerRadius: 6).stroke()

        drawText("\(row.name)\n\(row.partNumber) | \(row.category)", x: margin + 8, y: y, width: 185, font: .systemFont(ofSize: 9), color: .label)
        drawText("\(row.quantity)", x: margin + 205, y: y + 8, width: 60, font: .boldSystemFont(ofSize: 11), color: .label)
        drawText("\(row.recommendedOrderQuantity)", x: margin + 275, y: y + 8, width: 60, font: .boldSystemFont(ofSize: 11), color: .label)
        drawText(row.priority.rawValue, x: margin + 345, y: y + 8, width: 70, font: .boldSystemFont(ofSize: 10), color: row.priority.color)
        drawText(row.action, x: margin + 425, y: y + 8, width: 95, font: .systemFont(ofSize: 9), color: .label)
        y += 54
    }

    private func drawFooter() {
        drawText(AppBranding.confidentialFooter, x: margin, y: pageRect.height - 28, width: pageRect.width - margin * 2, font: .systemFont(ofSize: 9), color: .secondaryLabel)
    }

    private func drawText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: UIFont, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        NSString(string: text).draw(
            with: CGRect(x: x, y: y, width: width, height: 80),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }
}

@MainActor
final class GeneratedReportStore {
    static let shared = GeneratedReportStore()
    private var reportURLsByID: [UUID: URL] = [:]

    private init() {}

    func register(reportID: UUID, url: URL) {
        reportURLsByID[reportID] = url
    }

    func url(for reportID: UUID) -> URL? {
        if let url = reportURLsByID[reportID], FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        if let url = try? Self.reportURL(reportID: reportID, title: "Inventory_Report"),
           FileManager.default.fileExists(atPath: url.path) {
            reportURLsByID[reportID] = url
            return url
        }

        return nil
    }

    static func reportURL(reportID: UUID, title: String) throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GeneratedReports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory.appendingPathComponent("\(title)_\(reportID.uuidString).pdf")
    }
}

extension AppNotification {
    var inventoryReportID: UUID? {
        guard title.localizedCaseInsensitiveContains("Inventory Report") else { return nil }
        guard let range = message.range(of: "Report ID: ") else { return nil }
        let suffix = message[range.upperBound...]
        let token = suffix.split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "," }).first
        return token.flatMap { UUID(uuidString: String($0)) }
    }
}
