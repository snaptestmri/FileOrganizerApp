//
//  MockLLMService.swift
//  File Classification System
//
//  Mock LLM service for testing.
//

import Foundation

// MARK: - Mock LLM Service (for testing)

class MockLLMService: LLMService {
    var shouldFail = false
    var mockResponse: String?
    var delay: TimeInterval = 0.5
    
    func generateCompletion(prompt: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldFail {
            throw NSError(domain: "MockLLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        
        if let response = mockResponse {
            return response
        }
        
        // Generate a mock response based on the prompt
        if prompt.contains(".jpg") || prompt.contains(".png") || prompt.contains(".webp") {
            return """
            {"category": "Media", "subfolder": "Photos", "confidence": 0.95, "reasoning": "extension indicates image file", "method": "llm"}
            """
        } else if prompt.contains(".mp4") || prompt.contains(".mov") {
            return """
            {"category": "Media", "subfolder": "Videos", "confidence": 0.95, "reasoning": "extension indicates video file", "method": "llm"}
            """
        } else if prompt.contains(".stl") || prompt.contains(".obj") {
            return """
            {"category": "Projects", "subfolder": "3D", "confidence": 0.95, "reasoning": "extension indicates 3D model", "method": "llm"}
            """
        } else if prompt.contains(".swift") || prompt.contains(".py") {
            return """
            {"category": "Projects", "subfolder": "Code", "confidence": 0.95, "reasoning": "extension indicates code file", "method": "llm"}
            """
        } else if prompt.contains("invoice") {
            return """
            {"category": "Documents", "subfolder": "Invoices", "confidence": 0.92, "reasoning": "filename contains 'invoice'", "method": "llm"}
            """
        } else {
            return """
            {"category": "Documents", "subfolder": "General", "confidence": 0.80, "reasoning": "default classification", "method": "llm"}
            """
        }
    }
}

