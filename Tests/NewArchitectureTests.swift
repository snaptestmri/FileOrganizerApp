import XCTest
import Foundation
@testable import FileOrganizerApp

/// Tests for the new architecture: FileClassificationManager, FallbackClassifier, TelemetryService, etc.
final class NewArchitectureTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewArchitectureTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        TelemetryService.shared.clearData()
        try super.tearDownWithError()
    }
    
    // MARK: - FallbackClassifier Tests
    
    func testFallbackClassifierBasic() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata(
            fileName: "invoice_2024.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "invoice_2024",
            fullPath: nil,
            parentFolder: "Documents",
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: "com.adobe.pdf",
            mimeType: "application/pdf",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 1,
            commonPatterns: ["contains_date"],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: "invoice",
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = classifier.classify(metadata)
        
        XCTAssertEqual(result.category, "Finance")
        XCTAssertEqual(result.subfolder, "Bills")
        XCTAssertEqual(result.method, ClassificationMethod.fallback)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertNotNil(result.reasoning)
    }
    
    func testFallbackClassifierImage() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata(
            fileName: "photo.jpg",
            fileExtension: "jpg",
            fileNameWithoutExtension: "photo",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 2048000,
            fileSizeFormatted: "2 MB",
            creationDate: nil,
            modificationDate: nil,
            fileType: "public.jpeg",
            mimeType: "image/jpeg",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = classifier.classify(metadata)
        
        XCTAssertEqual(result.category, "Media")
        XCTAssertEqual(result.subfolder, "Photos")
        XCTAssertEqual(result.method, ClassificationMethod.fallback)
    }
    
    func testFallbackClassifier3DModel() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata(
            fileName: "model.stl",
            fileExtension: "stl",
            fileNameWithoutExtension: "model",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024000,
            fileSizeFormatted: "1 MB",
            creationDate: nil,
            modificationDate: nil,
            fileType: "public.3d-model",
            mimeType: "model/stl",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = classifier.classify(metadata)
        
        XCTAssertEqual(result.category, "Projects")
        XCTAssertEqual(result.subfolder, "Code")
        XCTAssertEqual(result.method, ClassificationMethod.fallback)
    }

    func testFallbackClassifierPreviewIntentWhenFilenameAmbiguous() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata.forTest(
            fileName: "document_2024.pdf",
            fileExtension: "pdf",
            contentPreview: "Form 1040 U.S. Individual Income Tax Return Department of the Treasury",
            hasTextContent: true,
            detectedIntent: nil
        )

        let result = classifier.classify(metadata)

        XCTAssertEqual(result.category, "Finance")
        XCTAssertEqual(result.subfolder, "Taxes")
        XCTAssertTrue(result.reasoning?.contains("preview intent") ?? false)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.58)
        XCTAssertLessThan(result.confidence, 0.95)
    }

    func testFallbackClassifierPreviewRoutesPMTopicsToCareer() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata.forTest(
            fileName: "A PMs Guide to Wireframes and Prototypes.pdf",
            fileExtension: "pdf",
            contentPreview: "Product management fundamentals: wireframes and prototypes for PM teams.",
            hasTextContent: true,
            detectedIntent: nil
        )

        let result = classifier.classify(metadata)

        XCTAssertEqual(result.category, "Career")
        XCTAssertEqual(result.subfolder, "Books")
        XCTAssertTrue(result.reasoning?.contains("preview intent") ?? false)
    }

    func testFallbackClassifierFilenameIntentBeatsPreview() {
        let classifier = FallbackClassifier()
        let metadata = FileMetadata.forTest(
            fileName: "invoice_march.pdf",
            fileExtension: "pdf",
            contentPreview: "This textbook chapter covers university admissions.",
            hasTextContent: true,
            detectedIntent: "invoice"
        )

        let result = classifier.classify(metadata)

        XCTAssertEqual(result.category, "Finance")
        XCTAssertEqual(result.subfolder, "Bills")
        XCTAssertTrue(result.reasoning?.contains("filename intent") ?? false)
    }

    func testDetectIntentInPreviewText() {
        XCTAssertEqual(
            FileMetadata.detectIntent(in: "Consulate General visa appointment confirmation"),
            "immigration"
        )
        XCTAssertEqual(
            FileMetadata.detectIntent(
                in: "Become an expert in A/B testing and split test experimentation for product teams",
                treatAsFilename: false
            ),
            "book"
        )
    }
    
    func testFallbackClassifierDetermineCategoryFromExtension() {
        let classifier = FallbackClassifier()
        
        XCTAssertEqual(classifier.determineCategoryFromExtension("pdf"), "Documents")
        XCTAssertEqual(classifier.determineCategoryFromExtension("jpg"), "Media")
        XCTAssertEqual(classifier.determineCategoryFromExtension("stl"), "Projects")
        // Archives are classified by content - test with a design-related archive
        XCTAssertEqual(classifier.determineCategoryFromExtension("zip", fileName: "vector_assets.zip"), "Projects")
        // Generic archive goes to Documents
        XCTAssertEqual(classifier.determineCategoryFromExtension("zip", fileName: "backup.zip"), "Documents")
    }
    
    // MARK: - FileClassificationManager Tests
    
    func testFileClassificationManagerWithStubLLM() async {
        let stub = StubLLMService.fast()
        stub.fixedResponse = """
        {"category": "Finance", "subfolder": "Bills", "confidence": 0.95, "reasoning": "PDF file with invoice in name"}
        """
        
        let manager = FileClassificationManager(
            llmService: stub,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        
        let metadata = FileMetadata(
            fileName: "invoice.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "invoice",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: "application/pdf",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: "invoice",
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = await manager.classifyFile(metadata)
        
        XCTAssertEqual(result.category, "Finance")
        XCTAssertEqual(result.subfolder, "Bills")
        XCTAssertEqual(result.method, ClassificationMethod.llm)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    func testFileClassificationManagerFallbackOnLLMFailure() async {
        let manager = FileClassificationManager(
            llmService: FailingLLMService(),
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        manager.useFallbackOnFailure = true
        
        let metadata = FileMetadata(
            fileName: "photo.jpg",
            fileExtension: "jpg",
            fileNameWithoutExtension: "photo",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: "image/jpeg",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let result = await manager.classifyFile(metadata)
        
        // Should fallback to rule-based classification
        XCTAssertEqual(result.category, "Media")
        XCTAssertEqual(result.subfolder, "Photos")
        XCTAssertEqual(result.method, ClassificationMethod.fallback)
    }
    
    func testFileClassificationManagerBatch() async {
        let stub = StubLLMService.fast()
        stub.fixedResponse = """
        {"category": "Personal", "subfolder": "General", "confidence": 0.9, "reasoning": "default"}
        """
        
        let manager = FileClassificationManager(
            llmService: stub,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        
        let files = [
            FileMetadata(
                fileName: "file1.pdf",
                fileExtension: "pdf",
                fileNameWithoutExtension: "file1",
                fullPath: nil,
                parentFolder: nil,
                fileSize: 1024,
                fileSizeFormatted: "1 KB",
                creationDate: nil,
                modificationDate: nil,
                fileType: nil,
                mimeType: "application/pdf",
                isDirectory: false,
                isHidden: false,
                isPackage: false,
                contentPreview: nil,
                hasTextContent: false,
                siblingFiles: nil,
                folderDepth: 0,
                commonPatterns: [],
                isProjectDirectory: false,
                hasTemporalName: false,
                detectedIntent: nil,
                author: nil,
                keywords: nil,
                whereFrom: nil
            ),
            FileMetadata(
                fileName: "file2.jpg",
                fileExtension: "jpg",
                fileNameWithoutExtension: "file2",
                fullPath: nil,
                parentFolder: nil,
                fileSize: 2048,
                fileSizeFormatted: "2 KB",
                creationDate: nil,
                modificationDate: nil,
                fileType: nil,
                mimeType: "image/jpeg",
                isDirectory: false,
                isHidden: false,
                isPackage: false,
                contentPreview: nil,
                hasTextContent: false,
                siblingFiles: nil,
                folderDepth: 0,
                commonPatterns: [],
                isProjectDirectory: false,
                hasTemporalName: false,
                detectedIntent: nil,
                author: nil,
                keywords: nil,
                whereFrom: nil
            )
        ]
        
        let results = await manager.classifyFiles(files)
        
        XCTAssertEqual(results.count, files.count)
        for result in results {
            XCTAssertFalse(result.category.isEmpty)
            XCTAssertFalse(result.subfolder.isEmpty)
        }
    }
    
    // MARK: - TelemetryService Tests
    
    func testTelemetryServiceRecordClassification() {
        let telemetry = TelemetryService.shared
        telemetry.clearData()
        
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
            mimeType: "application/pdf",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        telemetry.recordClassification(
            method: .llm,
            success: true,
            confidence: 0.9,
            duration: 1.5,
            metadata: metadata
        )
        
        let metrics = telemetry.getMetrics()
        XCTAssertEqual(metrics.totalClassifications, 1)
        XCTAssertEqual(metrics.llmClassifications, 1)
        XCTAssertEqual(metrics.successRate, 1.0, accuracy: 0.01)
    }
    
    func testTelemetryServiceRecordClassificationResult() {
        let telemetry = TelemetryService.shared
        telemetry.clearData()
        
        let result = ClassificationResult(
            category: "Documents",
            subfolder: "Invoices",
            confidence: 0.95,
            reasoning: "test",
            method: .llm
        )
        
        let metadata = FileMetadata(
            fileName: "invoice.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "invoice",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: "application/pdf",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        telemetry.recordClassificationResult(
            result: result,
            duration: 2.0,
            metadata: metadata
        )
        
        let metrics = telemetry.getMetrics()
        XCTAssertEqual(metrics.totalClassifications, 1)
        XCTAssertEqual(metrics.averageConfidence, 0.95, accuracy: 0.01)
    }
    
    func testTelemetryServicePerformanceReport() {
        let telemetry = TelemetryService.shared
        telemetry.clearData()
        
        // Add some test data
        for i in 0..<10 {
            let metadata = FileMetadata(
                fileName: "file\(i).pdf",
                fileExtension: "pdf",
                fileNameWithoutExtension: "file\(i)",
                fullPath: nil,
                parentFolder: nil,
                fileSize: Int64(i * 1024),
                fileSizeFormatted: "\(i) KB",
                creationDate: nil,
                modificationDate: nil,
                fileType: nil,
                mimeType: "application/pdf",
                isDirectory: false,
                isHidden: false,
                isPackage: false,
                contentPreview: nil,
                hasTextContent: false,
                siblingFiles: nil,
                folderDepth: 0,
                commonPatterns: [],
                isProjectDirectory: false,
                hasTemporalName: false,
                detectedIntent: nil,
                author: nil,
                keywords: nil,
                whereFrom: nil
            )
            
            telemetry.recordClassification(
                method: i % 2 == 0 ? .llm : .fallback,
                success: true,
                confidence: 0.8 + Double(i) * 0.02,
                duration: Double(i) * 0.1,
                metadata: metadata
            )
        }
        
        let report = telemetry.generatePerformanceReport()
        
        XCTAssertEqual(report.overallMetrics.totalClassifications, 10)
        XCTAssertGreaterThan(report.overallMetrics.averageConfidence, 0.0)
        XCTAssertFalse(report.recommendations.isEmpty)
    }
    
    // MARK: - ClassificationPromptBuilder Tests
    
    func testClassificationPromptBuilderStandard() {
        let builder = ClassificationPromptBuilder()
        builder.promptVariant = .standard
        builder.useExamples = true
        
        let metadata = FileMetadata(
            fileName: "invoice.pdf",
            fileExtension: "pdf",
            fileNameWithoutExtension: "invoice",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: "application/pdf",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let prompt = builder.buildPrompt(metadata: metadata, preCategory: "Documents")
        
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("invoice.pdf"))
        XCTAssertTrue(prompt.contains("TAXONOMY"))
        XCTAssertTrue(prompt.contains("Finance"))
    }
    
    func testClassificationPromptBuilderConcise() {
        let builder = ClassificationPromptBuilder()
        builder.promptVariant = .concise
        
        let metadata = FileMetadata(
            fileName: "photo.jpg",
            fileExtension: "jpg",
            fileNameWithoutExtension: "photo",
            fullPath: nil,
            parentFolder: nil,
            fileSize: 1024,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: "image/jpeg",
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: nil,
            folderDepth: 0,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
        
        let prompt = builder.buildPrompt(metadata: metadata, preCategory: nil)
        
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("photo.jpg"))
    }
    
    // MARK: - ClassificationConstants Tests
    
    func testClassificationConstantsValidCategories() {
        XCTAssertTrue(ClassificationConstants.isValidPersonalCategory("Career"))
        XCTAssertTrue(ClassificationConstants.isValidPersonalCategory("Finance"))
        XCTAssertTrue(ClassificationConstants.isValidPersonalCategory("Media"))
        XCTAssertFalse(ClassificationConstants.isValidPersonalCategory("Documents"))
        XCTAssertFalse(ClassificationConstants.isValidPersonalCategory("Invalid"))
    }
    
    func testClassificationConstantsValidSubfolders() {
        XCTAssertTrue(ClassificationConstants.isValidPersonalSubfolder("Resumes", for: "Career"))
        XCTAssertTrue(ClassificationConstants.isValidPersonalSubfolder("Code", for: "Projects"))
        XCTAssertTrue(ClassificationConstants.isValidPersonalSubfolder("Taxes", for: "Finance"))
        XCTAssertFalse(ClassificationConstants.isValidPersonalSubfolder("Invoices", for: "Finance"))
    }
    
    func testClassificationConstantsGetCategoryForExtension() {
        XCTAssertEqual(ClassificationConstants.getCategoryForExtension("jpg"), "Media")
        XCTAssertEqual(ClassificationConstants.getCategoryForExtension("pdf"), "Documents")
        XCTAssertEqual(ClassificationConstants.getCategoryForExtension("stl"), "Projects")
        // Archives no longer have a fixed category - they're classified by content
        XCTAssertNil(ClassificationConstants.getCategoryForExtension("zip"))
        XCTAssertNil(ClassificationConstants.getCategoryForExtension("unknown"))
    }
}

