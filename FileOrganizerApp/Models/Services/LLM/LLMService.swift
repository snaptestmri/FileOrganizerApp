//
//  LLMService.swift
//  File Classification System
//
//  Protocol for LLM service implementations.
//

import Foundation

// MARK: - LLM Service Protocol

protocol LLMService {
    func generateCompletion(prompt: String) async throws -> String
}

