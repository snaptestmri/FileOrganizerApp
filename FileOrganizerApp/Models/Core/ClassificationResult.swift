import Foundation

/// Classification result from LLM
struct ClassificationResult: Codable, CustomStringConvertible {
    let category: String
    let subfolder: String
    let confidence: Double  // 0.0 to 1.0
    let reasoning: String?  // Optional explanation
    var method: ClassificationMethod = .llm  // Classification method used
    
    var description: String {
        return """
        Classification Result:
        - Category: \(category)
        - Subfolder: \(subfolder)
        - Confidence: \(String(format: "%.2f", confidence))
        - Method: \(method.rawValue)
        - Reasoning: \(reasoning ?? "N/A")
        """
    }
    
    var destinationPath: String {
        return "\(category)/\(subfolder)"
    }
}

// MARK: - Classification Error

/// Classification errors
enum ClassificationError: LocalizedError {
    case apiError(String)
    case parseError(String)
    case unavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        case .unavailable(let message):
            return "Unavailable: \(message)"
        }
    }
}
