//
//  FileClassificationManager.swift
//  File Classification System
//
//  A robust file classification system with LLM integration,
//  fallback rule-based classification, and comprehensive telemetry.
//

import Foundation

// MARK: - File Classification Manager

class FileClassificationManager {
    
    // MARK: - Properties
    
    private let llmService: LLMService
    private let telemetryService: TelemetryService
    private let fallbackClassifier: FallbackClassifier
    private let promptBuilder: ClassificationPromptBuilder
    
    var useExamples: Bool = true
    var enableTelemetry: Bool = true
    var useFallbackOnFailure: Bool = true
    
    // MARK: - Initialization
    
    init(
        llmService: LLMService,
        telemetryService: TelemetryService = TelemetryService.shared,
        fallbackClassifier: FallbackClassifier = FallbackClassifier(),
        promptBuilder: ClassificationPromptBuilder = ClassificationPromptBuilder()
    ) {
        self.llmService = llmService
        self.telemetryService = telemetryService
        self.fallbackClassifier = fallbackClassifier
        self.promptBuilder = promptBuilder
        
        self.promptBuilder.useExamples = useExamples
    }
    
    // MARK: - Public Methods
    
    /// Classify a file using LLM with fallback to rule-based classification
    func classifyFile(_ metadata: FileMetadata) async -> ClassificationResult {
        let startTime = Date()
        var classificationMethod: ClassificationMethod = .llm
        var result: ClassificationResult?
        
        // Determine if category is pre-determined by extension
        let preCategory = fallbackClassifier.determineCategoryFromExtension(metadata.fileExtension)
        
        // Try LLM classification first
        do {
            result = try await classifyWithLLM(metadata: metadata, preCategory: preCategory)
            
            if enableTelemetry {
                let duration = Date().timeIntervalSince(startTime)
                telemetryService.recordClassification(
                    method: .llm,
                    success: true,
                    confidence: result?.confidence ?? 0.0,
                    duration: duration,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ LLM classification failed: \(error)")
            classificationMethod = .fallback
            
            if enableTelemetry {
                telemetryService.recordClassification(
                    method: .llm,
                    success: false,
                    confidence: 0.0,
                    duration: Date().timeIntervalSince(startTime),
                    metadata: metadata,
                    error: error.localizedDescription
                )
            }
        }
        
        // Fallback to rule-based classification if LLM fails
        if result == nil && useFallbackOnFailure {
            result = fallbackClassifier.classify(metadata)
            classificationMethod = .fallback
            
            if enableTelemetry {
                let duration = Date().timeIntervalSince(startTime)
                telemetryService.recordClassification(
                    method: .fallback,
                    success: true,
                    confidence: result?.confidence ?? 0.0,
                    duration: duration,
                    metadata: metadata
                )
            }
        }
        
        // If all else fails, return a default classification
        guard let finalResult = result else {
            let defaultResult = ClassificationResult(
                category: "Documents",
                subfolder: "General",
                confidence: 0.3,
                reasoning: "Default fallback classification",
                method: .fallback
            )
            return defaultResult
        }
        
        // Add classification method to result
        return ClassificationResult(
            category: finalResult.category,
            subfolder: finalResult.subfolder,
            confidence: finalResult.confidence,
            reasoning: finalResult.reasoning,
            method: classificationMethod
        )
    }
    
    /// Batch classify multiple files
    func classifyFiles(_ files: [FileMetadata]) async -> [ClassificationResult] {
        await withTaskGroup(of: (Int, ClassificationResult).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    let result = await self.classifyFile(file)
                    return (index, result)
                }
            }
            
            var results: [(Int, ClassificationResult)] = []
            for await result in group {
                results.append(result)
            }
            
            // Sort by original index to maintain order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Private Methods
    
    private func classifyWithLLM(metadata: FileMetadata, preCategory: String?) async throws -> ClassificationResult {
        // Build the prompt
        let prompt = promptBuilder.buildPrompt(metadata: metadata, preCategory: preCategory)
        
        // Call LLM service
        let response = try await llmService.generateCompletion(prompt: prompt)
        
        // Parse and validate response
        guard let result = parseClassificationResponse(response) else {
            throw ClassificationError.parseError("Failed to parse LLM response: \(response)")
        }
        
        // Validate result
        guard validateClassificationResult(result) else {
            throw ClassificationError.parseError("Validation failed for result: \(result)")
        }
        
        return result
    }
    
    /// Parse LLM response with robust error handling
    private func parseClassificationResponse(_ response: String) -> ClassificationResult? {
        // Clean the response - remove markdown code blocks if present
        var cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if cleanedResponse.hasPrefix("```") {
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```json", with: "")
            cleanedResponse = cleanedResponse.replacingOccurrences(of: "```", with: "")
            cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to find JSON object if there's extra text
        if let jsonStart = cleanedResponse.firstIndex(of: "{"),
           let jsonEnd = cleanedResponse.lastIndex(of: "}") {
            cleanedResponse = String(cleanedResponse[jsonStart...jsonEnd])
        }
        
        // Parse JSON
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("⚠️ Failed to convert response to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            var result = try decoder.decode(ClassificationResult.self, from: data)
            result.method = .llm
            // Ensure reasoning is not nil
            if result.reasoning == nil {
                result = ClassificationResult(
                    category: result.category,
                    subfolder: result.subfolder,
                    confidence: result.confidence,
                    reasoning: "LLM classification",
                    method: .llm
                )
            }
            return result
        } catch {
            print("⚠️ JSON parsing error: \(error)")
            print("Response was: \(cleanedResponse)")
            return nil
        }
    }
    
    /// Validate classification result
    private func validateClassificationResult(_ result: ClassificationResult) -> Bool {
        let validCategories = ["Media", "Projects", "Documents", "Archive"]
        
        // Check category is valid
        guard validCategories.contains(result.category) else {
            print("⚠️ Invalid category: \(result.category)")
            return false
        }
        
        // Check subfolder is valid for the category
        let validSubfolders = ClassificationConstants.validSubfolders[result.category] ?? []
        guard validSubfolders.contains(result.subfolder) else {
            print("⚠️ Invalid subfolder '\(result.subfolder)' for category '\(result.category)'")
            return false
        }
        
        // Check confidence is in valid range
        guard (0.0...1.0).contains(result.confidence) else {
            print("⚠️ Invalid confidence: \(result.confidence)")
            return false
        }
        
        // Check subfolder doesn't contain invalid characters
        guard !result.subfolder.contains("/") && !result.subfolder.contains("\\") else {
            print("⚠️ Subfolder contains invalid path separators")
            return false
        }
        
        return true
    }
}

// MARK: - Classification Error
// Note: ClassificationError is defined in ClassificationResult.swift

// MARK: - Classification Method

enum ClassificationMethod: String, Codable {
    case llm = "llm"
    case fallback = "fallback"
    case hybrid = "hybrid"
}