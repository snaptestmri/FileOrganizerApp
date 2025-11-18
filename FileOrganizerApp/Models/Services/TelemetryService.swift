//
//  TelemetryService.swift
//  File Classification System
//
//  Comprehensive telemetry and analytics service for monitoring
//  classification performance, accuracy, and system health.
//

import Foundation

// MARK: - Telemetry Service

class TelemetryService {
    
    // MARK: - Shared Instance
    
    static let shared = TelemetryService()
    
    // MARK: - Properties
    
    private var events: [TelemetryEvent] = []
    private var aggregatedMetrics: AggregatedMetrics = AggregatedMetrics()
    private let queue = DispatchQueue(label: "com.fileClassification.telemetry", attributes: .concurrent)
    
    private var maxStoredEvents = 1000
    var isEnabled = true
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Record a classification event
    func recordClassification(
        method: ClassificationMethod,
        success: Bool,
        confidence: Double,
        duration: TimeInterval,
        metadata: FileMetadata,
        error: String? = nil
    ) {
        guard isEnabled else { return }
        
        let event = TelemetryEvent(
            timestamp: Date(),
            method: method,
            success: success,
            confidence: confidence,
            duration: duration,
            category: nil,
            subfolder: nil,
            fileExtension: metadata.fileExtension,
            fileSize: metadata.fileSize,
            error: error
        )
        
        queue.async(flags: .barrier) {
            self.events.append(event)
            self.updateAggregatedMetrics(with: event)
            self.pruneOldEventsIfNeeded()
        }
    }
    
    /// Record a completed classification with result
    func recordClassificationResult(
        result: ClassificationResult,
        duration: TimeInterval,
        metadata: FileMetadata
    ) {
        guard isEnabled else { return }
        
        let event = TelemetryEvent(
            timestamp: Date(),
            method: result.method,
            success: true,
            confidence: result.confidence,
            duration: duration,
            category: result.category,
            subfolder: result.subfolder,
            fileExtension: metadata.fileExtension,
            fileSize: metadata.fileSize,
            error: nil
        )
        
        queue.async(flags: .barrier) {
            self.events.append(event)
            self.updateAggregatedMetrics(with: event)
            self.pruneOldEventsIfNeeded()
        }
    }
    
    /// Get current metrics
    func getMetrics() -> TelemetryMetrics {
        queue.sync {
            return TelemetryMetrics(
                totalClassifications: aggregatedMetrics.totalClassifications,
                llmClassifications: aggregatedMetrics.llmClassifications,
                fallbackClassifications: aggregatedMetrics.fallbackClassifications,
                successRate: calculateSuccessRate(),
                averageConfidence: calculateAverageConfidence(),
                averageDuration: calculateAverageDuration(),
                categoryDistribution: aggregatedMetrics.categoryDistribution,
                methodDistribution: aggregatedMetrics.methodDistribution,
                errorRate: calculateErrorRate(),
                recentEvents: Array(events.suffix(10))
            )
        }
    }
    
    /// Get metrics for a specific time period
    func getMetrics(since: Date) -> TelemetryMetrics {
        queue.sync {
            let filteredEvents = events.filter { $0.timestamp >= since }
            return calculateMetrics(from: filteredEvents)
        }
    }
    
