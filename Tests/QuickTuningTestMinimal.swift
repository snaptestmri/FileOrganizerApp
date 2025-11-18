import Foundation
import XCTest
@testable import FileOrganizerApp

/// Minimal test to debug the crash
final class QuickTuningTestMinimal: XCTestCase {
    
    func testMinimal() async throws {
        print("Test started")
        XCTAssertTrue(true)
    }
    
    func testQuickTuningSimple() async throws {
        print("🚀 Quick Classifier Tuning Test")
        print(String(repeating: "=", count: 60))
        
        // Skip if Ollama not available (don't check, just skip)
        throw XCTSkip("Skipping for now - test Ollama availability manually")
    }
}

