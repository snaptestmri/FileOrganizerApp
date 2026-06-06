//
//  ClassifierComparison.swift
//  File Organizer App
//
//  Side-by-side classifier comparison (phase 1).
//

import Foundation

// MARK: - Backend

enum ClassifierBackend: String, CaseIterable, Codable, Comparable {
    case fallback
    case ollama
    case openai

    var displayName: String {
        switch self {
        case .fallback: return "Fallback"
        case .ollama: return "Ollama"
        case .openai: return "OpenAI"
        }
    }

    static func < (lhs: ClassifierBackend, rhs: ClassifierBackend) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Per-backend result

struct ClassifierRunResult: Equatable, Codable {
    let backend: ClassifierBackend
    let category: String
    let subfolder: String
    let confidence: Double
    let method: ClassificationMethod
    let durationMs: Double
    let reasoning: String?
    let error: String?

    var destinationPath: String {
        guard error == nil else { return "" }
        return "\(category)/\(subfolder)"
    }

    var wasSkipped: Bool {
        error == "skipped"
    }
}

// MARK: - Comparison row

struct ClassifierComparisonRow: Equatable, Codable {
    let fileName: String
    let filePath: String
    let results: [ClassifierRunResult]

    /// All non-skipped, successful backends produced the same destination.
    var allAgree: Bool {
        let paths = results
            .filter { $0.error == nil && !$0.wasSkipped }
            .map(\.destinationPath)
            .filter { !$0.isEmpty }
        guard paths.count >= 2 else { return true }
        return Set(paths).count == 1
    }

    func result(for backend: ClassifierBackend) -> ClassifierRunResult? {
        results.first { $0.backend == backend }
    }
}

// MARK: - Comparison report

struct ClassifierComparisonReport: Equatable, Codable {
    let config: EvaluationConfig
    let sourceDescription: String
    let generatedAt: Date
    let backendsUsed: [ClassifierBackend]
    let backendsSkipped: [ClassifierBackend]
    let rows: [ClassifierComparisonRow]

    var fileCount: Int { rows.count }

    var agreementCount: Int {
        rows.filter(\.allAgree).count
    }

    var disagreementCount: Int {
        rows.filter { !$0.allAgree }.count
    }

    func exportCSV() -> String {
        let sortedBackends = backendsUsed.sorted()
        var headers = ["fileName", "filePath"]
        for backend in sortedBackends {
            let key = backend.rawValue
            headers.append("\(key)_category")
            headers.append("\(key)_subfolder")
            headers.append("\(key)_confidence")
            headers.append("\(key)_method")
            headers.append("\(key)_durationMs")
            headers.append("\(key)_error")
        }
        headers.append("allAgree")

        var lines = [headers.joined(separator: ",")]
        for row in rows {
            var fields = [csvEscape(row.fileName), csvEscape(row.filePath)]
            for backend in sortedBackends {
                if let result = row.result(for: backend) {
                    fields.append(csvEscape(result.category))
                    fields.append(csvEscape(result.subfolder))
                    fields.append(String(format: "%.4f", result.confidence))
                    fields.append(csvEscape(result.method.rawValue))
                    fields.append(String(format: "%.1f", result.durationMs))
                    fields.append(csvEscape(result.error ?? ""))
                } else {
                    fields.append(contentsOf: Array(repeating: "", count: 6))
                }
            }
            fields.append(row.allAgree ? "yes" : "no")
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func printReport(to output: ((String) -> Void)? = nil) {
        let write = output ?? { print($0) }
        let divider = String(repeating: "=", count: 72)
        let dash = String(repeating: "-", count: 72)

        write(divider)
        write("Classifier Comparison Report")
        write(divider)
        write("Source:       \(sourceDescription)")
        write("Generated:    \(ISO8601DateFormatter().string(from: generatedAt))")
        write("Backends:     \(backendsUsed.map(\.displayName).joined(separator: ", "))")
        if !backendsSkipped.isEmpty {
            write("Skipped:      \(backendsSkipped.map(\.displayName).joined(separator: ", "))")
        }
        write("Files:        \(fileCount)")
        write("Agreements:   \(agreementCount)")
        write("Disagreements:\(disagreementCount)")
        write("")

        write(dash)
        for row in rows {
            let flag = row.allAgree ? "✓" : "✗"
            write("\(flag) \(row.fileName)")
            for backend in backendsUsed.sorted() {
                guard let result = row.result(for: backend) else { continue }
                if result.wasSkipped {
                    write("    \(backend.displayName): (skipped)")
                } else if let error = result.error {
                    write("    \(backend.displayName): ERROR — \(error)")
                } else {
                    write("    \(backend.displayName): \(result.destinationPath) (\(String(format: "%.2f", result.confidence)), \(String(format: "%.0f", result.durationMs))ms, \(result.method.rawValue))")
                }
            }
            if !row.allAgree {
                write("    → disagreement")
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

// MARK: - API key resolution (tests + CLI)

extension EvaluationConfig {
    /// OpenAI key from `OPENAI_API_KEY` or app UserDefaults (`openai_api_key`).
    static func resolvedOpenAIAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"),
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        return nil
    }
}
