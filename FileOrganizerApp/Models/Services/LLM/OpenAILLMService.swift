//
//  OpenAILLMService.swift
//  File Classification System
//
//  OpenAI LLM service implementation.
//

import Foundation

// MARK: - Real LLM Service Implementation (OpenAI)

class OpenAILLMService: LLMService {
    private let apiKey: String
    private let model: String
    private let maxTokens: Int
    
    init(apiKey: String, model: String = "gpt-4", maxTokens: Int = 500) {
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
    }
    
    func generateCompletion(prompt: String) async throws -> String {
        // Implement actual OpenAI API call here
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OpenAILLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        guard let result = content else {
            throw NSError(domain: "OpenAILLMService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return result
    }
}

