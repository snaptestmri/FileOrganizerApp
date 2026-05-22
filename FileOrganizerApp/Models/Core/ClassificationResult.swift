import Foundation

/// Classification result from LLM
struct ClassificationResult: Codable, CustomStringConvertible {
    let category: String
    let subfolder: String
    let confidence: Double  // 0.0 to 1.0
    let reasoning: String?  // Optional explanation
    var method: ClassificationMethod  // Classification method used
    
    enum CodingKeys: String, CodingKey {
        case category, subfolder, confidence, reasoning, method
    }
    
    init(category: String, subfolder: String, confidence: Double, reasoning: String? = nil, method: ClassificationMethod = .llm) {
        self.category = category
        self.subfolder = subfolder
        self.confidence = confidence
        self.reasoning = reasoning
        self.method = method
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        subfolder = try container.decode(String.self, forKey: .subfolder)
        confidence = try container.decode(Double.self, forKey: .confidence)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        // method is optional in JSON, default to .llm if missing
        method = (try? container.decode(ClassificationMethod.self, forKey: .method)) ?? .llm
    }
    
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
