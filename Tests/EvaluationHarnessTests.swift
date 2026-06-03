import Foundation
import XCTest
@testable import FileOrganizerApp

/// Phase 0: shared evaluation harness (no Ollama required).
final class EvaluationHarnessTests: XCTestCase {

    private var harness = ClassificationEvaluationHarness()
    private var cleanupDirectory: URL?

    override func tearDownWithError() throws {
        if let cleanupDirectory {
            try? FileManager.default.removeItem(at: cleanupDirectory)
        }
        cleanupDirectory = nil
        try super.tearDownWithError()
    }

    // MARK: - Config

    func testEvaluationConfigFromEnvironment() {
        setenv("EVAL_FOLDER", "~/Documents", 1)
        setenv("EVAL_MAX_FILES", "12", 1)
        setenv("EVAL_MODEL", "mistral:7b", 1)
        setenv("EVAL_TEMPERATURE", "0.15", 1)
        setenv("EVAL_USE_EXAMPLES", "true", 1)
        setenv("EVAL_PROMPT_VARIANT", "concise", 1)
        setenv("EVAL_RUN_LABEL", "env-test", 1)
        defer {
            unsetenv("EVAL_FOLDER")
            unsetenv("EVAL_MAX_FILES")
            unsetenv("EVAL_MODEL")
            unsetenv("EVAL_TEMPERATURE")
            unsetenv("EVAL_USE_EXAMPLES")
            unsetenv("EVAL_PROMPT_VARIANT")
            unsetenv("EVAL_RUN_LABEL")
        }

        let config = EvaluationConfig.fromEnvironment()
        XCTAssertEqual(config.folderPath, ( "~/Documents" as NSString).expandingTildeInPath)
        XCTAssertEqual(config.maxFiles, 12)
        XCTAssertEqual(config.model, "mistral:7b")
        XCTAssertEqual(config.temperature, 0.15, accuracy: 0.001)
        XCTAssertTrue(config.useExamples)
        XCTAssertEqual(config.promptVariant, .concise)
        XCTAssertEqual(config.runLabel, "env-test")
    }

    func testEvaluationConfigMakeManagerAppliesPromptSettings() {
        var config = EvaluationConfig()
        config.useExamples = false
        config.promptVariant = .detailed

        let manager = config.makeClassificationManager(llmService: MockLLMService.fast())
        XCTAssertFalse(manager.useExamples)
    }

    // MARK: - Discovery

    func testDiscoverFilesCreatesSampleFixturesWhenNoFolder() throws {
        var config = EvaluationConfig()
        config.folderPath = nil
        config.maxFiles = 3
        config.useSampleFixturesWhenEmpty = true

        let fileSet = try harness.discoverFiles(config: config)
        cleanupDirectory = fileSet.cleanupDirectory

        XCTAssertEqual(fileSet.urls.count, 3)
        XCTAssertNotNil(fileSet.cleanupDirectory)
        XCTAssertTrue(fileSet.sourceDescription.contains("sample") || fileSet.cleanupDirectory != nil)
    }

    func testDiscoverFilesFromTemporaryFolder() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalHarness-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cleanupDirectory = dir

        try "invoice data".write(to: dir.appendingPathComponent("bill.pdf"), atomically: true, encoding: .utf8)
        try "photo".write(to: dir.appendingPathComponent("pic.jpg"), atomically: true, encoding: .utf8)

        var config = EvaluationConfig()
        config.folderPath = dir.path
        config.maxFiles = 10

