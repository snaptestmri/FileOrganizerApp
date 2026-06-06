import Foundation
@testable import FileOrganizerApp

/// Test-only LLM stub with configurable responses (not shipped in the app target).
final class StubLLMService: LLMService {
    var shouldFail = false
    var fixedResponse: String?
    var delay: TimeInterval = 0

    func generateCompletion(prompt: String) async throws -> String {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldFail {
            throw NSError(domain: "StubLLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Stub failure"])
        }
        if let fixedResponse {
            return fixedResponse
        }
        return """
        {"category": "Personal", "subfolder": "General", "confidence": 0.80, "reasoning": "stub default", "method": "llm"}
        """
    }
}

extension StubLLMService {
    static func fast() -> StubLLMService {
        let stub = StubLLMService()
        stub.delay = 0
        return stub
    }

    static func failingInstantly() -> StubLLMService {
        let stub = fast()
        stub.shouldFail = true
        return stub
    }
}
