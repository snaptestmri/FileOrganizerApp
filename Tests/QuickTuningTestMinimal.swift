import Foundation
import XCTest
@testable import FileOrganizerApp

/// Quick tuning test — classifies real files via Ollama.
///
/// Configure the folder (first match wins):
///   1. Environment: `QUICK_TUNING_FOLDER=/path/to/folder swift test --filter QuickTuningTestMinimal.testQuickTuningSimple`
///   2. Edit `testFolder` below (supports `~`); subfolders are scanned recursively.
///
/// If the folder has no files, built-in sample files are created in a temp directory so the test still runs.
final class QuickTuningTestMinimal: XCTestCase {

    /// Default folder when `QUICK_TUNING_FOLDER` is not set.
    static let testFolder = "~/Downloads"

    static let maxFiles = 5

    private var tempFixtureDirectory: URL?

    override func tearDownWithError() throws {
        if let tempFixtureDirectory {
            try? FileManager.default.removeItem(at: tempFixtureDirectory)
        }
        tempFixtureDirectory = nil
        try super.tearDownWithError()
    }

    func testMinimal() async throws {
        XCTAssertTrue(true)
    }

    func testQuickTuningSimple() async throws {
        print("🚀 Quick Classifier Tuning Test")
        print(String(repeating: "=", count: 60))

        guard await checkOllamaAvailableSimple() else {
            throw XCTSkip("Ollama is not available. Run: ollama serve && ollama pull llama3.2:3b")
        }

        let folderPath = resolvedTestFolderPath()
        let folderURL = URL(fileURLWithPath: folderPath)

        guard FileManager.default.fileExists(atPath: folderPath) else {
            throw XCTSkip("Test folder does not exist: \(folderPath). Set QUICK_TUNING_FOLDER or edit testFolder.")
        }

        var files = try collectFiles(from: folderURL, maxFiles: Self.maxFiles)
        var sourceDescription = folderPath

        if files.isEmpty {
            print("⚠️ No files in \(folderPath) (including subfolders). Using built-in sample files.")
            files = try createSampleFixtures(maxFiles: Self.maxFiles)
            sourceDescription = tempFixtureDirectory?.path ?? "temp fixtures"
        }

        print("📁 Testing with \(files.count) file(s) from: \(sourceDescription)")
        print(String(repeating: "-", count: 60))

        let llmService = OllamaLLMService(model: "llama3.2:3b", temperature: 0.1)
        let promptBuilder = ClassificationPromptBuilder()
        let manager = FileClassificationManager(
            llmService: llmService,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: promptBuilder
        )

        var totalConfidence: Double = 0
        var totalTime: TimeInterval = 0
        var successCount = 0

        for fileURL in files {
            guard let metadata = FileMetadata.extract(from: fileURL, includePreview: true, maxPreviewLength: 500) else {
                print("   ⚠️ Skipped (could not read metadata): \(fileURL.lastPathComponent)")
                continue
            }

            let startTime = Date()
            let result = await manager.classifyFile(metadata)
            let duration = Date().timeIntervalSince(startTime)

            totalConfidence += result.confidence
            totalTime += duration
            successCount += 1

            print("   \(metadata.fileName)")
            print("      → \(result.category)/\(result.subfolder)")
            print("      Method: \(result.method.rawValue)")
            print("      Confidence: \(String(format: "%.2f", result.confidence))")
            print("      Time: \(String(format: "%.0f", duration * 1000))ms")
            if let reasoning = result.reasoning {
                print("      Reasoning: \(reasoning)")
            }
        }

        XCTAssertGreaterThan(successCount, 0, "No files could be classified")

        let avgConfidence = totalConfidence / Double(successCount)
        let avgTime = totalTime / Double(successCount)

        print("\n   Average Confidence: \(String(format: "%.2f%%", avgConfidence * 100))")
        print("   Average Time: \(String(format: "%.0f", avgTime * 1000))ms")
        print("   Files Processed: \(successCount)")
        print(String(repeating: "=", count: 60))
    }

    // MARK: - Configuration

    private func resolvedTestFolderPath() -> String {
        if let env = ProcessInfo.processInfo.environment["QUICK_TUNING_FOLDER"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (env as NSString).expandingTildeInPath
        }
        return (Self.testFolder as NSString).expandingTildeInPath
    }

    // MARK: - File discovery

    /// Collect regular files under `folderURL`, including subfolders (depth-first).
    private func collectFiles(from folderURL: URL, maxFiles: Int) throws -> [URL] {
        let fileManager = FileManager.default
        var found: [URL] = []

        func scan(_ url: URL) throws {
            guard found.count < maxFiles else { return }

            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard found.count < maxFiles else { return }
                let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                if values?.isRegularFile == true {
                    found.append(item)
                } else if values?.isDirectory == true {
                    try scan(item)
                }
            }
        }

        try scan(folderURL)
        return found
    }

    /// Sample files for when Downloads (or your folder) is empty.
    private func createSampleFixtures(maxFiles: Int) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickTuningFixtures")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempFixtureDirectory = dir

        let samples: [(String, String)] = [
            ("visa_application.pdf", "Consulate appointment confirmation for B-1 visa."),
            ("invoice_acme_2024.pdf", "Invoice #4421 — Amount due $1,250.00"),
            ("IMG_vacation.jpg", "Family vacation photo export"),
            ("resume_mrinal.docx", "Curriculum vitae — work history and skills"),
            ("Taxes2025.pdf", "Form 1099-INT interest income statement")
        ]

        var urls: [URL] = []
        for (name, content) in samples.prefix(maxFiles) {
            let url = dir.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        return urls
    }

    private func checkOllamaAvailableSimple() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
