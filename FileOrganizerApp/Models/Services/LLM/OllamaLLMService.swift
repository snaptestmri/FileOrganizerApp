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
    private let timeoutInterval: TimeInterval
    private let maxRetries: Int
    
    // Custom URLSession with longer timeout for Ollama
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval * 2 // Allow longer for resource
        return URLSession(configuration: configuration)
    }()
    
    init(
        baseURL: URL? = nil,
        model: String = "llama3.2:3b",
        temperature: Double = 0.1,
        topP: Double = 0.95,
        topK: Int = 40,
        timeoutInterval: TimeInterval = 120.0, // 2 minutes default (Ollama can be slow)
        maxRetries: Int = 2
    ) {
        guard let url = baseURL ?? URL(string: "http://localhost:11434") else {
            fatalError("Invalid Ollama base URL: http://localhost:11434")
        }
        self.baseURL = url
        self.model = model
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
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
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Retry logic for timeout errors
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "OllamaLLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Ollama"])
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMsg = "Ollama API returned error: HTTP \(httpResponse.statusCode)"
                    throw NSError(domain: "OllamaLLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
                
                let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
                return ollamaResponse.response
                
            } catch let error as NSError {
                lastError = error
                
                // Check if it's a timeout error
                let isTimeout = error.domain == NSURLErrorDomain && 
                               (error.code == NSURLErrorTimedOut || error.code == -1001)
                
                // Only retry on timeout errors, and only if we have retries left
                if isTimeout && attempt < maxRetries {
                    let delay = Double(attempt + 1) * 2.0 // Exponential backoff: 2s, 4s
                    print("⚠️ Ollama request timed out (attempt \(attempt + 1)/\(maxRetries + 1)). Retrying in \(delay)s...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Not a timeout, or no retries left
                    if isTimeout {
                        throw NSError(
                            domain: "OllamaLLMService",
                            code: NSURLErrorTimedOut,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Ollama request timed out after \(maxRetries + 1) attempts. Make sure Ollama is running and the model is loaded. Try: ollama pull \(model)"
                            ]
                        )
                    }
                    throw error
                }
            }
        }
        
        // Should never reach here, but just in case
        throw lastError ?? NSError(domain: "OllamaLLMService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }
}

private struct OllamaResponse: Codable {
    let response: String
}

