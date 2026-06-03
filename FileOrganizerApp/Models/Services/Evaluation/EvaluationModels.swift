//
//  EvaluationModels.swift
//  File Organizer App
//
//  Row-level and report types for classification evaluation.
//

import Foundation

// MARK: - Expected label (phase 3+)

struct ExpectedLabel: Equatable, Codable {
    let expectedCategory: String
    let expectedSubfolder: String
}

// MARK: - Evaluation row

struct EvaluationRow: Equatable, Codable {
    let fileName: String
    let filePath: String
    let category: String
    let subfolder: String
    let confidence: Double
    let method: ClassificationMethod
    let durationMs: Double
    let reasoning: String?
    let error: String?
    let expected: ExpectedLabel?

    init(
        fileName: String,
        filePath: String,
        result: ClassificationResult,
        durationMs: Double,
        error: String? = nil,
        expected: ExpectedLabel? = nil
    ) {
        self.fileName = fileName
        self.filePath = filePath
        self.category = result.category
        self.subfolder = result.subfolder
        self.confidence = result.confidence
        self.method = result.method
        self.durationMs = durationMs
        self.reasoning = result.reasoning
        self.error = error
        self.expected = expected
    }

    var destinationPath: String {
        "\(category)/\(subfolder)"
    }
}

// MARK: - File set (discovery result)

struct EvaluationFileSet {
    let urls: [URL]
    let sourceDescription: String
    /// When non-nil, caller should delete this directory after the run (temporary fixtures).
    let cleanupDirectory: URL?
}

// MARK: - Evaluation report

struct EvaluationReport: Equatable, Codable {
    let config: EvaluationConfig
    let runLabel: String
    let sourceDescription: String
    let generatedAt: Date
    let rows: [EvaluationRow]

    // MARK: - Aggregates

    var fileCount: Int { rows.count }

    var successCount: Int {
        rows.filter { $0.error == nil }.count
    }

    var averageConfidence: Double {
        guard !rows.isEmpty else { return 0 }
        return rows.map(\.confidence).reduce(0, +) / Double(rows.count)
    }

    var averageDurationMs: Double {
        guard !rows.isEmpty else { return 0 }
        return rows.map(\.durationMs).reduce(0, +) / Double(rows.count)
    }

    var fallbackCount: Int {
        rows.filter { $0.method == .fallback }.count
    }

    var fallbackRate: Double {
        guard !rows.isEmpty else { return 0 }
        return Double(fallbackCount) / Double(rows.count)
    }

    var categoryDistribution: [String: Int] {
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.category, default: 0] += 1
        }
        return counts
    }

    var subfolderDistribution: [String: Int] {
        var counts: [String: Int] = [:]
        for row in rows {
            let key = "\(row.category)/\(row.subfolder)"
            counts[key, default: 0] += 1
        }
        return counts
    }

    // MARK: - Export

    func exportJSON(prettyPrinted: Bool = true) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try? encoder.encode(self)
    }

    static func decodeJSON(_ data: Data) throws -> EvaluationReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(EvaluationReport.self, from: data)
    }

    func exportCSV() -> String {
        var lines: [String] = [
            "fileName,filePath,runLabel,category,subfolder,confidence,method,durationMs,reasoning,error,expectedCategory,expectedSubfolder"
        ]
        for row in rows {
            lines.append([
                csvEscape(row.fileName),
                csvEscape(row.filePath),
                csvEscape(runLabel),
                csvEscape(row.category),
                csvEscape(row.subfolder),
                String(format: "%.4f", row.confidence),
                csvEscape(row.method.rawValue),
                String(format: "%.1f", row.durationMs),
                csvEscape(row.reasoning ?? ""),
                csvEscape(row.error ?? ""),
                csvEscape(row.expected?.expectedCategory ?? ""),
                csvEscape(row.expected?.expectedSubfolder ?? "")
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func printReport(to output: ((String) -> Void)? = nil) {
        let write = output ?? { print($0) }
        let divider = String(repeating: "=", count: 60)
        let dash = String(repeating: "-", count: 60)

        write(divider)
        write("Classification Evaluation Report")
        write(divider)
        write("Run label:      \(runLabel)")
        write("Source:         \(sourceDescription)")
        write("Generated:      \(ISO8601DateFormatter().string(from: generatedAt))")
        write("Files:          \(fileCount) (\(successCount) succeeded)")
        write("")
        write("Average confidence: \(String(format: "%.1f%%", averageConfidence * 100))")
        write("Average time:       \(String(format: "%.0f", averageDurationMs))ms")
        write("Fallback rate:      \(String(format: "%.1f%%", fallbackRate * 100)) (\(fallbackCount)/\(fileCount))")
        write("")

        if !categoryDistribution.isEmpty {
            write("Category distribution:")
            for (category, count) in categoryDistribution.sorted(by: { $0.key < $1.key }) {
                write("  \(category): \(count)")
            }
            write("")
        }

        write(dash)
        write("Per file:")
        for row in rows {
            write("  \(row.fileName)")
            if let error = row.error {
                write("    ERROR: \(error)")
            } else {
                write("    → \(row.destinationPath)")
                write("    Method: \(row.method.rawValue), Confidence: \(String(format: "%.2f", row.confidence)), Time: \(String(format: "%.0f", row.durationMs))ms")
                if let reasoning = row.reasoning {
                    write("    Reasoning: \(reasoning)")
                }
            }
        }
        write(divider)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
