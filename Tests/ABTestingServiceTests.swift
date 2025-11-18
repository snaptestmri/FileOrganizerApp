import XCTest
import Foundation
@testable import FileOrganizerApp

/// Tests for ABTestingService
final class ABTestingServiceTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Clear any existing experiments
        let service = ABTestingService.shared
        service.isEnabled = true
    }
    
    override func tearDownWithError() throws {
        // Clean up experiments
        let service = ABTestingService.shared
        let experiments = service.getAllExperiments()
        for experiment in experiments {
            service.stopExperiment(name: experiment.name)
        }
        try super.tearDownWithError()
    }
    
    // MARK: - Experiment Creation Tests
    
    func testCreateExperiment() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: ["param": "valueA"]
            ),
            ExperimentVariant(
                id: "variant_b",
                name: "Variant B",
                configuration: ["param": "valueB"]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let experiments = service.getAllExperiments()
        XCTAssertTrue(experiments.contains { $0.name == "TestExperiment" })
    }
    
    func testGetVariant() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: ["param": "valueA"]
            ),
            ExperimentVariant(
                id: "variant_b",
                name: "Variant B",
                configuration: ["param": "valueB"]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let variant = service.getVariant(experimentName: "TestExperiment")
        XCTAssertNotNil(variant)
        XCTAssertTrue(variant?.id == "variant_a" || variant?.id == "variant_b")
    }
    
    func testGetVariantWhenDisabled() {
        let service = ABTestingService.shared
        service.isEnabled = false
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let variant = service.getVariant(experimentName: "TestExperiment")
        XCTAssertNil(variant, "Should return nil when service is disabled")
    }
    
    // MARK: - Result Recording Tests
    
    func testRecordResult() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let metadata = FileMetadata(
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "test",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        service.recordResult(
            experimentName: "TestExperiment",
            variantId: "variant_a",
            success: true,
            confidence: 0.9,
            duration: 1.5,
            metadata: metadata
        )
        
        // Give it a moment to process
        Thread.sleep(forTimeInterval: 0.1)
        
        let analysis = service.getExperimentAnalysis(experimentName: "TestExperiment")
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis?.totalSamples, 1)
    }
    
    // MARK: - Analysis Tests
    
    func testGetExperimentAnalysis() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            ),
            ExperimentVariant(
                id: "variant_b",
                name: "Variant B",
                configuration: [:]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let metadata = FileMetadata(
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "test",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        // Record multiple results
        for i in 0..<10 {
            service.recordResult(
                experimentName: "TestExperiment",
                variantId: i % 2 == 0 ? "variant_a" : "variant_b",
                success: true,
                confidence: 0.8 + Double(i) * 0.02,
                duration: Double(i) * 0.1,
                metadata: metadata
            )
        }
        
        // Give it a moment to process
        Thread.sleep(forTimeInterval: 0.2)
        
        let analysis = service.getExperimentAnalysis(experimentName: "TestExperiment")
        XCTAssertNotNil(analysis)
        XCTAssertEqual(analysis?.totalSamples, 10)
        XCTAssertNotNil(analysis?.variantAnalyses)
        XCTAssertEqual(analysis?.variantAnalyses.count, 2)
    }
    
    // MARK: - Experiment Management Tests
    
    func testStopExperiment() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        service.stopExperiment(name: "TestExperiment")
        
        let variant = service.getVariant(experimentName: "TestExperiment")
        XCTAssertNil(variant, "Should return nil for stopped experiment")
    }
    
    func testExportResults() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            )
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants
        )
        
        let metadata = FileMetadata(
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "test",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        service.recordResult(
            experimentName: "TestExperiment",
            variantId: "variant_a",
            success: true,
            confidence: 0.9,
            duration: 1.5,
            metadata: metadata
        )
        
        // Give it a moment to process
        Thread.sleep(forTimeInterval: 0.1)
        
        let exportData = service.exportResults(experimentName: "TestExperiment")
        XCTAssertNotNil(exportData, "Should export experiment results as JSON")
        
        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: exportData!)
        XCTAssertNotNil(json)
    }
    
    // MARK: - Traffic Allocation Tests
    
    func testTrafficAllocation() {
        let service = ABTestingService.shared
        
        let variants = [
            ExperimentVariant(
                id: "variant_a",
                name: "Variant A",
                configuration: [:]
            ),
            ExperimentVariant(
                id: "variant_b",
                name: "Variant B",
                configuration: [:]
            )
        ]
        
        let trafficAllocation = [
            "variant_a": 0.7,
            "variant_b": 0.3
        ]
        
        service.createExperiment(
            name: "TestExperiment",
            variants: variants,
            trafficAllocation: trafficAllocation
        )
        
        // Get variant multiple times to test distribution
        var variantACount = 0
        var variantBCount = 0
        
        for _ in 0..<100 {
            if let variant = service.getVariant(experimentName: "TestExperiment") {
                if variant.id == "variant_a" {
                    variantACount += 1
                } else if variant.id == "variant_b" {
                    variantBCount += 1
                }
            }
        }
        
        // With 70/30 split, we should see roughly that distribution
        // Allow some variance for randomness
        XCTAssertGreaterThan(variantACount, 50, "Variant A should be selected more often")
        XCTAssertGreaterThan(variantBCount, 10, "Variant B should be selected sometimes")
    }
}

