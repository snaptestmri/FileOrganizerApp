import Foundation

// MARK: - Shared Test Utilities

// Helper extension for string repetition (used across multiple test files)
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

