import Foundation
import XCTest
@testable import FileOrganizerApp

/// Phase 1: compare classifiers side-by-side on the same files.
final class ClassifierComparisonTests: XCTestCase {

    private var harness = ClassificationEvaluationHarness()
    private var cleanupDirectory: URL?

    override func tearDownWithError() throws {
        if let cleanupDirectory {
            try? FileManager.default.removeItem(at: cleanupDirectory)
        }
        cleanupDirectory = nil
        try super.tearDownWithError()
    }

    // MARK: - Core comparison

    func testCompareFallbackOnFixtures() async throws {
        let dir = try makeFixtureFolder(files: [
            ("report.pdf", "Quarterly report summary"),
            ("photo.jpg", "binary placeholder")
        ])
        cleanupDirectory = dir

        setenv("EVAL_FOLDER", dir.path, 1)
        defer { unsetenv("EVAL_FOLDER") }

        let config = EvaluationConfig.forHarnessTests { $0.maxFiles = 10 }
        let (report, _) = try await harness.compareDiscoveredClassifiers(
            config: config,
            backends: [.fallback],
            includeOpenAI: false
        )

        XCTAssertEqual(report.backendsUsed, [.fallback])
        XCTAssertEqual(report.fileCount, 2)
        XCTAssertEqual(report.backendsSkipped, [])
        XCTAssertEqual(report.agreementCount, 2)

        for row in report.rows {
            XCTAssertNotNil(row.result(for: .fallback))
            XCTAssertNil(row.result(for: .fallback)?.error)
        }

        report.printReport()
        let csv = report.exportCSV()
        XCTAssertTrue(csv.contains("fileName,filePath"))
        XCTAssertTrue(csv.contains("fallback_category"))
        XCTAssertTrue(csv.contains("allAgree"))
    }

    func testCompareAll() async throws {
        let config = EvaluationConfig.forHarnessTests()
        let (report, fileSet) = try await harness.compareDiscoveredClassifiers(
            config: config,
            backends: [.fallback, .ollama, .openai],
            includeOpenAI: false
        )
        cleanupDirectory = fileSet.cleanupDirectory

        XCTAssertGreaterThan(report.fileCount, 0)
        XCTAssertTrue(report.backendsUsed.contains(.fallback))

        print("📊 Compare-all: \(report.agreementCount) agree, \(report.disagreementCount) disagree")
        report.printReport()

        let csv = report.exportCSV()
        XCTAssertGreaterThan(csv.split(separator: "\n").count, 1)
        XCTAssertFalse(csv.contains("mock_category"))

        let ollamaUp = await ClassificationEvaluationHarness.isOllamaAvailable()
        if ollamaUp {
            XCTAssertTrue(report.backendsUsed.contains(.ollama))
        } else {
            XCTAssertTrue(report.backendsSkipped.contains(.ollama))
        }
        XCTAssertTrue(report.backendsSkipped.contains(.openai))
    }

    func testCompareAllWithOpenAIWhenKeyConfigured() async throws {
        guard EvaluationConfig.resolvedOpenAIAPIKey() != nil else {
            throw XCTSkip("OPENAI_API_KEY or openai_api_key not configured")
        }

        let dir = try makeFixtureFolder(files: [("notes.txt", "Meeting notes from standup")])
        cleanupDirectory = dir

        setenv("EVAL_FOLDER", dir.path, 1)
        defer { unsetenv("EVAL_FOLDER") }

        let config = EvaluationConfig.forHarnessTests { $0.maxFiles = 1 }
        let (report, _) = try await harness.compareDiscoveredClassifiers(
            config: config,
            backends: [.fallback, .openai],
            includeOpenAI: true
        )

        XCTAssertTrue(report.backendsUsed.contains(.openai))
        XCTAssertEqual(report.fileCount, 1)
    }

    func testCompareWithOllamaWhenAvailable() async throws {
        guard await ClassificationEvaluationHarness.isOllamaAvailable() else {
            throw XCTSkip("Ollama not running — start with: ollama serve")
        }

        let config = EvaluationConfig.forHarnessTests { $0.maxFiles = 2 }
        let (report, fileSet) = try await harness.compareDiscoveredClassifiers(
            config: config,
            backends: [.fallback, .ollama],
            includeOpenAI: false
        )
        cleanupDirectory = fileSet.cleanupDirectory

        XCTAssertTrue(report.backendsUsed.contains(.ollama))
        XCTAssertGreaterThan(report.fileCount, 0)
        report.printReport()
    }

    // MARK: - Backend resolution

    func testResolveComparisonBackendsAlwaysIncludesFallback() async {
        let (used, skipped) = await harness.resolveComparisonBackends(
            requested: [.fallback, .ollama, .openai],
            includeOpenAI: false
        )
        XCTAssertTrue(used.contains(.fallback))
        let ollamaUp = await ClassificationEvaluationHarness.isOllamaAvailable()
        if ollamaUp {
            XCTAssertTrue(used.contains(.ollama))
        } else {
            XCTAssertTrue(skipped.contains(.ollama))
        }
        XCTAssertTrue(skipped.contains(.openai))
    }

    // MARK: - Agreement logic

    func testAgreementWhenDestinationsMatch() {
        let row = ClassifierComparisonRow(
            fileName: "a.pdf",
            filePath: "/tmp/a.pdf",
            results: [
                ClassifierRunResult(
                    backend: .ollama,
                    category: "Personal",
                    subfolder: "General",
                    confidence: 0.9,
                    method: .llm,
                    durationMs: 10,
                    reasoning: nil,
                    error: nil
                ),
                ClassifierRunResult(
                    backend: .fallback,
                    category: "Personal",
                    subfolder: "General",
                    confidence: 0.7,
                    method: .fallback,
                    durationMs: 1,
                    reasoning: nil,
                    error: nil
                )
            ]
        )
        XCTAssertTrue(row.allAgree)
    }

    func testDisagreementWhenDestinationsDiffer() {
        let row = ClassifierComparisonRow(
            fileName: "a.pdf",
            filePath: "/tmp/a.pdf",
            results: [
                ClassifierRunResult(
                    backend: .ollama,
                    category: "Media",
                    subfolder: "Photos",
                    confidence: 0.9,
                    method: .llm,
                    durationMs: 10,
                    reasoning: nil,
                    error: nil
                ),
                ClassifierRunResult(
                    backend: .fallback,
                    category: "Personal",
                    subfolder: "General",
                    confidence: 0.7,
                    method: .fallback,
                    durationMs: 1,
                    reasoning: nil,
                    error: nil
                )
            ]
        )
        XCTAssertFalse(row.allAgree)
    }

    // MARK: - Helpers

    private func makeFixtureFolder(files: [(String, String)]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClassifierCompare-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, content) in files {
            try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return dir
    }
}
