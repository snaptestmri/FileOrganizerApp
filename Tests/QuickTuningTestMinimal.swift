import Foundation
import XCTest
@testable import FileOrganizerApp

/// Quick tuning test to compare classifier configurations
final class QuickTuningTestMinimal: XCTestCase {
    
    // MARK: - Configuration
    
    /// Change this to your test folder path
    static let testFolder = "~/Downloads"
    
    /// Maximum number of files to test
    static let maxFiles = 5
    
    // MARK: - Tests
    
    func testMinimal() async throws {
        print("Test started")
        XCTAssertTrue(true)
    }
    
    func testQuickTuningSimple() async throws {
        print("🚀 Quick Classifier Tuning Test")
        print(String(repeating: "=", count: 60))
        
        // Check if Ollama is available (simplified check)
        let ollamaAvailable = await checkOllamaAvailableSimple()
        guard ollamaAvailable else {
            throw XCTSkip("Ollama is not available. Please start Ollama with 'ollama serve' and ensure a model is downloaded.")
        }
        
        // Expand folder path
        let folderPath = (Self.testFolder as NSString).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: folderPath)
        
        // Check if folder exists
        guard FileManager.default.fileExists(atPath: folderPath) else {
            throw XCTSkip("Test folder does not exist: \(folderPath). Please update testFolder in the test file.")
        }
        
        // Get files from folder
        let files = try getFiles(from: folderURL, maxFiles: Self.maxFiles)
        guard !files.isEmpty else {
            throw XCTSkip("No files found in test folder: \(folderPath)")
        }
        
        print("📁 Testing with \(files.count) files from: \(folderPath)")
        print(String(repeating: "-", count: 60))
        
        // Test only one configuration first to avoid memory issues
        print("\n🧪 Testing: Default Configuration")
        print(String(repeating: "-", count: 40))
        
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
        
        if successCount > 0 {
            let avgConfidence = totalConfidence / Double(successCount)
            let avgTime = totalTime / Double(successCount)
            
            print("\n   Average Confidence: \(String(format: "%.2f%%", avgConfidence * 100))")
            print("   Average Time: \(String(format: "%.0f", avgTime * 1000))ms")
            print("   Files Processed: \(successCount)")
        }
        
        print(String(repeating: "=", count: 60))
    }
    
    // MARK: - Helper Methods
    
    private func checkOllamaAvailableSimple() async -> Bool {
        // Use async URLSession to avoid semaphore issues in async context
        guard let url = URL(string: "http://localhost:11434/api/tags") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        
        return false
    }
    
    private func getFiles(from folderURL: URL, maxFiles: Int) throws -> [URL] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        var files: [URL] = []
        for item in contents {
            let resourceValues = try? item.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                files.append(item)
                if files.count >= maxFiles {
                    break
                }
            }
        }
        
        return files
    }
}

