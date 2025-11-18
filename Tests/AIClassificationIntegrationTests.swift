import XCTest
import Foundation
@testable import FileOrganizerApp

/// Integration tests for AI Classification feature
/// These tests verify the complete workflow from file selection to classification
final class AIClassificationIntegrationTests: XCTestCase {
    
    var tempDirectory: URL!
    var testFiles: [URL] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIClassificationIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create a variety of test files
        testFiles = try createTestFiles()
    }
    
    override func tearDownWithError() throws {
        // Clean up
        for file in testFiles {
            try? FileManager.default.removeItem(at: file)
        }
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }
    
    // MARK: - Complete Workflow Tests
    
    func testEndToEndClassificationWorkflow() async throws {
        // 1. Extract metadata from all files
        var metadataList: [FileMetadata] = []
        for file in testFiles {
            if let metadata = FileMetadata.extract(from: file, includePreview: false) {
                metadataList.append(metadata)
            }
        }
        
        XCTAssertGreaterThan(metadataList.count, 0, "Should extract metadata from test files")
        
        // 2. Classify using FileClassificationManager with FallbackClassifier
        let mockLLM = MockLLMService()
        mockLLM.shouldFail = true // Force fallback
        
        let manager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        manager.useFallbackOnFailure = true
        
        var classifications: [ClassificationResult] = []
        for metadata in metadataList {
            let result = await manager.classifyFile(metadata)
            classifications.append(result)
        }
        
        XCTAssertEqual(classifications.count, metadataList.count, "Should classify all files")
        
        // 3. Verify classifications are reasonable
        for (index, classification) in classifications.enumerated() {
            let metadata = metadataList[index]
            
            // Verify category is not empty
            XCTAssertFalse(classification.category.isEmpty, "Category should not be empty for \(metadata.fileName)")
            
            // Verify subfolder is not empty
            XCTAssertFalse(classification.subfolder.isEmpty, "Subfolder should not be empty for \(metadata.fileName)")
            
            // Verify confidence is in valid range
            XCTAssertGreaterThanOrEqual(classification.confidence, 0.0, "Confidence should be >= 0")
            XCTAssertLessThanOrEqual(classification.confidence, 1.0, "Confidence should be <= 1")
        }
    }
    
    func testFileOrganizationWithAIClassifier() async throws {
        // Create organized structure
        let sourceFolder = tempDirectory.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        
        // Move test files to source
        for file in testFiles {
            let fileName = file.lastPathComponent
            let destination = sourceFolder.appendingPathComponent(fileName)
            try FileManager.default.moveItem(at: file, to: destination)
        }
        
        // Classify and organize using FileClassificationManager
        // Note: AIClassifierMover needs to be updated to use new architecture
        // For now, we'll test classification directly
        let mockLLM = MockLLMService()
        mockLLM.shouldFail = true
        
        let manager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        manager.useFallbackOnFailure = true
        
        // Classify files directly
        var classifications: [String: String] = [:]
        var movedCount = 0
        
        let files = try FileManager.default.contentsOfDirectory(
            at: sourceFolder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues?.isRegularFile == true
        }
        
        for file in files {
            if let metadata = FileMetadata.extract(from: file, includePreview: false) {
                let result = await manager.classifyFile(metadata)
                classifications[metadata.fileName] = "\(result.category)/\(result.subfolder)"
                movedCount += 1
            }
        }
        
        // Verify results
        XCTAssertGreaterThan(movedCount, 0)
        XCTAssertEqual(classifications.count, movedCount)
        
        // Verify files were organized into category/subfolder structure
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
        
        // Should have category folders
        let categoryFolders = contents.filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues?.isDirectory == true
        }
        
        XCTAssertGreaterThan(categoryFolders.count, 0, "Should create category folders")
    }
    
    // MARK: - Classifier Selection Tests
    
    func testFileClassificationManagerFallbackChain() async {
        let mockLLM = MockLLMService()
        mockLLM.shouldFail = true // Force fallback
        
        let manager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        manager.useFallbackOnFailure = true
        
        let metadata = FileMetadata(
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "test",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = await manager.classifyFile(metadata)
        
        // Should fallback to FallbackClassifier
        XCTAssertEqual(result.method, .fallback)
        XCTAssertEqual(result.category, "Documents")
    }
    
    func testFileClassificationManagerWithMultipleServices() async {
        // Test that manager can work with different LLM services
        let mockLLM = MockLLMService()
        mockLLM.mockResponse = """
        {"category": "Documents", "subfolder": "General", "confidence": 0.9, "reasoning": "test"}
        """
        
        let manager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        
        let metadata = FileMetadata(
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "test",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = await manager.classifyFile(metadata)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.category.isEmpty)
    }
    
    // MARK: - Batch Processing Tests
    
    func testLargeBatchProcessing() async throws {
        // Create many files
        let largeBatchFolder = tempDirectory.appendingPathComponent("large_batch")
        try FileManager.default.createDirectory(at: largeBatchFolder, withIntermediateDirectories: true)
        
        var metadataList: [FileMetadata] = []
        for i in 0..<50 {
            let file = largeBatchFolder.appendingPathComponent("file\(i).pdf")
            try "content \(i)".write(to: file, atomically: true, encoding: .utf8)
            
            if let metadata = FileMetadata.extract(from: file) {
                metadataList.append(metadata)
            }
        }
        
        let mockLLM = MockLLMService()
        mockLLM.shouldFail = true
        
        let manager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        manager.useFallbackOnFailure = true
        
        let startTime = Date()
        
        let results = await manager.classifyFiles(metadataList)
        
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, metadataList.count)
        XCTAssertLessThan(duration, 5.0, "Should process 50 files in under 5 seconds")
    }
    
    // MARK: - Error Recovery Tests
    
    func testClassificationWithMissingFiles() async throws {
        // Create metadata for non-existent file
        let fakeMetadata = FileMetadata(
            fileName: "nonexistent.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "nonexistent",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 0,
            fileSizeFormatted: "0 B",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let classifier = FallbackClassifier()
        
        // Should still classify (doesn't need file to exist)
        let result = classifier.classify(fakeMetadata)
        XCTAssertNotNil(result)
        XCTAssertFalse(result.category.isEmpty)
        XCTAssertEqual(result.method, .fallback)
    }
    
    // MARK: - Data Consistency Tests
    
    func testMetadataConsistency() throws {
        // Extract metadata multiple times from same file
        guard let firstFile = testFiles.first else {
            XCTFail("No test files available")
            return
        }
        
        let metadata1 = FileMetadata.extract(from: firstFile)
        let metadata2 = FileMetadata.extract(from: firstFile)
        
        XCTAssertNotNil(metadata1)
        XCTAssertNotNil(metadata2)
        
        // Core properties should be consistent
        XCTAssertEqual(metadata1?.fileName, metadata2?.fileName)
        XCTAssertEqual(metadata1?.fileExtension, metadata2?.fileExtension)
        XCTAssertEqual(metadata1?.fileSize, metadata2?.fileSize)
    }
    
    func testClassificationConsistency() async throws {
        // Classify same file multiple times
        guard let firstFile = testFiles.first,
              let metadata = FileMetadata.extract(from: firstFile) else {
            XCTFail("No test files available")
            return
        }
        
        let classifier = FallbackClassifier()
        
        let result1 = classifier.classify(metadata)
        let result2 = classifier.classify(metadata)
        
        // Fallback classifier should be deterministic
        XCTAssertEqual(result1.category, result2.category)
        XCTAssertEqual(result1.subfolder, result2.subfolder)
        XCTAssertEqual(result1.method, .fallback)
        XCTAssertEqual(result2.method, .fallback)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFiles() throws -> [URL] {
        let fileSpecs: [(String, String)] = [
            ("invoice_2024.pdf", "invoice content"),
            ("receipt_nov.pdf", "receipt content"),
            ("contract_agreement.pdf", "contract content"),
            ("report_q4.pdf", "report content"),
            ("vacation_photo.jpg", "photo content"),
            ("family_picture.jpg", "photo content"),
            ("screenshot.png", "screenshot content"),
            ("movie.mp4", "video content"),
            ("presentation.mp4", "video content"),
            ("song.mp3", "audio content"),
            ("code.swift", "swift code"),
            ("script.py", "python code"),
            ("archive.zip", "archive content"),
            ("backup.tar.gz", "backup content")
        ]
        
        var files: [URL] = []
        for (name, content) in fileSpecs {
            let file = tempDirectory.appendingPathComponent(name)
            try content.write(to: file, atomically: true, encoding: .utf8)
            files.append(file)
        }
        
        return files
    }
}

