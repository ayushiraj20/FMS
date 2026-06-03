import Foundation
import UIKit
import Vision

struct VehicleDocumentOCRResult {
    var detectedType: DocumentType?
    var documentNumber: String
    var expiryDate: Date?

    var hasUsefulData: Bool {
        detectedType != nil || !documentNumber.isEmpty || expiryDate != nil
    }
}

enum VehicleDocumentOCRService {
    static func extractDocumentData(from image: UIImage) async throws -> VehicleDocumentOCRResult {
        let lines = try await recognizeText(in: image)
        return parse(lines: lines)
    }

    private static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw FuelOCRService.OCRError.invalidImage
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

    private static func parse(lines: [String]) -> VehicleDocumentOCRResult {
        let normalizedLines = lines.map {
            $0.replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let detectedType = detectType(from: normalizedLines)
        let documentNumber = detectDocumentNumber(from: normalizedLines, type: detectedType)
        let expiryDate = detectExpiryDate(from: normalizedLines)

        return VehicleDocumentOCRResult(
            detectedType: detectedType,
            documentNumber: documentNumber,
            expiryDate: expiryDate
        )
    }

    private static func detectType(from lines: [String]) -> DocumentType? {
        let text = lines.joined(separator: "\n").lowercased()

        if text.contains("pollution under control") || text.contains("puc certificate") || text.contains("puc") {
            return .puc
        }
        if text.contains("insurance") || text.contains("policy no") || text.contains("insurer") || text.contains("policy number") {
            return .insurance
        }
        if text.contains("national permit") || text.contains("goods permit") || text.contains("permit no") || text.contains("permit") {
            return .permit
        }
        if text.contains("certificate of registration") || text.contains("registration certificate") || text.contains("regn. no") || text.contains("registration no") {
            return .rc
        }

        return nil
    }

    private static func detectDocumentNumber(from lines: [String], type: DocumentType?) -> String {
        if let contextualMatch = detectContextualDocumentNumber(from: lines, type: type), !contextualMatch.isEmpty {
            return sanitizeDocumentNumber(contextualMatch)
        }

        let keywordPatterns: [DocumentType: [String]] = [
            .rc: [
                #"registration\s*(?:number|no|no\.)[:\s-]*([A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{0,3}[\s\-]?\d{3,4})"#,
                #"regn\.?\s*(?:no|number)?[:\s-]*([A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{0,3}[\s\-]?\d{3,4})"#,
                #"vehicle\s*(?:number|no|no\.)[:\s-]*([A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{0,3}[\s\-]?\d{3,4})"#
            ],
            .insurance: [
                #"policy\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{6,})"#,
                #"policy[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{6,})"#,
                #"certificate\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{6,})"#
            ],
            .puc: [
                #"certificate\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#,
                #"puc\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#,
                #"cert(?:ificate)?\s*(?:sr\.?\s*)?no[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#,
                #"serial\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#,
                #"token\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#
            ],
            .permit: [
                #"permit\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#,
                #"national\s*permit[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#,
                #"permit\s*auth(?:orization)?\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#,
                #"auth(?:orization)?\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#,
                #"goods\s*permit[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{4,})"#
            ]
        ]

        if let type, let patterns = keywordPatterns[type] {
            let match = firstMatch(in: lines, patterns: patterns)
            if !match.isEmpty { return sanitizeDocumentNumber(match) }
        }

        if type == .rc || type == nil {
            let registrationCandidate = detectRegistrationCandidate(in: lines)
            if !registrationCandidate.isEmpty {
                return sanitizeDocumentNumber(registrationCandidate)
            }
        }

        let genericPatterns = [
            #"registration\s*(?:number|no|no\.)[:\s-]*([A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{0,3}[\s\-]?\d{3,4})"#,
            #"policy\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{6,})"#,
            #"certificate\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#,
            #"permit\s*(?:number|no|no\.)[:\s-]*((?=[A-Z0-9\/\-]*\d)[A-Z0-9\/\-]{5,})"#
        ]

        let fallback = firstMatch(in: lines, patterns: genericPatterns)
        return sanitizeDocumentNumber(fallback)
    }

    private static func detectExpiryDate(from lines: [String]) -> Date? {
        let preferredPatterns = [
            #"(?:(?:expiry|valid\s*upto|valid\s*up\s*to|valid\s*till|validity|expires?\s*on|expiry\s*date)[^0-9]{0,12})(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})"#,
            #"(?:(?:expiry|valid\s*upto|validity)[^A-Z0-9]{0,12})(\d{1,2}\s+[A-Z]{3,9}\s+\d{2,4})"#
        ]

        if let match = firstDateMatch(in: lines, patterns: preferredPatterns) {
            return match
        }

        let genericPatterns = [
            #"(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})"#,
            #"(\d{1,2}\s+[A-Z]{3,9}\s+\d{2,4})"#
        ]
        return firstDateMatch(in: lines, patterns: genericPatterns)
    }

    private static func firstMatch(in lines: [String], patterns: [String]) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for line in lines {
                let uppercaseLine = line.uppercased()
                let range = NSRange(uppercaseLine.startIndex..., in: uppercaseLine)
                if let match = regex.firstMatch(in: uppercaseLine, range: range),
                   match.numberOfRanges > 1,
                   let captureRange = Range(match.range(at: 1), in: uppercaseLine) {
                    return String(uppercaseLine[captureRange]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }

    private static func firstDateMatch(in lines: [String], patterns: [String]) -> Date? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range),
                   match.numberOfRanges > 1,
                   let captureRange = Range(match.range(at: 1), in: line) {
                    let raw = String(line[captureRange]).trimmingCharacters(in: .whitespaces)
                    if let date = parseDate(raw) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    private static func parseDate(_ value: String) -> Date? {
        let sanitized = value
            .replacingOccurrences(of: ".", with: "/")
            .replacingOccurrences(of: "-", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let formatters = [
            "dd/MM/yyyy", "d/M/yyyy", "dd/MM/yy", "d/M/yy",
            "dd MMM yyyy", "d MMM yyyy", "dd MMM yy", "d MMM yy",
            "dd MMMM yyyy", "d MMMM yyyy"
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }

        for formatter in formatters {
            if let date = formatter.date(from: sanitized) {
                return date
            }
        }
        return nil
    }

    private static func sanitizeDocumentNumber(_ value: String) -> String {
        value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func detectContextualDocumentNumber(from lines: [String], type: DocumentType?) -> String? {
        let contexts = contextKeywords(for: type)
        guard !contexts.isEmpty else { return nil }

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.uppercased()
            guard let matchedContext = contexts.first(where: { line.contains($0) }) else { continue }

            if let inline = extractValueFromLabelLine(line, matchedContext: matchedContext, type: type),
               isValidCandidate(inline, for: type) {
                return inline
            }

            let nextCandidates = Array(lines.dropFirst(index + 1).prefix(3))
            for candidateLine in nextCandidates {
                if let candidate = extractCandidate(from: candidateLine, for: type), isValidCandidate(candidate, for: type) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func contextKeywords(for type: DocumentType?) -> [String] {
        switch type {
        case .rc:
            return ["REGISTRATION MARK", "REGISTRATION NO", "REGN NO", "REGN. NO", "REGISTRATION NUMBER", "VEHICLE NO"]
        case .insurance:
            return ["POLICY NO", "POLICY NUMBER", "CERTIFICATE NO", "CERTIFICATE NUMBER", "COVER NOTE NO"]
        case .puc:
            return [
                "PUC NO", "PUC NUMBER", "PUC CERTIFICATE",
                "CERTIFICATE NO", "CERTIFICATE NUMBER", "CERTIFICATE SR NO",
                "CERTIFICATE SR. NO", "SERIAL NO", "SR NO", "TOKEN NO",
                "COMPUTER I.D. NO", "COMPUTER ID NO", "COMPUTER I D NO"
            ]
        case .permit:
            return [
                "PERMIT NO", "PERMIT NUMBER", "NATIONAL PERMIT",
                "PERMIT AUTH NO", "PERMIT AUTH. NO", "AUTHORIZATION NO",
                "AUTHORISATION NO", "GOODS PERMIT", "AUTHORIZATION DETAILS"
            ]
        case nil:
            return [
                "REGISTRATION MARK", "REGISTRATION NO", "REGN NO", "REGN. NO",
                "POLICY NO", "POLICY NUMBER", "CERTIFICATE NO", "CERTIFICATE NUMBER",
                "PERMIT NO", "PERMIT NUMBER"
            ]
        }
    }

    private static func extractValueFromLabelLine(_ line: String, matchedContext: String, type: DocumentType?) -> String? {
        let separators = [":", "："]
        for separator in separators {
            if let range = line.range(of: separator) {
                let suffix = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let candidate = extractCandidate(from: suffix, for: type) {
                    return candidate
                }
            }
        }

        if let contextRange = line.range(of: matchedContext) {
            let suffix = String(line[contextRange.upperBound...])
                .replacingOccurrences(of: ".", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let candidate = extractCandidate(from: suffix, for: type) {
                return candidate
            }
        }

        // Remove common numeric bullet prefixes like "1." or "(i)"
        let stripped = line.replacingOccurrences(
            of: #"^\s*(?:\(?[IVX0-9A-Z]+\)?[.)]?\s*)+"#,
            with: "",
            options: .regularExpression
        )
        return extractCandidate(from: stripped, for: type)
    }

    private static func extractCandidate(from line: String, for type: DocumentType?) -> String? {
        let uppercased = line.uppercased()

        if type == .rc || type == nil {
            if let rc = firstRegexMatch(#"\b[A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{1,3}[\s\-]?\d{3,4}\b"#, in: uppercased) {
                return rc
            }
        }

        if type == .puc || type == .permit {
            let targetedPatterns = [
                #"\b(?=[A-Z0-9\/\-]{4,}\b)(?=.*\d)[A-Z0-9]+(?:[\/\-][A-Z0-9]+)+\b"#,
                #"\b[A-Z]{2,}\d{2,}[A-Z0-9\-\/]*\b"#,
                #"\b[A-Z]{1,4}\d{3,}[A-Z0-9\/\-]*\b"#,
                #"\b\d{4,}[A-Z0-9\/\-]*\b"#
            ]

            for pattern in targetedPatterns {
                if let match = firstRegexMatch(pattern, in: uppercased), isValidCandidate(match, for: type) {
                    return match
                }
            }
        }

        let alphanumericRuns = uppercased
            .components(separatedBy: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "/-")))
            .filter { $0.count >= 5 }

        for token in alphanumericRuns {
            if isValidCandidate(token, for: type) {
                return token
            }
        }

        return nil
    }

    private static func isValidCandidate(_ value: String, for type: DocumentType?) -> Bool {
        let candidate = sanitizeDocumentNumber(value)
        guard !candidate.isEmpty else { return false }

        let blacklist = [
            "BAZAAR", "POLICY", "NUMBER", "CERTIFICATE", "INSURANCE", "ORIENTAL",
            "REGISTRATION", "VEHICLE", "PRIVATE", "LIMITED", "INDIA", "MUMBAI"
        ]
        if blacklist.contains(candidate) { return false }

        switch type {
        case .rc:
            return candidate.range(of: #"^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{3,4}$"#, options: .regularExpression) != nil
        case .puc, .permit:
            return candidate.count >= 4 &&
                candidate.filter(\.isNumber).count >= 3 &&
                candidate.range(of: #"^[A-Z0-9\/\-]+$"#, options: .regularExpression) != nil
        case .insurance, nil:
            return candidate.count >= 6 && candidate.contains(where: \.isNumber)
        }
    }

    private static func firstRegexMatch(_ pattern: String, in value: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let matchRange = Range(match.range, in: value) else { return nil }
        return String(value[matchRange])
    }

    private static func detectRegistrationCandidate(in lines: [String]) -> String {
        let patterns = [
            #"\b[A-Z]{2}[\s\-]?\d{1,2}[\s\-]?[A-Z]{1,3}[\s\-]?\d{3,4}\b"#,
            #"\b[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{3,4}\b"#
        ]

        let blacklist = [
            "CERTIFICATE", "REGISTRATION", "NUMBER", "VEHICLE", "INSURANCE",
            "POLICY", "PERMIT", "BAZAAR", "INDIA", "PRIVATE", "TRANSPORT"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for line in lines {
                let uppercaseLine = line.uppercased()
                let range = NSRange(uppercaseLine.startIndex..., in: uppercaseLine)
                let matches = regex.matches(in: uppercaseLine, range: range)

                for match in matches {
                    guard let matchRange = Range(match.range, in: uppercaseLine) else { continue }
                    let candidate = String(uppercaseLine[matchRange]).trimmingCharacters(in: .whitespaces)
                    if blacklist.contains(candidate) { continue }
                    if candidate.filter(\.isNumber).count < 5 { continue }
                    return candidate
                }
            }
        }

        return ""
    }
}
