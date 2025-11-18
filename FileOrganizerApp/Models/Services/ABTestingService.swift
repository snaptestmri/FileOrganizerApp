//
//  ABTestingService.swift
//  File Classification System
//
//  A/B testing framework for comparing prompt variants and
//  classification approaches to optimize system performance.
//

import Foundation

// MARK: - A/B Testing Service

class ABTestingService {
    
    // MARK: - Shared Instance
    
    static let shared = ABTestingService()
    
    // MARK: - Properties
    
    private var activeExperiments: [String: Experiment] = [:]
    private var experimentResults: [String: [ExperimentResult]] = [:]
    private let queue = DispatchQueue(label: "com.fileClassification.abtesting", attributes: .concurrent)
    
    var isEnabled = true
    
    // MARK: - Initialization
    
    private init() {
        setupDefaultExperiments()
    }
    
    // MARK: - Public Methods
    
    /// Create a new experiment
    func createExperiment(
        name: String,
        variants: [ExperimentVariant],
        trafficAllocation: [String: Double]? = nil
    ) {
        queue.async(flags: .barrier) {
            let experiment = Experiment(
                id: UUID().uuidString,
                name: name,
                variants: variants,
                trafficAllocation: trafficAllocation ?? self.evenTrafficAllocation(for: variants),
                startDate: Date(),
                isActive: true
            )
            
            self.activeExperiments[experiment.id] = experiment
            self.experimentResults[experiment.id] = []
            
            print("📊 Created experiment: \(name) with \(variants.count) variants")
        }
    }
    
    /// Get variant for a classification request
    func getVariant(experimentName: String) -> ExperimentVariant? {
        guard isEnabled else { return nil }
        
        return queue.sync {
            guard let experiment = activeExperiments.values.first(where: { $0.name == experimentName }),
                  experiment.isActive else {
                return nil
            }
            
            // Use weighted random selection based on traffic allocation
            let random = Double.random(in: 0...1)
            var cumulative = 0.0
            
            for variant in experiment.variants {
                cumulative += experiment.trafficAllocation[variant.id] ?? 0.0
                if random <= cumulative {
                    return variant
                }
            }
            
            return experiment.variants.first
        }
    }
    
    /// Record experiment result
    func recordResult(
        experimentName: String,
        variantId: String,
        success: Bool,
        confidence: Double,
        duration: TimeInterval,
        metadata: FileMetadata
    ) {
        guard isEnabled else { return }
        
        queue.async(flags: .barrier) {
            guard let experiment = self.activeExperiments.values.first(where: { $0.name == experimentName }) else {
                return
            }
            
            let result = ExperimentResult(
                timestamp: Date(),
                experimentId: experiment.id,
                variantId: variantId,
                success: success,
                confidence: confidence,
                duration: duration,
                fileExtension: metadata.fileExtension,
                fileSize: metadata.fileSize
            )
            
            self.experimentResults[experiment.id, default: []].append(result)
        }
    }
    
    /// Get experiment analysis
    func getExperimentAnalysis(experimentName: String) -> ExperimentAnalysis? {
        queue.sync {
            guard let experiment = activeExperiments.values.first(where: { $0.name == experimentName }),
                  let results = experimentResults[experiment.id] else {
                return nil
            }
            
            return analyzeExperiment(experiment: experiment, results: results)
        }
    }
    
    /// Get all experiments
    func getAllExperiments() -> [Experiment] {
        queue.sync {
            return Array(activeExperiments.values)
        }
    }
    
    /// Stop an experiment
    func stopExperiment(name: String) {
        queue.async(flags: .barrier) {
            if let experiment = self.activeExperiments.values.first(where: { $0.name == name }) {
                self.activeExperiments[experiment.id]?.isActive = false
                print("🛑 Stopped experiment: \(name)")
            }
        }
    }
    
