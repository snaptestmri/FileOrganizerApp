//
//  OllamaLLMService.swift
//  File Classification System
//
//  Local LLM service implementation using Ollama.
//

import Foundation

// MARK: - Ollama LLM Service Implementation

class OllamaLLMService: LLMService {
    private let baseURL: URL
    private let model: String
    private let temperature: Double
    private let topP: Double
    private let topK: Int
    
    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "llama3.2:3b",
        temperature: Double = 0.1,
        topP: Double = 0.95,
        topK: Int = 40
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }
    
    func generateCompletion(prompt: String) async throws -> String {
        var requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        
        let options: [String: Any] = [
            "temperature": temperature,
            "top_p": topP,
            "top_k": topK,
            "num_predict": 200
        ]
        requestBody["options"] = options
        
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaLLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ollama API returned error"])
        }
        
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }
}

private struct OllamaResponse: Codable {
    let response: String
}

