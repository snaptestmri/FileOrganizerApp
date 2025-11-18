//
//  AnthropicLLMService.swift
//  File Classification System
//
//  Anthropic Claude LLM service implementation.
//

import Foundation

// MARK: - Anthropic Claude LLM Service

class AnthropicLLMService: LLMService {
    private let apiKey: String
    private let model: String
    private let maxTokens: Int
    
    init(apiKey: String, model: String = "claude-3-sonnet-20240229", maxTokens: Int = 500) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
    }
    
    func generateCompletion(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "AnthropicLLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        
        guard let result = text else {
            throw NSError(domain: "AnthropicLLMService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return result
    }
}