    /// Export experiment results
    func exportResults(experimentName: String) -> Data? {
        queue.sync {
            guard let experiment = activeExperiments.values.first(where: { $0.name == experimentName }),
                  let results = experimentResults[experiment.id] else {
                return nil
            }
            
            let analysis = analyzeExperiment(experiment: experiment, results: results)
            
            let export = ExperimentExport(
                experiment: experiment,
                analysis: analysis,
                results: results
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            return try? encoder.encode(export)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultExperiments() {
        // Experiment 1: Prompt Variants
        let promptVariants = PromptVariant.allCases.map { variant in
            ExperimentVariant(
                id: variant.rawValue,
                name: variant.description,
                configuration: ["promptVariant": variant.rawValue]
            )
        }
        
        createExperiment(
            name: "PromptVariantComparison",
            variants: promptVariants
        )
        
        // Experiment 2: Few-shot Examples
        let exampleVariants = [
            ExperimentVariant(
                id: "with_examples",
                name: "With Few-shot Examples",
                configuration: ["useExamples": true]
            ),
            ExperimentVariant(
                id: "without_examples",
                name: "Without Few-shot Examples",
                configuration: ["useExamples": false]
            )
        ]
        
        createExperiment(
            name: "FewShotExamplesImpact",
            variants: exampleVariants
        )
        
        // Experiment 3: LLM vs Fallback Performance
        let methodVariants = [
            ExperimentVariant(
                id: "llm_primary",
                name: "LLM Primary (with fallback)",
                configuration: ["method": "llm", "fallbackEnabled": true]
            ),
            ExperimentVariant(
                id: "fallback_only",
                name: "Fallback Only",
                configuration: ["method": "fallback"]
            )
        ]
        
        createExperiment(
            name: "ClassificationMethodComparison",
            variants: methodVariants,
            trafficAllocation: ["llm_primary": 0.8, "fallback_only": 0.2]
        )
    }
    
    private func evenTrafficAllocation(for variants: [ExperimentVariant]) -> [String: Double] {
        let allocation = 1.0 / Double(variants.count)
        return Dictionary(uniqueKeysWithValues: variants.map { ($0.id, allocation) })
    }
    
    private func analyzeExperiment(experiment: Experiment, results: [ExperimentResult]) -> ExperimentAnalysis {
        var variantAnalyses: [String: VariantAnalysis] = [:]
        
        for variant in experiment.variants {
            let variantResults = results.filter { $0.variantId == variant.id }
            
            guard !variantResults.isEmpty else {
                variantAnalyses[variant.id] = VariantAnalysis(
                    variantId: variant.id,
                    variantName: variant.name,
                    sampleSize: 0,
                    successRate: 0.0,
                    averageConfidence: 0.0,
                    averageDuration: 0.0,
                    standardDeviation: 0.0
                )
                continue
            }
            
            let successCount = variantResults.filter { $0.success }.count
            let successRate = Double(successCount) / Double(variantResults.count)
            
            let avgConfidence = variantResults.reduce(0.0) { $0 + $1.confidence } / Double(variantResults.count)
            let avgDuration = variantResults.reduce(0.0) { $0 + $1.duration } / Double(variantResults.count)
            
            // Calculate standard deviation
            let confidenceValues = variantResults.map { $0.confidence }
            let stdDev = calculateStandardDeviation(values: confidenceValues)
            
            variantAnalyses[variant.id] = VariantAnalysis(
                variantId: variant.id,
                variantName: variant.name,
                sampleSize: variantResults.count,
                successRate: successRate,
                averageConfidence: avgConfidence,
                averageDuration: avgDuration,
                standardDeviation: stdDev
            )
        }
        
        // Determine winner
        let winner = determineWinner(variantAnalyses: variantAnalyses)
        
        // Calculate statistical significance
        let significance = calculateStatisticalSignificance(variantAnalyses: variantAnalyses)
        
        return ExperimentAnalysis(
            experimentId: experiment.id,
            experimentName: experiment.name,
            startDate: experiment.startDate,
            totalSamples: results.count,
            variantAnalyses: variantAnalyses,
            winner: winner,
            statisticalSignificance: significance,
            recommendations: generateRecommendations(
                experiment: experiment,
                variantAnalyses: variantAnalyses,
                winner: winner,
                significance: significance
            )
        )
    }
    
    private func calculateStandardDeviation(values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        
        return sqrt(variance)
    }
    
    private func determineWinner(variantAnalyses: [String: VariantAnalysis]) -> String? {
        // Winner is determined by highest success rate, with confidence as tiebreaker
        let validAnalyses = variantAnalyses.values.filter { $0.sampleSize >= 30 } // Minimum sample size
        
        guard !validAnalyses.isEmpty else { return nil }
        
        let winner = validAnalyses.max { a, b in
            if abs(a.successRate - b.successRate) < 0.01 {
                return a.averageConfidence < b.averageConfidence
            }
            return a.successRate < b.successRate
        }
        
        return winner?.variantId
    }
    
    private func calculateStatisticalSignificance(variantAnalyses: [String: VariantAnalysis]) -> Double {
        // Simplified statistical significance calculation
        // In production, use proper t-test or chi-square test
        
        let analyses = Array(variantAnalyses.values).filter { $0.sampleSize >= 30 }
        guard analyses.count >= 2 else { return 0.0 }
        
        // Calculate variance between groups
        let meanSuccessRate = analyses.reduce(0.0) { $0 + $1.successRate } / Double(analyses.count)
        let variance = analyses.reduce(0.0) { $0 + pow($1.successRate - meanSuccessRate, 2) } / Double(analyses.count)
        
        // Higher variance = more significant difference
        // This is a simplified metric; use proper statistical tests in production
        return min(variance * 10, 1.0)
    }
    
    private func generateRecommendations(
        experiment: Experiment,
        variantAnalyses: [String: VariantAnalysis],
        winner: String?,
        significance: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        // Check sample sizes
        let minSampleSize = variantAnalyses.values.map { $0.sampleSize }.min() ?? 0
        if minSampleSize < 100 {
            recommendations.append("⚠️ Sample sizes are small. Continue collecting data for more reliable results.")
        }
        
        // Check statistical significance
        if significance < 0.3 {
            recommendations.append("ℹ️ Differences between variants are not statistically significant yet.")
        } else if significance >= 0.3 && significance < 0.7 {
            recommendations.append("✓ Results show moderate statistical significance.")
        } else {
            recommendations.append("✓✓ Results show strong statistical significance.")
        }
        
        // Winner recommendation
        if let winnerId = winner,
           let winnerAnalysis = variantAnalyses[winnerId] {
            recommendations.append("🏆 Winner: \(winnerAnalysis.variantName) with \(String(format: "%.1f%%", winnerAnalysis.successRate * 100)) success rate")
            
            if winnerAnalysis.successRate > 0.9 && significance >= 0.5 {
                recommendations.append("✅ Strong recommendation: Deploy \(winnerAnalysis.variantName) as default")
            }
        }
        
        // Performance recommendations
        let avgDurations = variantAnalyses.values.map { $0.averageDuration }
        if let fastestDuration = avgDurations.min(),
           let slowestDuration = avgDurations.max(),
           slowestDuration > fastestDuration * 2 {
            recommendations.append("⚠️ Significant performance difference detected. Consider the trade-off between accuracy and speed.")
        }
        
        return recommendations
    }
}

// MARK: - A/B Testing Models

struct Experiment: Codable {
    let id: String
    let name: String
    let variants: [ExperimentVariant]
    let trafficAllocation: [String: Double]
    let startDate: Date
    var isActive: Bool
}

struct ExperimentVariant: Codable {
    let id: String
    let name: String
    let configuration: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, name, configuration
    }
    
    init(id: String, name: String, configuration: [String: Any]) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode configuration as dictionary
        let configData = try container.decode([String: String].self, forKey: .configuration)
        configuration = configData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        // Encode configuration - convert Any to String
        let configStrings = configuration.mapValues { "\($0)" }
        try container.encode(configStrings, forKey: .configuration)
    }
}

struct ExperimentResult: Codable {
    let timestamp: Date
    let experimentId: String
    let variantId: String
    let success: Bool
    let confidence: Double
    let duration: TimeInterval
    let fileExtension: String
    let fileSize: Int64
}

struct VariantAnalysis: Codable {
    let variantId: String
    let variantName: String
    let sampleSize: Int
    let successRate: Double
    let averageConfidence: Double
    let averageDuration: TimeInterval
    let standardDeviation: Double
}

struct ExperimentAnalysis: Codable {
    let experimentId: String
    let experimentName: String
    let startDate: Date
    let totalSamples: Int
    let variantAnalyses: [String: VariantAnalysis]
    let winner: String?
    let statisticalSignificance: Double
    let recommendations: [String]
}

struct ExperimentExport: Codable {
    let experiment: Experiment
    let analysis: ExperimentAnalysis
    let results: [ExperimentResult]
}