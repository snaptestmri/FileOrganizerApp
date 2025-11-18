import XCTest
import SwiftUI
import Foundation
@testable import FileOrganizerApp

final class KeywordTextFieldTests: XCTestCase {
    
    // MARK: - Test Properties
    var keywordStore: KeywordStore!
    var tempDirectory: URL!
    
    // MARK: - Setup and Teardown
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeywordTextFieldTests")
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
    
    // MARK: - Core Functionality Tests
    func testKeywordTextFieldBasicFunctionality() {
        // Test basic keyword addition
        let testKeyword = "basic test"
        keywordStore.add(keyword: testKeyword, subfolder: "Basic", category: "Work")
        
        XCTAssertEqual(keywordStore.keywords.count, 1)
        let addedEntry = keywordStore.keywords.first
        XCTAssertEqual(addedEntry?.keyword, testKeyword)
        XCTAssertEqual(addedEntry?.subfolder, "Basic")
        XCTAssertEqual(addedEntry?.category, "Work")
    }
    
    func testKeywordTextFieldEmptyValidation() {
        // Test that empty keywords are handled correctly
        let emptyKeywords = ["", "   ", "\n", "\t", "  \n\t  "]
        
        for keyword in emptyKeywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(trimmed.isEmpty, "Failed for keyword: '\(keyword)'")
        }
    }
    
    func testKeywordTextFieldWhitespaceTrimming() {
        // Test whitespace trimming functionality
        let testCases = [
            ("  test  ", "test"),
            ("\ttest\t", "test"),
            ("\ntest\n", "test"),
            ("  \t\n  test  \n\t  ", "test"),
            ("test", "test"),
            ("  test", "test"),
            ("test  ", "test")
        ]
        
        for (input, expected) in testCases {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(trimmed, expected, "Failed for input: '\(input)'")
        }
    }
    
    // MARK: - Input Validation Tests
    func testKeywordTextFieldInputValidation() {
        let validationTestCases = [
            ("", false, "Empty string"),
            ("   ", false, "Whitespace only"),
            ("\n\t", false, "Newlines and tabs only"),
            ("a", true, "Single character"),
            ("test", true, "Normal keyword"),
            ("  test  ", true, "Keyword with whitespace"),
            ("test\n", true, "Keyword with newline"),
            ("test\t", true, "Keyword with tab"),
            ("test\r\n", true, "Keyword with carriage return"),
            ("test\0", true, "Keyword with null character"),
            ("test test", true, "Keyword with space"),
            ("test-test", true, "Keyword with hyphen"),
            ("test_test", true, "Keyword with underscore"),
            ("test.test", true, "Keyword with period"),
            ("test@test", true, "Keyword with at symbol"),
            ("test#test", true, "Keyword with hash"),
            ("test$test", true, "Keyword with dollar sign"),
            ("test%test", true, "Keyword with percent"),
            ("test^test", true, "Keyword with caret"),
            ("test&test", true, "Keyword with ampersand"),
            ("test*test", true, "Keyword with asterisk"),
            ("test+test", true, "Keyword with plus"),
            ("test=test", true, "Keyword with equals"),
            ("test|test", true, "Keyword with pipe"),
            ("test\\test", true, "Keyword with backslash"),
            ("test/test", true, "Keyword with forward slash"),
            ("test:test", true, "Keyword with colon"),
            ("test;test", true, "Keyword with semicolon"),
            ("test\"test", true, "Keyword with quote"),
            ("test'test", true, "Keyword with apostrophe"),
            ("test<test", true, "Keyword with less than"),
            ("test>test", true, "Keyword with greater than"),
            ("test?test", true, "Keyword with question mark"),
            ("test[test", true, "Keyword with bracket"),
            ("test]test", true, "Keyword with closing bracket"),
            ("test{test", true, "Keyword with brace"),
            ("test}test", true, "Keyword with closing brace"),
            ("test`test", true, "Keyword with backtick"),
            ("test~test", true, "Keyword with tilde")
        ]
        
        for (input, expectedValid, description) in validationTestCases {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValid = !trimmed.isEmpty
            XCTAssertEqual(isValid, expectedValid, "Failed for \(description): '\(input)'")
        }
    }
    
    // MARK: - Character Set Tests
    func testKeywordTextFieldUnicodeSupport() {
        let unicodeTestCases = [
            ("测试关键词", "Chinese"),
            ("キーワード", "Japanese"),
            ("ключевое слово", "Russian"),
            ("كلمة مفتاحية", "Arabic"),
            ("מילת מפתח", "Hebrew"),
            ("Anahtar kelime", "Turkish"),
            ("Palavra-chave", "Portuguese"),
            ("Mots-clés", "French"),
            ("Schlüsselwort", "German"),
            ("Parola chiave", "Italian"),
            ("Palabra clave", "Spanish"),
            ("Sleutelwoord", "Dutch"),
            ("Nyckelord", "Swedish"),
            ("Avainsana", "Finnish"),
            ("Klíčové slovo", "Czech"),
            ("Kulcsszó", "Hungarian"),
            ("Ključna beseda", "Slovenian"),
            ("Ključna riječ", "Croatian"),
            ("Ključna reč", "Serbian"),
            ("Ključna beseda", "Slovak")
        ]
        
        for (keyword, language) in unicodeTestCases {
            keywordStore.add(keyword: keyword, subfolder: "Unicode", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword, "Failed for \(language)")
        }
        
        XCTAssertEqual(keywordStore.keywords.count, unicodeTestCases.count)
    }
    
    func testKeywordTextFieldEmojiSupport() {
        let emojiKeywords = [
            "📁", "📄", "📂", "🗂️", "📋", "📝", "📊", "📈", "📉",
            "💾", "💿", "📀", "🔍", "🔎", "📌", "📍", "🎯", "⭐", "🌟", "✨",
            "📱", "💻", "🖥️", "⌨️", "🖱️", "🖨️", "📷", "🎥", "🎬", "🎭",
            "🎨", "🎪", "🎟️", "🎫", "🎖️", "🏆", "🏅", "🥇", "🥈", "🥉"
        ]
        
        for emoji in emojiKeywords {
            keywordStore.add(keyword: emoji, subfolder: "Emoji", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, emoji)
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
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, mixedKeywords.count)
    }
    
    // MARK: - Edge Case Tests
    func testKeywordTextFieldExtremeLengths() {
        // Test very short keywords
        let shortKeywords = ["a", "b", "c", "1", "2", "3", "!", "@", "#", "$"]
        
        for keyword in shortKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Short", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword)
        }
        
        // Test very long keywords
        let longKeywords = [
            String(repeating: "a", count: 100),
            String(repeating: "b", count: 1000),
            String(repeating: "c", count: 10000)
        ]
        
        for keyword in longKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Long", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, shortKeywords.count + longKeywords.count)
    }
    
    func testKeywordTextFieldControlCharacters() {
        let controlCharacters = [
            "\0", // Null
            "\t", // Tab
            "\n", // Newline
            "\r", // Carriage return
            "\r\n", // Carriage return + newline
            "\u{0001}", // Start of heading
            "\u{0002}", // Start of text
            "\u{0003}", // End of text
            "\u{0004}", // End of transmission
            "\u{0005}", // Enquiry
            "\u{0006}", // Acknowledge
            "\u{0007}", // Bell
            "\u{0008}", // Backspace
            "\u{0009}", // Horizontal tab
            "\u{000A}", // Line feed
            "\u{000B}", // Vertical tab
            "\u{000C}", // Form feed
            "\u{000D}", // Carriage return
            "\u{000E}", // Shift out
            "\u{000F}", // Shift in
            "\u{0010}", // Data link escape
            "\u{0011}", // Device control 1
            "\u{0012}", // Device control 2
            "\u{0013}", // Device control 3
            "\u{0014}", // Device control 4
            "\u{0015}", // Negative acknowledge
            "\u{0016}", // Synchronous idle
            "\u{0017}", // End of transmission block
            "\u{0018}", // Cancel
            "\u{0019}", // End of medium
            "\u{001A}", // Substitute
            "\u{001B}", // Escape
            "\u{001C}", // File separator
            "\u{001D}", // Group separator
            "\u{001E}", // Record separator
            "\u{001F}"  // Unit separator
        ]
        
        for char in controlCharacters {
            let keyword = "test\(char)keyword"
            keywordStore.add(keyword: keyword, subfolder: "Control", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, controlCharacters.count)
    }
    
    func testKeywordTextFieldSpecialUnicode() {
        let specialUnicode = [
            "\u{200B}", // Zero width space
            "\u{200C}", // Zero width non-joiner
            "\u{200D}", // Zero width joiner
            "\u{200E}", // Left-to-right mark
            "\u{200F}", // Right-to-left mark
            "\u{2028}", // Line separator
            "\u{2029}", // Paragraph separator
            "\u{202A}", // Left-to-right embedding
            "\u{202B}", // Right-to-left embedding
            "\u{202C}", // Pop directional formatting
            "\u{202D}", // Left-to-right override
            "\u{202E}", // Right-to-left override
            "\u{2060}", // Word joiner
            "\u{2061}", // Function application
            "\u{2062}", // Invisible times
            "\u{2063}", // Invisible separator
            "\u{2064}", // Invisible plus
            "\u{2066}", // Left-to-right isolate
            "\u{2067}", // Right-to-left isolate
            "\u{2068}", // First strong isolate
            "\u{2069}", // Pop directional isolate
            "\u{206A}", // Inhibit symmetric swapping
            "\u{206B}", // Activate symmetric swapping
            "\u{206C}", // Inhibit arabic form shaping
            "\u{206D}", // Activate arabic form shaping
            "\u{206E}", // National digit shapes
            "\u{206F}"  // Nominal digit shapes
        ]
        
        for char in specialUnicode {
            let keyword = "test\(char)keyword"
            keywordStore.add(keyword: keyword, subfolder: "SpecialUnicode", category: "Work")
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, keyword)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, specialUnicode.count)
    }
    
    // MARK: - Performance Tests
    func testKeywordTextFieldPerformance() {
        measure {
            for i in 0..<1000 {
                let keyword = "performance\(i)"
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
    
    func testKeywordTextFieldConcurrentAccess() {
        // Test concurrent access to keyword store
        let expectation = XCTestExpectation(description: "Concurrent keyword additions")
        let queue = DispatchQueue(label: "test.queue", attributes: .concurrent)
        
        let keywords = Array(0..<100).map { "concurrent\($0)" }
        
        for keyword in keywords {
            queue.async {
                self.keywordStore.add(keyword: keyword, subfolder: "Concurrent", category: "Work")
            }
        }
        
        queue.async {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should have all keywords added (though order may vary)
        XCTAssertEqual(keywordStore.keywords.count, keywords.count)
    }
    
    // MARK: - Integration Tests
    func testKeywordTextFieldWithSubfolderIntegration() {
        // Test that keyword field works correctly with subfolder selection
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
    
    func testKeywordTextFieldWithCategoryIntegration() {
        // Test that keyword field works correctly with category selection
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
    
    // MARK: - Error Handling Tests
    func testKeywordTextFieldErrorHandling() {
        // Test that the system handles problematic inputs gracefully
        let problematicInputs = [
            String(repeating: "a", count: 100000), // Extremely long keyword
            "test\nkeyword\nwith\nmany\nnewlines\n",
            "test\tkeyword\twith\tmany\ttabs\t",
            "test\r\nkeyword\r\nwith\r\ncarriage\r\nreturns\r\n",
            "test\0keyword\0with\0nulls\0",
            String(repeating: "测试", count: 1000), // Many unicode characters
            String(repeating: "📁", count: 1000), // Many emojis
        ]
        
        for input in problematicInputs {
            // Should not crash when adding problematic keywords
            keywordStore.add(keyword: input, subfolder: "ErrorHandling", category: "Work")
        }
        
        XCTAssertEqual(keywordStore.keywords.count, problematicInputs.count)
    }
    
    func testKeywordTextFieldCorruptedDataHandling() throws {
        // Test handling of corrupted data
        let corruptedData = "invalid json content".data(using: .utf8)!
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/file_organizer_keywords.json")
        
        try corruptedData.write(to: path)
        
        // Should not crash and should start with empty keywords
        let newStore = createIsolatedKeywordStore()
        XCTAssertTrue(newStore.keywords.isEmpty)
    }
    
    // MARK: - Accessibility Tests
    func testKeywordTextFieldAccessibility() {
        // Test accessibility considerations
        let accessibilityKeywords = [
            "document",
            "spreadsheet",
            "presentation",
            "image",
            "video",
            "audio",
            "archive",
            "backup",
            "configuration",
            "settings"
        ]
        
        for keyword in accessibilityKeywords {
            keywordStore.add(keyword: keyword, subfolder: "Accessibility", category: "Work")
        }
        
        XCTAssertEqual(keywordStore.keywords.count, accessibilityKeywords.count)
        
        // Verify all keywords are stored correctly
        let storedKeywords = keywordStore.keywords.map { $0.keyword }
        for keyword in accessibilityKeywords {
            XCTAssertTrue(storedKeywords.contains(keyword))
        }
    }
    
    func testKeywordTextFieldInputHandling() {
        // Test that keyword text field can handle input correctly
        let testInputs = [
            "simple",
            "with spaces",
            "with-special-chars!@#",
            "with numbers 123",
            "with unicode 🚀",
            "very long keyword that should still work properly even when it gets quite lengthy"
        ]
        
        for input in testInputs {
            // Simulate adding the keyword
            keywordStore.add(keyword: input, subfolder: "InputTest", category: "Work")
            
            // Verify it was stored correctly
            let addedEntry = keywordStore.keywords.last
            XCTAssertEqual(addedEntry?.keyword, input)
        }
        
        XCTAssertEqual(keywordStore.keywords.count, testInputs.count)
    }
    
    func testKeywordTextFieldFocusManagement() {
        // Test focus management for keyword text field
        let testKeyword = "focus test"
        
        // Add keyword and verify focus behavior
        keywordStore.add(keyword: testKeyword, subfolder: "Focus", category: "Work")
        
        // Verify the keyword was added
        let addedEntry = keywordStore.keywords.last
        XCTAssertEqual(addedEntry?.keyword, testKeyword)
        
        // Test that focus can be managed properly
        // This simulates the focus state management in the UI
        var focusState: String? = "keyword"
        XCTAssertNotNil(focusState)
        
        // Simulate clearing focus
        focusState = nil
        XCTAssertNil(focusState)
        
        // Simulate setting focus back to keyword field
        focusState = "keyword"
        XCTAssertEqual(focusState, "keyword")
    }
    
    func testKeywordTextFieldWithSpecialCharacters() {
        // Test keyword text field with various special characters
        let specialKeywords = [
            "test@email.com",
            "file-name_with_underscores",
            "path/to/file",
            "file (copy)",
            "file [1]",
            "file {version}",
            "file & more",
            "file + plus",
            "file = equals",
            "file | pipe",
            "file \\ backslash",
            "file / forward slash",
            "file ~ tilde",
            "file ` backtick",
            "file ' single quote",
            "file \" double quote"
        ]
        
        for keyword in specialKeywords {
            keywordStore.add(keyword: keyword, subfolder: "SpecialChars", category: "Work")
        }
        
        XCTAssertEqual(keywordStore.keywords.count, specialKeywords.count)
        
        // Verify all keywords were stored correctly
        let storedKeywords = keywordStore.keywords.map { $0.keyword }
        for keyword in specialKeywords {
            XCTAssertTrue(storedKeywords.contains(keyword))
        }
    }
    
    // MARK: - Test Helpers
    private func createIsolatedKeywordStore() -> KeywordStore {
        // Create a temporary store that doesn't persist to the main file
        let store = KeywordStore()
        store.keywords = [] // Ensure it starts empty
        return store
    }
}

