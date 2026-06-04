//
//  FuelOCRResult.swift
//  FMS
//
//  Created by Shashwat kumar on 03/06/26.
//


import Vision
import UIKit

// MARK: - OCR Result

struct FuelOCRResult {
    var stationName: String
    var litres: String
    var amount: String
    var fuelType: FuelType

    enum FuelType: String {
        case petrol = "Petrol"
        case diesel = "Diesel"
        case unknown = "Unknown"
    }

    var isEmpty: Bool {
        stationName.isEmpty && litres.isEmpty && amount.isEmpty
    }
}

// MARK: - Fuel OCR Service

/// Uses Apple Vision (VNRecognizeTextRequest) to extract fuel receipt data:
/// station name, litres dispensed, total amount, and fuel type (petrol/diesel).
///
/// Usage:
///   let result = try await FuelOCRService.extractReceiptData(from: image)
///
enum FuelOCRService {

    // MARK: - Public API

    /// Runs Vision OCR on `image` and returns extracted receipt fields.
    /// Throws if the Vision request itself fails (not if fields are simply not found).
    static func extractReceiptData(from image: UIImage) async throws -> FuelOCRResult {
        let lines = try await recognizeText(in: image)
        return parseReceiptLines(lines)
    }

    // MARK: - Vision Text Recognition

    private static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }

            // Accurate mode gives better results for printed receipt text
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-IN", "en-US", "hi"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsing Logic

    private static func parseReceiptLines(_ lines: [String]) -> FuelOCRResult {
        var stationName = ""
        var litres      = ""
        var amount      = ""
        var fuelType    = FuelOCRResult.FuelType.unknown

        // ── Detect fuel type ──────────────────────────────────────────────
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("petrol") || lower.contains("ms ") || lower.contains("unleaded") {
                fuelType = .petrol
                break
            }
            if lower.contains("diesel") || lower.contains("hsd") || lower.contains("high speed") {
                fuelType = .diesel
                break
            }
        }

        // ── Detect station name ───────────────────────────────────────────
        // Indian fuel station names: HP, IndianOil (IOCL), Bharat (BPCL), Reliance, Nayara
        let stationKeywords: [String: String] = [
            "hindustan petroleum": "Hindustan Petroleum",
            "hp ":                 "Hindustan Petroleum",
            "hpcl":                "Hindustan Petroleum",
            "indian oil":          "Indian Oil (IOCL)",
            "iocl":                "Indian Oil (IOCL)",
            "indane":              "Indian Oil (IOCL)",
            "bharat petroleum":    "Bharat Petroleum",
            "bpcl":                "Bharat Petroleum",
            "reliance":            "Reliance BP",
            "nayara":              "Nayara Energy",
            "essar":               "Nayara Energy",
            "shell":               "Shell",
        ]
        for line in lines {
            let lower = line.lowercased()
            for (keyword, canonical) in stationKeywords where lower.contains(keyword) {
                stationName = canonical
                break
            }
            if !stationName.isEmpty { break }
        }
        // If no known brand, try to grab a line that looks like a business name (Title Case, not all numbers)
        if stationName.isEmpty {
            for line in lines.prefix(6) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let hasLetter = trimmed.contains(where: { $0.isLetter })
                let looksLikeDate = trimmed.contains("/") && trimmed.count < 12
                if hasLetter && !looksLikeDate && trimmed.count >= 4 {
                    stationName = trimmed
                    break
                }
            }
        }

        // ── Detect litres / volume ────────────────────────────────────────
        // Patterns: "42.50 L", "Qty: 38.40", "Volume: 50.000", "42.500Ltr", "42.50lt"
        let litrePatterns: [String] = [
            #"(\d{1,3}[.,]\d{1,3})\s*(?:l(?:tr?s?|iter|itre)?|litr?e?s?)"#,  // 42.50 L, 38.40Ltrs
            #"(?:qty|vol(?:ume)?|litres?)[:\s]+(\d{1,3}[.,]\d{1,3})"#,         // Qty: 42.50
            #"(\d{2,3}[.,]\d{3})"#,                                             // 042.500 (pump format)
        ]
        litres = firstMatch(in: lines, patterns: litrePatterns, group: 1)

        // ── Detect amount / total ─────────────────────────────────────────
        // Patterns: "Total: ₹4150", "Amount: 3725.00", "Rs. 4,150", "NET AMT 4150"
        let amountPatterns: [String] = [
            #"(?:total|amount|amt|net\s*amt|grand\s*total|payable|sale\s*amount)[^\d]*(\d{3,6}(?:[.,]\d{0,2})?)"#,
            #"(?:rs\.?|₹|inr)\s*(\d{3,6}(?:[.,]\d{0,2})?)"#,
            #"(\d{3,6}[.,]\d{2})\s*(?:inr|rs|₹)?"#,
        ]
        amount = firstMatch(in: lines, patterns: amountPatterns, group: 1)

        // Normalise decimal separators (Indian receipts sometimes use comma as decimal)
        litres = normaliseDecimal(litres)
        amount = normaliseDecimal(amount)

        return FuelOCRResult(
            stationName: stationName,
            litres:      litres,
            amount:      amount,
            fuelType:    fuelType
        )
    }

    // MARK: - Helpers

    /// Searches each line in `lines` against each regex `pattern` (case-insensitive).
    /// Returns the first capture group `group` that matches, normalised (no trailing zeros).
    private static func firstMatch(in lines: [String], patterns: [String], group: Int) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range),
                   match.numberOfRanges > group,
                   let captureRange = Range(match.range(at: group), in: line) {
                    let raw = String(line[captureRange])
                        .replacingOccurrences(of: ",", with: ".")   // 4,150 → 4150 handled below
                        .trimmingCharacters(in: .whitespaces)
                    return raw
                }
            }
        }
        return ""
    }

    /// Converts comma-as-thousands-separator ("4,150") vs comma-as-decimal ("42,50").
    /// Indian receipts use "." as decimal in most cases; this normalises edge cases.
    private static func normaliseDecimal(_ value: String) -> String {
        // If the value has a comma and it's in thousands position (e.g. "4,150"), strip it
        let stripped = value.replacingOccurrences(of: ",", with: "")
        // Return the first valid Double representation
        if let _ = Double(stripped) { return stripped }
        return value
    }

    // MARK: - Errors

    enum OCRError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "Could not convert image for OCR processing." }
    }
}