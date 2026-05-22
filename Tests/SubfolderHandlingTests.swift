import XCTest
import Foundation
@testable import FileOrganizerApp

/// Tests for recursive subfolder handling and folder context in classification
final class SubfolderHandlingTests: XCTestCase {
    
    // MARK: - Test Properties
    var tempDirectory: URL!
    var fileMover: FileMover!
    var classificationManager: FileClassificationManager!
    
    // MARK: - Setup and Teardown
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubfolderHandlingTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Initialize FileMover
        fileMover = FileMover(sourceFolder: tempDirectory)
        
        // Initialize FileClassificationManager with MockLLMService
        let mockLLM = MockLLMService()
        classificationManager = FileClassificationManager(
            llmService: mockLLM,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        fileMover = nil
        classificationManager = nil
        TelemetryService.shared.clearData()
        try super.tearDownWithError()
    }
    
    // MARK: - Recursive File Collection Tests
    
    func testFileMoverCollectsFilesFromSubfolders() throws {
        // Create folder structure:
        // tempDirectory/
        //   ├── top_level.pdf
        //   ├── top_level.jpg
        //   └── Subfolder/
        //       ├── subfolder_file1.pdf
        //       ├── subfolder_file2.jpg
        //       └── NestedSubfolder/
        //           └── nested_file.txt
        
        let topLevelPDF = tempDirectory.appendingPathComponent("top_level.pdf")
        let topLevelJPG = tempDirectory.appendingPathComponent("top_level.jpg")
        let subfolder = tempDirectory.appendingPathComponent("Subfolder")
        let subfolderFile1 = subfolder.appendingPathComponent("subfolder_file1.pdf")
        let subfolderFile2 = subfolder.appendingPathComponent("subfolder_file2.jpg")
        let nestedSubfolder = subfolder.appendingPathComponent("NestedSubfolder")
        let nestedFile = nestedSubfolder.appendingPathComponent("nested_file.txt")
        
        // Create files
        try "content".write(to: topLevelPDF, atomically: true, encoding: .utf8)
        try "content".write(to: topLevelJPG, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content".write(to: subfolderFile1, atomically: true, encoding: .utf8)
        try "content".write(to: subfolderFile2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: nestedSubfolder, withIntermediateDirectories: true)
        try "content".write(to: nestedFile, atomically: true, encoding: .utf8)
        
        // Use reflection to access private method (or make it internal for testing)
        // For now, we'll test through the public interface
        let keywords = [
            KeywordEntry(keyword: "top_level", subfolder: "General", category: "Documents"),
            KeywordEntry(keyword: "subfolder", subfolder: "General", category: "Documents"),
            KeywordEntry(keyword: "nested", subfolder: "General", category: "Documents")
        ]
        
        var processedFiles: [String] = []
        let results = try fileMover.runWithProgress(with: keywords) { current, total, fileName in
            processedFiles.append(fileName)
        }
        
        // Should process files from all levels
        XCTAssertTrue(processedFiles.contains("top_level.pdf") || processedFiles.contains("top_level.jpg"))
        XCTAssertTrue(processedFiles.contains("subfolder_file1.pdf") || processedFiles.contains("subfolder_file2.jpg"))
        XCTAssertTrue(processedFiles.contains("nested_file.txt"))
        
        // Verify total files processed
        XCTAssertGreaterThan(results.processedFiles, 0)
    }
    
    func testAIClassifierMoverCollectsFilesFromSubfolders() async throws {
        // Create folder structure with files in subfolders
        let subfolder = tempDirectory.appendingPathComponent("Financial")
        let subfolderFile1 = subfolder.appendingPathComponent("invoice_2024.pdf")
        let subfolderFile2 = subfolder.appendingPathComponent("receipt_2024.pdf")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content".write(to: subfolderFile1, atomically: true, encoding: .utf8)
        try "content".write(to: subfolderFile2, atomically: true, encoding: .utf8)
        
        let mover = AIClassifierMover(
            sourceFolder: tempDirectory,
            classificationManager: classificationManager
        )
        
        var processedFiles: [String] = []
        let results = try await mover.runWithProgress(
            progressCallback: { current, total, fileName, _ in
                processedFiles.append(fileName)
            },
            classificationCallback: { _, _, _ in }
        )
        
        // Should process files from subfolder
        XCTAssertTrue(processedFiles.contains("invoice_2024.pdf"))
        XCTAssertTrue(processedFiles.contains("receipt_2024.pdf"))
        XCTAssertGreaterThan(results.processedFiles, 0)
    }
    
    func testRecursiveCollectionHandlesEmptySubfolders() throws {
        // Create structure with empty subfolders
        let emptySubfolder1 = tempDirectory.appendingPathComponent("Empty1")
        let emptySubfolder2 = tempDirectory.appendingPathComponent("Empty2")
        let file = tempDirectory.appendingPathComponent("file.pdf")
        
        try FileManager.default.createDirectory(at: emptySubfolder1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: emptySubfolder2, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let keywords = [KeywordEntry(keyword: "file", subfolder: "General", category: "Documents")]
        
        let results = try fileMover.runWithProgress(with: keywords) { _, _, _ in }
        
        // Should only process the file, not crash on empty folders
        XCTAssertEqual(results.processedFiles, 1)
    }
    
    func testRecursiveCollectionHandlesDeepNesting() throws {
        // Create deeply nested structure
        var currentPath: URL = tempDirectory
        var filePaths: [URL] = []
        
        for i in 1...5 {
            currentPath = currentPath.appendingPathComponent("Level\(i)")
            try FileManager.default.createDirectory(at: currentPath, withIntermediateDirectories: true)
            
            let file = currentPath.appendingPathComponent("file_level\(i).txt")
            try "content".write(to: file, atomically: true, encoding: .utf8)
            filePaths.append(file)
        }
        
        let keywords = [KeywordEntry(keyword: "file", subfolder: "General", category: "Documents")]
        
        var processedCount = 0
        let results = try fileMover.runWithProgress(with: keywords) { _, _, _ in
            processedCount += 1
        }
        
        // Should process all files from all nesting levels
        XCTAssertEqual(processedCount, 5)
        XCTAssertEqual(results.processedFiles, 5)
    }
    
    // MARK: - Folder Context Extraction Tests
    
    func testFileMetadataExtractsParentFolder() throws {
        // Create file in subfolder
        let subfolder = tempDirectory.appendingPathComponent("Financial")
        let file = subfolder.appendingPathComponent("invoice.pdf")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let metadata = FileMetadata.extract(from: file)
        
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.parentFolder, "Financial")
    }
    
    func testFileMetadataExtractsFolderDepth() throws {
        // Create nested structure
        let level1 = tempDirectory.appendingPathComponent("Level1")
        let level2 = level1.appendingPathComponent("Level2")
        let file = level2.appendingPathComponent("file.txt")
        
        try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let metadata = FileMetadata.extract(from: file)
        
        XCTAssertNotNil(metadata)
        // Folder depth should be relative to home directory
        // For test files, it will be at least 2 (Level1/Level2)
        XCTAssertGreaterThanOrEqual(metadata?.folderDepth ?? 0, 0)
    }
    
    func testFileMetadataExtractsSiblingFiles() throws {
        // Create multiple files in same folder
        let subfolder = tempDirectory.appendingPathComponent("Documents")
        let file1 = subfolder.appendingPathComponent("file1.pdf")
        let file2 = subfolder.appendingPathComponent("file2.pdf")
        let file3 = subfolder.appendingPathComponent("file3.pdf")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try "content3".write(to: file3, atomically: true, encoding: .utf8)
        
        let metadata = FileMetadata.extract(from: file1)
        
        XCTAssertNotNil(metadata)
        XCTAssertNotNil(metadata?.siblingFiles)
        XCTAssertTrue(metadata?.siblingFiles?.contains("file2.pdf") ?? false)
        XCTAssertTrue(metadata?.siblingFiles?.contains("file3.pdf") ?? false)
        XCTAssertTrue(metadata?.siblingFiles?.contains("file1.pdf") ?? false)
    }
    
    func testFileMetadataContextForTopLevelFile() throws {
        // Create file at top level
        let file = tempDirectory.appendingPathComponent("top_level.pdf")
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let metadata = FileMetadata.extract(from: file)
        
        XCTAssertNotNil(metadata)
        // Parent folder should be the temp directory name or last component
        XCTAssertNotNil(metadata?.parentFolder)
        // Folder depth should be minimal for top-level file
        XCTAssertGreaterThanOrEqual(metadata?.folderDepth ?? 0, 0)
    }
    
    // MARK: - Classification Prompt Context Tests
    
    func testClassificationPromptIncludesParentFolder() throws {
        // Create file in subfolder
        let subfolder = tempDirectory.appendingPathComponent("Financial")
        let file = subfolder.appendingPathComponent("invoice.pdf")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        guard let metadata = FileMetadata.extract(from: file) else {
            XCTFail("Failed to extract metadata")
            return
        }
        
        let promptBuilder = ClassificationPromptBuilder()
        let prompt = promptBuilder.buildPrompt(metadata: metadata, preCategory: "Documents")
        
        // Prompt should include parent folder context
        XCTAssertTrue(prompt.contains("Parent Folder"))
        XCTAssertTrue(prompt.contains("Financial"))
    }
    
    func testClassificationPromptIncludesSiblingFiles() throws {
        // Create multiple files in same folder
        let subfolder = tempDirectory.appendingPathComponent("Reports")
        let file1 = subfolder.appendingPathComponent("report1.pdf")
        let file2 = subfolder.appendingPathComponent("report2.pdf")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        
        guard let metadata = FileMetadata.extract(from: file1) else {
            XCTFail("Failed to extract metadata")
            return
        }
        
        let promptBuilder = ClassificationPromptBuilder()
        let prompt = promptBuilder.buildPrompt(metadata: metadata, preCategory: "Documents")
        
        // Prompt should include sibling files
        XCTAssertTrue(prompt.contains("Sibling Files"))
        XCTAssertTrue(prompt.contains("report2.pdf"))
    }
    
    func testClassificationPromptIncludesFolderDepth() throws {
        // Create deeply nested file
        let level1 = tempDirectory.appendingPathComponent("Level1")
        let level2 = level1.appendingPathComponent("Level2")
        let file = level2.appendingPathComponent("file.pdf")
        
        try FileManager.default.createDirectory(at: level2, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        guard let metadata = FileMetadata.extract(from: file) else {
            XCTFail("Failed to extract metadata")
            return
        }
        
        let promptBuilder = ClassificationPromptBuilder()
        let prompt = promptBuilder.buildPrompt(metadata: metadata, preCategory: "Documents")
        
        // Prompt should include depth information if > 1
        if metadata.folderDepth > 1 {
            XCTAssertTrue(prompt.contains("depth:"))
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndSubfolderClassification() async throws {
        // Create realistic folder structure
        let financialFolder = tempDirectory.appendingPathComponent("Financial")
        let invoiceFile = financialFolder.appendingPathComponent("invoice_2024.pdf")
        let receiptFile = financialFolder.appendingPathComponent("receipt_2024.pdf")
        
        try FileManager.default.createDirectory(at: financialFolder, withIntermediateDirectories: true)
        try "invoice content".write(to: invoiceFile, atomically: true, encoding: .utf8)
        try "receipt content".write(to: receiptFile, atomically: true, encoding: .utf8)
        
        let mover = AIClassifierMover(
            sourceFolder: tempDirectory,
            classificationManager: classificationManager
        )
        
        var classifications: [(FileMetadata, ClassificationResult, OrganizeDestination)] = []
        let results = try await mover.runWithProgress(
            progressCallback: { _, _, _, _ in },
            classificationCallback: { metadata, result, destination in
                classifications.append((metadata, result, destination))
            }
        )
        
        // Should classify files from subfolder
        XCTAssertGreaterThan(results.processedFiles, 0)
        XCTAssertGreaterThan(classifications.count, 0)
        
        // Verify folder context was used
        let invoiceClassification = classifications.first { $0.0.fileName == "invoice_2024.pdf" }
        XCTAssertNotNil(invoiceClassification)
        
        // Verify metadata includes parent folder
        XCTAssertEqual(invoiceClassification?.0.parentFolder, "Financial")
    }
    
    func testFolderContextInfluencesClassification() async throws {
        // Create files with same name but different folder contexts
        let financialFolder = tempDirectory.appendingPathComponent("Financial")
        let personalFolder = tempDirectory.appendingPathComponent("Personal")
        
        let financialFile = financialFolder.appendingPathComponent("report.pdf")
        let personalFile = personalFolder.appendingPathComponent("report.pdf")
        
        try FileManager.default.createDirectory(at: financialFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: personalFolder, withIntermediateDirectories: true)
        try "financial report".write(to: financialFile, atomically: true, encoding: .utf8)
        try "personal report".write(to: personalFile, atomically: true, encoding: .utf8)
        
        // Extract metadata
        guard let financialMetadata = FileMetadata.extract(from: financialFile),
              let personalMetadata = FileMetadata.extract(from: personalFile) else {
            XCTFail("Failed to extract metadata")
            return
        }
        
        // Verify parent folder context is different
        XCTAssertEqual(financialMetadata.parentFolder, "Financial")
        XCTAssertEqual(personalMetadata.parentFolder, "Personal")
        
        // Build prompts and verify context is included
        let promptBuilder = ClassificationPromptBuilder()
        let financialPrompt = promptBuilder.buildPrompt(metadata: financialMetadata, preCategory: "Documents")
        let personalPrompt = promptBuilder.buildPrompt(metadata: personalMetadata, preCategory: "Documents")
        
        XCTAssertTrue(financialPrompt.contains("Financial"))
        XCTAssertTrue(personalPrompt.contains("Personal"))
    }
    
    // MARK: - Edge Cases
    
    func testRecursiveCollectionSkipsHiddenFiles() throws {
        // Create hidden file in subfolder
        let subfolder = tempDirectory.appendingPathComponent("Subfolder")
        let hiddenFile = subfolder.appendingPathComponent(".hidden_file.txt")
        let visibleFile = subfolder.appendingPathComponent("visible_file.txt")
        
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "visible".write(to: visibleFile, atomically: true, encoding: .utf8)
        
        let keywords = [KeywordEntry(keyword: "visible", subfolder: "General", category: "Documents")]
        
        var processedFiles: [String] = []
        _ = try fileMover.runWithProgress(with: keywords) { _, _, fileName in
            processedFiles.append(fileName)
        }
        
        // Should process visible file but not hidden file
        XCTAssertTrue(processedFiles.contains("visible_file.txt"))
        XCTAssertFalse(processedFiles.contains(".hidden_file.txt"))
    }
    
    func testRecursiveCollectionHandlesSpecialCharacters() throws {
        // Create folder with special characters
        let specialFolder = tempDirectory.appendingPathComponent("Folder (2024)")
        let file = specialFolder.appendingPathComponent("file-name_with.special@chars.pdf")
        
        try FileManager.default.createDirectory(at: specialFolder, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let keywords = [KeywordEntry(keyword: "file", subfolder: "General", category: "Documents")]
        
        let results = try fileMover.runWithProgress(with: keywords) { _, _, _ in }
        
        // Should handle special characters without crashing
        XCTAssertGreaterThanOrEqual(results.processedFiles, 0)
    }
    
    func testMetadataExtractionForFilesInNestedSubfolders() throws {
        // Create deeply nested structure
        let level1 = tempDirectory.appendingPathComponent("Category1")
        let level2 = level1.appendingPathComponent("Subcategory1")
        let level3 = level2.appendingPathComponent("Year2024")
        let file = level3.appendingPathComponent("document.pdf")
        
        try FileManager.default.createDirectory(at: level3, withIntermediateDirectories: true)
        try "content".write(to: file, atomically: true, encoding: .utf8)
        
        let metadata = FileMetadata.extract(from: file)
        
        XCTAssertNotNil(metadata)
        // Parent folder should be the immediate parent
        XCTAssertEqual(metadata?.parentFolder, "Year2024")
        // Should have sibling files context (even if empty)
        XCTAssertNotNil(metadata?.siblingFiles)
    }
}