        let fileSet = try harness.discoverFiles(config: config)
        XCTAssertEqual(fileSet.urls.count, 2)
        XCTAssertNil(fileSet.cleanupDirectory)
        XCTAssertEqual(fileSet.sourceDescription, dir.path)
    }

    // MARK: - Evaluate

    func testEvaluateWithMockLLM() async throws {
        let dir = try makeSingleFileFixture(name: "invoice_acme_2024.pdf", content: "Invoice #4421")
        cleanupDirectory = dir

        var config = EvaluationConfig()
        config.folderPath = dir.path
        config.maxFiles = 1
        config.runLabel = "mock"
        config.useSampleFixturesWhenEmpty = false

        let fileSet = try harness.discoverFiles(config: config)
        let mock = MockLLMService.fast()
        mock.mockResponse = """
        {"category": "Documents", "subfolder": "Invoices", "confidence": 0.92, "reasoning": "test", "method": "llm"}
        """

        let report = await harness.evaluate(fileSet: fileSet, config: config, llmService: mock)

        XCTAssertEqual(report.runLabel, "mock")
        XCTAssertEqual(report.fileCount, 1)
        XCTAssertEqual(report.successCount, 1)
        XCTAssertGreaterThan(report.averageConfidence, 0)
        XCTAssertGreaterThan(report.averageDurationMs, 0)
        XCTAssertEqual(report.fallbackCount, 0)

        let row = try XCTUnwrap(report.rows.first)
        XCTAssertEqual(row.fileName, "invoice_acme_2024.pdf")
        XCTAssertEqual(row.method, .llm)
        XCTAssertEqual(row.confidence, 0.92, accuracy: 0.01)
        XCTAssertFalse(row.category.isEmpty)
        XCTAssertFalse(row.subfolder.isEmpty)
        // Life-domain normalization may adjust LLM category/subfolder (e.g. Documents → Personal).
    }

    func testEvaluateFallbackOnly() async throws {
        var config = EvaluationConfig()
        config.maxFiles = 2
        config.runLabel = "fallback-only"
        config.folderPath = nil

        let fileSet = try harness.discoverFiles(config: config)
        cleanupDirectory = fileSet.cleanupDirectory

        let report = await harness.evaluateFallbackOnly(fileSet: fileSet, config: config)

        XCTAssertEqual(report.runLabel, "fallback-only")
        XCTAssertGreaterThan(report.fileCount, 0)
        XCTAssertEqual(report.fallbackCount, report.fileCount)
        XCTAssertEqual(report.fallbackRate, 1.0, accuracy: 0.001)
    }

    func testEvaluateDiscoveredFilesEndToEnd() async throws {
        var config = EvaluationConfig()
        config.maxFiles = 2
        config.runLabel = "e2e-mock"
        config.folderPath = nil

        let (report, fileSet) = try await harness.evaluateDiscoveredFiles(
            config: config,
            llmService: MockLLMService.fast()
        )
        cleanupDirectory = fileSet.cleanupDirectory

        XCTAssertGreaterThan(report.fileCount, 0)
        XCTAssertFalse(report.sourceDescription.isEmpty)
    }

    // MARK: - Export

    func testExportJSONAndCSV() async throws {
        var config = EvaluationConfig()
        config.maxFiles = 2
        config.runLabel = "export-test"
        config.folderPath = nil

        let fileSet = try harness.discoverFiles(config: config)
        cleanupDirectory = fileSet.cleanupDirectory

        let report = await harness.evaluate(
            fileSet: fileSet,
            config: config,
            llmService: MockLLMService.fast()
        )

        let json = try XCTUnwrap(report.exportJSON())
        XCTAssertGreaterThan(json.count, 50)

        let decoded = try EvaluationReport.decodeJSON(json)
        XCTAssertEqual(decoded.runLabel, report.runLabel)
        XCTAssertEqual(decoded.rows.count, report.rows.count)

        let csv = report.exportCSV()
        XCTAssertTrue(csv.hasPrefix("fileName,filePath,runLabel"))
        XCTAssertTrue(csv.contains("export-test"))
        XCTAssertEqual(csv.filter { $0 == "\n" }.count, report.rows.count + 1)
    }

    func testPrintReportDoesNotCrash() async throws {
        var config = EvaluationConfig()
        config.maxFiles = 1
        config.folderPath = nil

        let fileSet = try harness.discoverFiles(config: config)
        cleanupDirectory = fileSet.cleanupDirectory

        let report = await harness.evaluate(
            fileSet: fileSet,
            config: config,
            llmService: MockLLMService.fast()
        )

        var lines: [String] = []
        report.printReport { lines.append($0) }
        XCTAssertTrue(lines.contains { $0.contains("Classification Evaluation Report") })
        XCTAssertTrue(lines.contains { $0.contains("Per file:") })
    }

    func testExpectedLabelAttachedToRow() async throws {
        let dir = try makeSingleFileFixture(name: "invoice_acme_2024.pdf", content: "Invoice")
        cleanupDirectory = dir

        var config = EvaluationConfig()
        config.folderPath = dir.path
        config.maxFiles = 1
        config.useSampleFixturesWhenEmpty = false

        let fileSet = try harness.discoverFiles(config: config)
        let expected: [String: ExpectedLabel] = [
            "invoice_acme_2024.pdf": ExpectedLabel(
                expectedCategory: "Documents",
                expectedSubfolder: "Invoices"
            )
        ]

        let report = await harness.evaluate(
            fileSet: fileSet,
            config: config,
            llmService: MockLLMService.fast(),
            expectedByFileName: expected
        )

        let row = try XCTUnwrap(report.rows.first)
        XCTAssertEqual(row.expected?.expectedCategory, "Documents")
        XCTAssertEqual(row.expected?.expectedSubfolder, "Invoices")
    }

    func testOllamaAvailabilityDoesNotRequireServer() async {
        // Smoke test: call completes (may be true or false depending on machine).
        _ = await ClassificationEvaluationHarness.isOllamaAvailable()
    }

    // MARK: - Helpers

    private func makeSingleFileFixture(name: String, content: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EvalHarness-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        return dir
    }
}