    /// Export telemetry data as JSON
    func exportData() -> Data? {
        queue.sync {
            let exportData = TelemetryExport(
                exportDate: Date(),
                totalEvents: events.count,
                metrics: getMetrics(),
                events: events
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            return try? encoder.encode(exportData)
        }
    }
    
    /// Clear all telemetry data
    func clearData() {
        queue.async(flags: .barrier) {
            self.events.removeAll()
            self.aggregatedMetrics = AggregatedMetrics()
        }
    }
    
    /// Get performance report
    func generatePerformanceReport() -> PerformanceReport {
        queue.sync {
            let metrics = getMetrics()
            
            // Calculate additional insights
            let llmSuccessRate = calculateMethodSuccessRate(for: .llm)
            let fallbackSuccessRate = calculateMethodSuccessRate(for: .fallback)
            
            // Identify problem areas
            let lowConfidenceClassifications = events.filter { $0.confidence < 0.7 }.count
            let slowClassifications = events.filter { $0.duration > 5.0 }.count
            
            // Category-specific metrics
            let categoryMetrics = calculateCategoryMetrics()
            
            return PerformanceReport(
                generatedAt: Date(),
                overallMetrics: metrics,
                llmSuccessRate: llmSuccessRate,
                fallbackSuccessRate: fallbackSuccessRate,
                lowConfidenceCount: lowConfidenceClassifications,
                slowClassificationCount: slowClassifications,
                categoryMetrics: categoryMetrics,
                recommendations: generateRecommendations(metrics: metrics)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func updateAggregatedMetrics(with event: TelemetryEvent) {
        aggregatedMetrics.totalClassifications += 1
        
        switch event.method {
        case .llm:
            aggregatedMetrics.llmClassifications += 1
        case .fallback:
            aggregatedMetrics.fallbackClassifications += 1
        case .hybrid:
            break
        }
        
        if let category = event.category {
            aggregatedMetrics.categoryDistribution[category, default: 0] += 1
        }
        
        aggregatedMetrics.methodDistribution[event.method.rawValue, default: 0] += 1
        
        if event.success {
            aggregatedMetrics.successfulClassifications += 1
        } else {
            aggregatedMetrics.failedClassifications += 1
        }
        
        aggregatedMetrics.totalConfidence += event.confidence
        aggregatedMetrics.totalDuration += event.duration
    }
    
    private func pruneOldEventsIfNeeded() {
        if events.count > maxStoredEvents {
            let excess = events.count - maxStoredEvents
            events.removeFirst(excess)
        }
    }
    
    private func calculateSuccessRate() -> Double {
        guard aggregatedMetrics.totalClassifications > 0 else { return 0.0 }
        return Double(aggregatedMetrics.successfulClassifications) / Double(aggregatedMetrics.totalClassifications)
    }
    
    private func calculateAverageConfidence() -> Double {
        guard aggregatedMetrics.totalClassifications > 0 else { return 0.0 }
        return aggregatedMetrics.totalConfidence / Double(aggregatedMetrics.totalClassifications)
    }
    
    private func calculateAverageDuration() -> TimeInterval {
        guard aggregatedMetrics.totalClassifications > 0 else { return 0.0 }
        return aggregatedMetrics.totalDuration / Double(aggregatedMetrics.totalClassifications)
    }
    
    private func calculateErrorRate() -> Double {
        guard aggregatedMetrics.totalClassifications > 0 else { return 0.0 }
        return Double(aggregatedMetrics.failedClassifications) / Double(aggregatedMetrics.totalClassifications)
    }
    
    private func calculateMethodSuccessRate(for method: ClassificationMethod) -> Double {
        let methodEvents = events.filter { $0.method == method }
        guard !methodEvents.isEmpty else { return 0.0 }
        
        let successfulEvents = methodEvents.filter { $0.success }.count
        return Double(successfulEvents) / Double(methodEvents.count)
    }
    
    private func calculateCategoryMetrics() -> [String: CategoryMetrics] {
        var categoryMetrics: [String: CategoryMetrics] = [:]
        
        for category in ["Media", "Projects", "Documents", "Archive"] {
            let categoryEvents = events.filter { $0.category == category }
            
            guard !categoryEvents.isEmpty else { continue }
            
            let avgConfidence = categoryEvents.reduce(0.0) { $0 + $1.confidence } / Double(categoryEvents.count)
            let avgDuration = categoryEvents.reduce(0.0) { $0 + $1.duration } / Double(categoryEvents.count)
            let successRate = Double(categoryEvents.filter { $0.success }.count) / Double(categoryEvents.count)
            
            categoryMetrics[category] = CategoryMetrics(
                count: categoryEvents.count,
                averageConfidence: avgConfidence,
                averageDuration: avgDuration,
                successRate: successRate
            )
        }
        
        return categoryMetrics
    }
    
    private func calculateMetrics(from events: [TelemetryEvent]) -> TelemetryMetrics {
        let totalCount = events.count
        let llmCount = events.filter { $0.method == .llm }.count
        let fallbackCount = events.filter { $0.method == .fallback }.count
        let successCount = events.filter { $0.success }.count
        
        let avgConfidence = events.isEmpty ? 0.0 : events.reduce(0.0) { $0 + $1.confidence } / Double(totalCount)
        let avgDuration = events.isEmpty ? 0.0 : events.reduce(0.0) { $0 + $1.duration } / Double(totalCount)
        let successRate = totalCount > 0 ? Double(successCount) / Double(totalCount) : 0.0
        let errorRate = totalCount > 0 ? Double(totalCount - successCount) / Double(totalCount) : 0.0
        
        var categoryDistribution: [String: Int] = [:]
        var methodDistribution: [String: Int] = [:]
        
        for event in events {
            if let category = event.category {
                categoryDistribution[category, default: 0] += 1
            }
            methodDistribution[event.method.rawValue, default: 0] += 1
        }
        
        return TelemetryMetrics(
            totalClassifications: totalCount,
            llmClassifications: llmCount,
            fallbackClassifications: fallbackCount,
            successRate: successRate,
            averageConfidence: avgConfidence,
            averageDuration: avgDuration,
            categoryDistribution: categoryDistribution,
            methodDistribution: methodDistribution,
            errorRate: errorRate,
            recentEvents: Array(events.suffix(10))
        )
    }
    
    private func generateRecommendations(metrics: TelemetryMetrics) -> [String] {
        var recommendations: [String] = []
        
        // Check success rate
        if metrics.successRate < 0.9 {
            recommendations.append("⚠️ Success rate is below 90%. Consider reviewing fallback rules.")
        }
        
        // Check confidence
        if metrics.averageConfidence < 0.8 {
            recommendations.append("⚠️ Average confidence is low. Consider improving prompt quality or adding more examples.")
        }
        
        // Check LLM usage
        let llmUsageRate = Double(metrics.llmClassifications) / Double(metrics.totalClassifications)
        if llmUsageRate < 0.5 {
            recommendations.append("ℹ️ LLM is being used less than 50% of the time. Consider investigating LLM availability.")
        }
        
        // Check duration
        if metrics.averageDuration > 3.0 {
            recommendations.append("⚠️ Average classification duration exceeds 3 seconds. Consider optimizing LLM calls or prompt size.")
        }
        
        // Check error rate
        if metrics.errorRate > 0.1 {
            recommendations.append("⚠️ Error rate exceeds 10%. Review error logs for patterns.")
        }
        
        if recommendations.isEmpty {
            recommendations.append("✅ All metrics are within acceptable ranges.")
        }
        
        return recommendations
    }
}

// MARK: - Telemetry Models

struct TelemetryEvent: Codable {
    let timestamp: Date
    let method: ClassificationMethod
    let success: Bool
    let confidence: Double
    let duration: TimeInterval
    let category: String?
    let subfolder: String?
    let fileExtension: String
    let fileSize: Int64
    let error: String?
}

struct AggregatedMetrics {
    var totalClassifications = 0
    var llmClassifications = 0
    var fallbackClassifications = 0
    var successfulClassifications = 0
    var failedClassifications = 0
    var totalConfidence = 0.0
    var totalDuration = 0.0
    var categoryDistribution: [String: Int] = [:]
    var methodDistribution: [String: Int] = [:]
}

struct TelemetryMetrics: Codable {
    let totalClassifications: Int
    let llmClassifications: Int
    let fallbackClassifications: Int
    let successRate: Double
    let averageConfidence: Double
    let averageDuration: TimeInterval
    let categoryDistribution: [String: Int]
    let methodDistribution: [String: Int]
    let errorRate: Double
    let recentEvents: [TelemetryEvent]
}

struct CategoryMetrics: Codable {
    let count: Int
    let averageConfidence: Double
    let averageDuration: TimeInterval
    let successRate: Double
}

struct PerformanceReport: Codable {
    let generatedAt: Date
    let overallMetrics: TelemetryMetrics
    let llmSuccessRate: Double
    let fallbackSuccessRate: Double
    let lowConfidenceCount: Int
    let slowClassificationCount: Int
    let categoryMetrics: [String: CategoryMetrics]
    let recommendations: [String]
}

struct TelemetryExport: Codable {
    let exportDate: Date
    let totalEvents: Int
    let metrics: TelemetryMetrics
    let events: [TelemetryEvent]
}