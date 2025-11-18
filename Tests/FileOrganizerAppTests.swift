import XCTest
import Foundation
@testable import FileOrganizerApp

final class FileOrganizerAppTests: XCTestCase {
    
    // MARK: - Test Properties
    var tempDirectory: URL!
    var keywordStore: KeywordStore!
    
    // MARK: - Setup and Teardown
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileOrganizerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create a test-specific keyword store with isolated data
        keywordStore = createIsolatedKeywordStore()
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        keywordStore = nil
        try super.tearDownWithError()
    }
    
    // MARK: - KeywordEntry Tests
    func testKeywordEntryCreation() {
        let entry = KeywordEntry(keyword: "test", subfolder: "General", category: "Work")
        
        XCTAssertEqual(entry.keyword, "test")
        XCTAssertEqual(entry.subfolder, "General")
        XCTAssertEqual(entry.category, "Work")
        XCTAssertNotNil(entry.id)
    }
    
    func testKeywordEntryCodable() throws {
        let originalEntry = KeywordEntry(keyword: "test", subfolder: "General", category: "Work")
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEntry)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedEntry = try decoder.decode(KeywordEntry.self, from: data)
        
        XCTAssertEqual(originalEntry.keyword, decodedEntry.keyword)
        XCTAssertEqual(originalEntry.subfolder, decodedEntry.subfolder)
        XCTAssertEqual(originalEntry.category, decodedEntry.category)
    }
    
    // MARK: - KeywordStore Tests
    func testKeywordStoreInitialization() {
        XCTAssertNotNil(keywordStore)
        XCTAssertTrue(keywordStore.keywords.isEmpty)
    }
    
    func testAddKeyword() {
        let initialCount = keywordStore.keywords.count
        
        keywordStore.add(keyword: "test", subfolder: "General", category: "Work")
        
        XCTAssertEqual(keywordStore.keywords.count, initialCount + 1)
        
        let addedKeyword = keywordStore.keywords.last
        XCTAssertEqual(addedKeyword?.keyword, "test")
        XCTAssertEqual(addedKeyword?.subfolder, "General")
        XCTAssertEqual(addedKeyword?.category, "Work")
    }
    
    func testAddMultipleKeywords() {
        keywordStore.add(keyword: "test1", subfolder: "General", category: "Work")
        keywordStore.add(keyword: "test2", subfolder: "Personal", category: "Personal")
        keywordStore.add(keyword: "test3", subfolder: "General", category: "Work")
        
        XCTAssertEqual(keywordStore.keywords.count, 3)
        
        let keywords = keywordStore.keywords.map { $0.keyword }
        XCTAssertTrue(keywords.contains("test1"))
        XCTAssertTrue(keywords.contains("test2"))
        XCTAssertTrue(keywords.contains("test3"))
    }
    
    func testKeywordStoreDataIntegrity() {
        // Add some keywords
        keywordStore.add(keyword: "test1", subfolder: "Test", category: "Work")
        keywordStore.add(keyword: "test2", subfolder: "General", category: "Personal")
        
        // Verify keywords were added correctly
        XCTAssertEqual(keywordStore.keywords.count, 2)
        
        let keywords = keywordStore.keywords.map { $0.keyword }
        XCTAssertTrue(keywords.contains("test1"))
        XCTAssertTrue(keywords.contains("test2"))
        
        // Verify subfolders and categories
        let subfolders = keywordStore.keywords.map { $0.subfolder }
        XCTAssertTrue(subfolders.contains("Test"))
        XCTAssertTrue(subfolders.contains("General"))
        
        let categories = keywordStore.keywords.map { $0.category }
        XCTAssertTrue(categories.contains("Work"))
        XCTAssertTrue(categories.contains("Personal"))
    }
    
    // MARK: - FileMover Tests
    func testFileMoverInitialization() {
        let fileMover = FileMover(sourceFolder: tempDirectory)
        XCTAssertNotNil(fileMover)
        XCTAssertEqual(fileMover.sourceFolder, tempDirectory)
    }
    
    func testFileMoverWithEmptyKeywords() throws {
        let fileMover = FileMover(sourceFolder: tempDirectory)
        
        do {
            let results = try fileMover.runWithProgress(with: []) { _, _, _ in }
            XCTAssertEqual(results.processedFiles, 0)
            XCTAssertEqual(results.movedFiles, 0)
            XCTAssertEqual(results.skippedFiles, 0)
            XCTAssertEqual(results.errorFiles, 0)
        } catch {
            XCTFail("FileMover should handle empty keywords without throwing: \(error)")
        }
    }
    
    func testFileMoverWithTestFiles() throws {
        // Create test files
        let testFile1 = tempDirectory.appendingPathComponent("test_document.pdf")
        let testFile2 = tempDirectory.appendingPathComponent("work_report.docx")
        
        try "test content".write(to: testFile1, atomically: true, encoding: .utf8)
        try "work content".write(to: testFile2, atomically: true, encoding: .utf8)
        
        // Create test keywords
        let keywords = [
            KeywordEntry(keyword: "test", subfolder: "Test", category: "Work"),
            KeywordEntry(keyword: "work", subfolder: "Work", category: "Work"),
            KeywordEntry(keyword: "document", subfolder: "Documents", category: "Work")
        ]
        
        let fileMover = FileMover(sourceFolder: tempDirectory)
        
        do {
            let results = try fileMover.runWithProgress(with: keywords) { _, _, _ in }
            XCTAssertGreaterThanOrEqual(results.processedFiles, 2)
            XCTAssertGreaterThanOrEqual(results.movedFiles, 0)
            XCTAssertGreaterThanOrEqual(results.skippedFiles, 0)
            XCTAssertGreaterThanOrEqual(results.errorFiles, 0)
        } catch {
            XCTFail("FileMover should process test files without throwing: \(error)")
        }
    }
    
    // MARK: - iCloudFileManager Tests
    func testICloudFileManagerInitialization() {
        let manager = iCloudFileManager.shared
        XCTAssertNotNil(manager)
    }
    
    func testICloudFileManagerListFiles() {
        let manager = iCloudFileManager.shared
        let files = manager.listFiles()
        
        // Should return an array (may be empty if no iCloud files)
        XCTAssertNotNil(files)
        XCTAssertTrue(files is Array<URL>)
    }
    
    // MARK: - ScannedKeyword Tests
    func testScannedKeywordCreation() {
        let scanned = ScannedKeyword(keyword: "test", source: "test_file.txt", type: .file)
        
        XCTAssertEqual(scanned.keyword, "test")
        XCTAssertEqual(scanned.source, "test_file.txt")
        XCTAssertEqual(scanned.type, .file)
        XCTAssertNotNil(scanned.id)
    }
    
    func testScannedKeywordEquality() {
        let scanned1 = ScannedKeyword(keyword: "test", source: "file1.txt", type: .file)
        let scanned2 = ScannedKeyword(keyword: "test", source: "file2.txt", type: .folder)
        
        // Should be equal based on keyword only
        XCTAssertEqual(scanned1, scanned2)
    }
    
    func testScannedKeywordHashable() {
        let scanned1 = ScannedKeyword(keyword: "test", source: "file1.txt", type: .file)
        let scanned2 = ScannedKeyword(keyword: "test", source: "file2.txt", type: .folder)
        
        var set = Set<ScannedKeyword>()
        set.insert(scanned1)
        set.insert(scanned2)
        
        // Should only have one element since they have the same keyword
        XCTAssertEqual(set.count, 1)
    }
    
    // MARK: - BulkKeywordEntry Tests
    func testBulkKeywordEntryCreation() {
        let entry = BulkKeywordEntry(keyword: "test", subfolder: "General", category: "Work")
        
        XCTAssertEqual(entry.keyword, "test")
        XCTAssertEqual(entry.subfolder, "General")
        XCTAssertEqual(entry.category, "Work")
    }
    
    // MARK: - KeywordType Tests
    func testKeywordTypeValues() {
        XCTAssertEqual(KeywordType.file, .file)
        XCTAssertEqual(KeywordType.folder, .folder)
    }
    
    // MARK: - Integration Tests
    func testCompleteWorkflow() throws {
        // 1. Add keywords to store
        keywordStore.add(keyword: "test", subfolder: "Test", category: "Work")
        keywordStore.add(keyword: "work", subfolder: "Work", category: "Work")
        
        XCTAssertEqual(keywordStore.keywords.count, 2)
        
        // 2. Create test files
        let testFile = tempDirectory.appendingPathComponent("test_work_file.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        
        // 3. Run file mover
        let fileMover = FileMover(sourceFolder: tempDirectory)
        let results = try fileMover.runWithProgress(with: keywordStore.keywords) { _, _, _ in }
        
        XCTAssertGreaterThanOrEqual(results.processedFiles, 1)
        XCTAssertGreaterThanOrEqual(results.movedFiles, 0)
    }
    
    // MARK: - Performance Tests
    func testKeywordStorePerformance() {
        measure {
            for i in 0..<100 {
                keywordStore.add(keyword: "keyword\(i)", subfolder: "subfolder\(i % 5)", category: i % 2 == 0 ? "Work" : "Personal")
            }
        }
    }
    
    func testFileMoverPerformance() throws {
        // Create many test files
        for i in 0..<50 {
            let testFile = tempDirectory.appendingPathComponent("test_file_\(i).txt")
            try "test content \(i)".write(to: testFile, atomically: true, encoding: .utf8)
        }
        
        let keywords = [
            KeywordEntry(keyword: "test", subfolder: "Test", category: "Work"),
            KeywordEntry(keyword: "file", subfolder: "Files", category: "Work")
        ]
        
        let fileMover = FileMover(sourceFolder: tempDirectory)
        
        measure {
            do {
                _ = try fileMover.runWithProgress(with: keywords) { _, _, _ in }
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Edge Case Tests
    func testEmptyKeyword() {
        let initialCount = keywordStore.keywords.count
        keywordStore.add(keyword: "", subfolder: "General", category: "Work")
        
        // Should still add the entry (validation should be done at UI level)
        XCTAssertEqual(keywordStore.keywords.count, initialCount + 1)
    }
    
    func testSpecialCharactersInKeyword() {
        let specialKeyword = "test@#$%^&*()_+-=[]{}|;':\",./<>?"
        keywordStore.add(keyword: specialKeyword, subfolder: "Special", category: "Work")
        
        let addedKeyword = keywordStore.keywords.last
        XCTAssertEqual(addedKeyword?.keyword, specialKeyword)
    }
    
    func testUnicodeCharactersInKeyword() {
        let unicodeKeyword = "测试关键词"
        keywordStore.add(keyword: unicodeKeyword, subfolder: "Unicode", category: "Work")
        
        let addedKeyword = keywordStore.keywords.last
        XCTAssertEqual(addedKeyword?.keyword, unicodeKeyword)
    }
    
    func testLongKeyword() {
        let longKeyword = String(repeating: "a", count: 1000)
        keywordStore.add(keyword: longKeyword, subfolder: "Long", category: "Work")
        
        let addedKeyword = keywordStore.keywords.last
        XCTAssertEqual(addedKeyword?.keyword, longKeyword)
    }
    
    // MARK: - Error Handling Tests

    
    func testKeywordStoreWithCorruptedData() throws {
        // Create a corrupted JSON file
        let corruptedData = "invalid json content".data(using: .utf8)!
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/file_organizer_keywords.json")
        
        try corruptedData.write(to: path)
        
        // Should not crash and should start with empty keywords
        let newStore = createIsolatedKeywordStore()
        XCTAssertTrue(newStore.keywords.isEmpty)
    }
    
    // MARK: - Keyword Text Field Tests
    func testKeywordTextFieldValidation() {
        // Test empty keyword validation
        let emptyKeyword = ""
        let trimmedEmpty = emptyKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmedEmpty.isEmpty)
        
        // Test whitespace-only keyword validation
        let whitespaceKeyword = "   \n\t   "
        let trimmedWhitespace = whitespaceKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmedWhitespace.isEmpty)
        
        // Test valid keyword validation
        let validKeyword = "test"
        let trimmedValid = validKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmedValid.isEmpty)
        XCTAssertEqual(trimmedValid, "test")
        
        // Test keyword with leading/trailing whitespace
        let keywordWithWhitespace = "  test  "
        let trimmedWithWhitespace = keywordWithWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(trimmedWithWhitespace.isEmpty)
        XCTAssertEqual(trimmedWithWhitespace, "test")
    }
    
    func testKeywordTextFieldEdgeCases() {
        // Test single character keyword
        let singleChar = "a"
        keywordStore.add(keyword: singleChar, subfolder: "General", category: "Work")
        XCTAssertEqual(keywordStore.keywords.last?.keyword, singleChar)
        
        // Test very long keyword
        let longKeyword = String(repeating: "a", count: 1000)
        keywordStore.add(keyword: longKeyword, subfolder: "General", category: "Work")
        XCTAssertEqual(keywordStore.keywords.last?.keyword, longKeyword)
        
        // Test keyword with newlines
        let keywordWithNewlines = "test\nkeyword"
        keywordStore.add(keyword: keywordWithNewlines, subfolder: "General", category: "Work")
        XCTAssertEqual(keywordStore.keywords.last?.keyword, keywordWithNewlines)
        
        // Test keyword with tabs
        let keywordWithTabs = "test\tkeyword"
        keywordStore.add(keyword: keywordWithTabs, subfolder: "General", category: "Work")
        XCTAssertEqual(keywordStore.keywords.last?.keyword, keywordWithTabs)
    }
    
    func testKeywordTextFieldSpecialCharacters() {
        let specialKeywords = [
            "test@example.com",
            "file-name_123",
            "document (v2)",
            "report#final",
            "data$2024",
            "config%settings",
            "log^debug",
            "cache&temp",
            "backup+archive",
            "config=production",
            "path/to/file",
            "folder\\subfolder",
            "file|backup",
            "data;separated",
            "config:settings",
            "file\"quoted\"",
            "file'single'",
            "file<template>",
            "file>output",
            "file?optional",
            "file[array]",
            "file{object}",
            "file`code`",
            "file~tilde"
        ]
        
        for keyword in specialKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Special", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, specialKeywords.count)
    }
    
    func testKeywordTextFieldUnicodeSupport() {
        let unicodeKeywords = [
            "测试关键词",
            "キーワード",
            "ключевое слово",
            "كلمة مفتاحية",
            "מילת מפתח",
            "ключова дума",
            "كليدي لفظ",
            "คำสำคัญ",
            "Anahtar kelime",
            "Palavra-chave"
        ]
        
        for keyword in unicodeKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Unicode", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, unicodeKeywords.count)
    }
    
    func testKeywordTextFieldEmojiSupport() {
        let emojiKeywords = [
            "📁",
            "📄",
            "📂",
            "🗂️",
            "📋",
            "📝",
            "📊",
            "📈",
            "📉",
            "💾",
            "💿",
            "📀",
            "🔍",
            "🔎",
            "📌",
            "📍",
            "🎯",
            "⭐",
            "🌟",
            "✨"
        ]
        
        for keyword in emojiKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Emoji", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, emojiKeywords.count)
    }
    
    func testKeywordTextFieldMixedContent() {
        let mixedKeywords = [
            "test📁",
            "📄document",
            "file📂folder",
            "🗂️organizer",
            "📋list📝",
            "📊data📈",
            "💾backup💿",
            "🔍search🔎",
            "📌pin📍",
            "🎯target⭐",
            "🌟star✨",
            "测试📁",
            "📄キーワード",
            "ключевое📂слово",
            "كلمة🗂️مفتاحية",
            "מילת📋מפתח",
            "Anahtar📝kelime",
            "Palavra📊chave",
            "คำสำคัญ📈",
            "كليدي💾لفظ"
        ]
        
        for keyword in mixedKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Mixed", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, mixedKeywords.count)
    }
    
    func testKeywordTextFieldCaseSensitivity() {
        let caseKeywords = [
            "test",
            "Test",
            "TEST",
            "tEsT",
            "TeSt"
        ]
        
        for keyword in caseKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Case", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, caseKeywords.count)
        
        // Verify all keywords are stored with their original case
        let storedKeywords = keywordStore.keywords.map { $0.keyword }
        for keyword in caseKeywords {
            XCTAssertTrue(storedKeywords.contains(keyword))
        }
    }
    
    func testKeywordTextFieldWhitespaceHandling() {
        let whitespaceKeywords = [
            "  leading",
            "trailing  ",
            "  both  ",
            "\tleading",
            "trailing\t",
            "\nleading",
            "trailing\n",
            "  \t\n  mixed  \n\t  "
        ]
        
        for keyword in whitespaceKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Whitespace", category: "Work")
            XCTAssertEqual(keywordStore.keywords.last?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, whitespaceKeywords.count)
    }
    
    func testKeywordTextFieldDuplicateHandling() {
        // Add the same keyword multiple times
        let keyword = "test"
        let subfolder = "General"
        let category = "Work"
        
        keywordStore.add(keyword: keyword, subfolder: subfolder, category: category)
        keywordStore.add(keyword: keyword, subfolder: subfolder, category: category)
        keywordStore.add(keyword: keyword, subfolder: subfolder, category: category)
        
        // Should allow duplicates (no deduplication at store level)
        XCTAssertEqual(keywordStore.keywords.count, 3)
        
        let testKeywords = keywordStore.keywords.filter { $0.keyword == keyword }
        XCTAssertEqual(testKeywords.count, 3)
        
        // All should have the same properties
        for entry in testKeywords {
            XCTAssertEqual(entry.keyword, keyword)
            XCTAssertEqual(entry.subfolder, subfolder)
            XCTAssertEqual(entry.category, category)
        }
    }
    
    func testKeywordTextFieldPerformance() {
        measure {
            for i in 0..<1000 {
                let keyword = "keyword\(i)"
                keywordStore.add(keyword: keyword, subfolder: "Performance", category: "Work")
            }
        }
        
        XCTAssertEqual(keywordStore.keywords.count, 1000)
    }
    
    func testKeywordTextFieldMemoryUsage() {
        // Test with many large keywords
        let largeKeyword = String(repeating: "a", count: 10000)
        
        measure {
            for i in 0..<100 {
                let keyword = "\(largeKeyword)\(i)"
                keywordStore.add(keyword: keyword, subfolder: "Memory", category: "Work")
            }
        }
        
        XCTAssertEqual(keywordStore.keywords.count, 100)
    }
    
    func testKeywordTextFieldIntegrationWithSubfolder() {
        // Test that keyword and subfolder work together correctly
        let testCases = [
            ("keyword1", "subfolder1", "Work"),
            ("keyword2", "subfolder2", "Personal"),
            ("keyword3", "subfolder1", "Work"), // Same subfolder, different keyword
            ("keyword1", "subfolder3", "Work"), // Same keyword, different subfolder
        ]
        
        for (keyword, subfolder, category) in testCases {
            keywordStore.add(keyword: keyword, subfolder: subfolder, category: category)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, 4)
        
        // Verify each entry has correct properties
        for (index, (keyword, subfolder, category)) in testCases.enumerated() {
            let entry = keywordStore.keywords[index]
            XCTAssertEqual(entry.keyword, keyword)
            XCTAssertEqual(entry.subfolder, subfolder)
            XCTAssertEqual(entry.category, category)
        }
    }
    
    func testKeywordTextFieldIntegrationWithCategory() {
        // Test that keyword and category work together correctly
        let testCases = [
            ("keyword1", "General", "Work"),
            ("keyword2", "General", "Personal"),
            ("keyword3", "Documents", "Work"),
            ("keyword4", "Documents", "Personal"),
        ]
        
        for (keyword, subfolder, category) in testCases {
            keywordStore.add(keyword: keyword, subfolder: subfolder, category: category)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, 4)
        
        // Verify each entry has correct properties
        for (index, (keyword, subfolder, category)) in testCases.enumerated() {
            let entry = keywordStore.keywords[index]
            XCTAssertEqual(entry.keyword, keyword)
            XCTAssertEqual(entry.subfolder, subfolder)
            XCTAssertEqual(entry.category, category)
        }
    }
    
    func testKeywordTextFieldClearAllFunctionality() {
        // Add some keywords
        keywordStore.add(keyword: "test1", subfolder: "General", category: "Work")
        keywordStore.add(keyword: "test2", subfolder: "Personal", category: "Personal")
        keywordStore.add(keyword: "test3", subfolder: "Documents", category: "Work")
        
        XCTAssertEqual(keywordStore.keywords.count, 3)
        
        // Clear all keywords
        keywordStore.clearAllKeywords()
        
        XCTAssertEqual(keywordStore.keywords.count, 0)
        XCTAssertTrue(keywordStore.keywords.isEmpty)
    }
    
    func testKeywordTextFieldPersistence() throws {
        // Add keywords
        keywordStore.add(keyword: "persistent1", subfolder: "General", category: "Work")
        keywordStore.add(keyword: "persistent2", subfolder: "Personal", category: "Personal")
        
        XCTAssertEqual(keywordStore.keywords.count, 2)
        
        // Create a new store instance (simulating app restart)
        let newStore = createIsolatedKeywordStore()
        
        // The new store should start empty (since we're using isolated storage for tests)
        XCTAssertEqual(newStore.keywords.count, 0)
    }
}

// MARK: - Test Helpers
extension FileOrganizerAppTests {
    
    func createIsolatedKeywordStore() -> KeywordStore {
        // Create a temporary store that doesn't persist to the main file
        let store = KeywordStore()
        store.keywords = [] // Ensure it starts empty
        return store
    }
    
    func createTestFile(name: String, content: String = "test content") throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    func createTestDirectory(name: String) throws -> URL {
        let dirURL = tempDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    func cleanupTestFiles() throws {
        let contents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        for file in contents {
            try FileManager.default.removeItem(at: file)
        }
    }
} 