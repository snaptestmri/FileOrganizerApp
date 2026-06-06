//
//  FailingLLMService.swift
//  File Classification System
//
//  LLM service that always fails — used to force rule-based fallback.
//

import Foundation

// MARK: - Failing LLM Service

/// Always throws so `FileClassificationManager` uses `FallbackClassifier`.
final class FailingLLMService: LLMService {
    var errorMessage: String

    init(errorMessage: String = "LLM unavailable") {
        self.errorMessage = errorMessage
    }

    func generateCompletion(prompt: String) async throws -> String {
        throw NSError(
            domain: "FailingLLMService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
    }
}
