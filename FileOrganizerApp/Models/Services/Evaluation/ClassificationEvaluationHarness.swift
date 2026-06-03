//
//  ClassificationEvaluationHarness.swift
//  File Organizer App
//
//  Shared runner for compare, tuning, and labeled-accuracy evaluation.
//

import Foundation

// MARK: - Classification Evaluation Harness

final class ClassificationEvaluationHarness {

    private let fileManager = FileManager.default

    // MARK: - File discovery

    /// Discovers files to evaluate from `config`, creating sample fixtures when needed.
    func discoverFiles(config: EvaluationConfig) throws -> EvaluationFileSet {
        if let folderPath = config.resolvedFolderPath(),
           fileManager.fileExists(atPath: folderPath) {
            let folderURL = URL(fileURLWithPath: folderPath)
            let urls = try collectFiles(from: folderURL, maxFiles: config.maxFiles)
            if !urls.isEmpty {
                return EvaluationFileSet(
                    urls: urls,
                    sourceDescription: folderPath,
                    cleanupDirectory: nil
                )
            }
            if config.useSampleFixturesWhenEmpty {
                let fixtures = try createSampleFixtures(maxFiles: config.maxFiles)
                return EvaluationFileSet(
                    urls: fixtures.urls,
                    sourceDescription: "\(folderPath) (empty — sample fixtures)",
                    cleanupDirectory: fixtures.cleanupDirectory
                )
            }
            return EvaluationFileSet(urls: [], sourceDescription: folderPath, cleanupDirectory: nil)
        }

        if config.useSampleFixturesWhenEmpty {
            let fixtures = try createSampleFixtures(maxFiles: config.maxFiles)
            return EvaluationFileSet(
                urls: fixtures.urls,
                sourceDescription: fixtures.cleanupDirectory?.path ?? "sample fixtures",
                cleanupDirectory: fixtures.cleanupDirectory
            )
        }

        let described = config.resolvedFolderPath() ?? "no folder"
        return EvaluationFileSet(urls: [], sourceDescription: described, cleanupDirectory: nil)
    }

    // MARK: - Evaluation runs

    /// Classifies each file with an LLM-backed `FileClassificationManager`.
    func evaluate(
        fileSet: EvaluationFileSet,
        config: EvaluationConfig,
        llmService: LLMService,
        expectedByFileName: [String: ExpectedLabel] = [:],
        enableTelemetry: Bool = false
    ) async -> EvaluationReport {
        let manager = config.makeClassificationManager(
            llmService: llmService,
            enableTelemetry: enableTelemetry
        )
        return await run(
            fileSet: fileSet,
            config: config,
            classify: { metadata in
                await manager.classifyFile(metadata)
            },
            expectedByFileName: expectedByFileName
        )
    }

    /// Classifies each file using only `FallbackClassifier` (no LLM).
    func evaluateFallbackOnly(
        fileSet: EvaluationFileSet,
        config: EvaluationConfig,
        fallbackClassifier: FallbackClassifier = FallbackClassifier(),
        expectedByFileName: [String: ExpectedLabel] = [:]
    ) async -> EvaluationReport {
        var fallbackConfig = config
        fallbackConfig.runLabel = config.runLabel.isEmpty ? "fallback" : config.runLabel

        return await run(
            fileSet: fileSet,
            config: fallbackConfig,
            classify: { metadata in
                fallbackClassifier.classify(metadata)
            },
            expectedByFileName: expectedByFileName
        )
    }

    /// End-to-end: discover files, evaluate with LLM, return report.
    func evaluateDiscoveredFiles(
        config: EvaluationConfig,
        llmService: LLMService,
        expectedByFileName: [String: ExpectedLabel] = [:],
        enableTelemetry: Bool = false
    ) async throws -> (report: EvaluationReport, fileSet: EvaluationFileSet) {
        let fileSet = try discoverFiles(config: config)
        let report = await evaluate(
            fileSet: fileSet,
            config: config,
            llmService: llmService,
            expectedByFileName: expectedByFileName,
            enableTelemetry: enableTelemetry
        )
        return (report, fileSet)
    }

    // MARK: - Classifier comparison (phase 1)

    /// Resolves which backends to run: fallback always; ollama/openai when available.
    func resolveComparisonBackends(
        requested: [ClassifierBackend]? = nil,
        includeOpenAI: Bool = true
    ) async -> (used: [ClassifierBackend], skipped: [ClassifierBackend]) {
        let candidates = requested ?? ClassifierBackend.allCases
        var used: [ClassifierBackend] = []
        var skipped: [ClassifierBackend] = []

        for backend in candidates.sorted() {
            switch backend {
            case .fallback:
                used.append(backend)
            case .ollama:
                if await Self.isOllamaAvailable() {
                    used.append(backend)
                } else {
                    skipped.append(backend)
                }
            case .openai:
                if includeOpenAI, EvaluationConfig.resolvedOpenAIAPIKey() != nil {
                    used.append(backend)
                } else {
                    skipped.append(backend)
                }
            }
        }
        return (used, skipped)
    }

    /// Classifies each file with every available backend and records agreements.
    func compareClassifiers(
        fileSet: EvaluationFileSet,
        config: EvaluationConfig,
        backends requestedBackends: [ClassifierBackend]? = nil,
        includeOpenAI: Bool = true
    ) async -> ClassifierComparisonReport {
        let (backendsUsed, backendsSkipped) = await resolveComparisonBackends(
            requested: requestedBackends,
            includeOpenAI: includeOpenAI
        )

        let fallbackClassifier = FallbackClassifier()
        var rows: [ClassifierComparisonRow] = []

        for fileURL in fileSet.urls {
            let fileName = fileURL.lastPathComponent
            let path = fileURL.path

            guard let metadata = FileMetadata.extract(
                from: fileURL,
                includePreview: config.includePreview,
                maxPreviewLength: config.maxPreviewLength
            ) else {
                let errorResults = backendsUsed.map { backend in
                    ClassifierRunResult(
                        backend: backend,
                        category: "",
                        subfolder: "",
                        confidence: 0,
                        method: .fallback,
                        durationMs: 0,
                        reasoning: nil,
                        error: "Could not extract metadata"
                    )
                }
                rows.append(ClassifierComparisonRow(
                    fileName: fileName,
                    filePath: path,
                    results: errorResults
                ))
                continue
            }

            var runResults: [ClassifierRunResult] = []
            for backend in backendsUsed {
                let runResult = await classifyWithBackend(
                    backend,
                    metadata: metadata,
                    config: config,
                    fallbackClassifier: fallbackClassifier
                )
                runResults.append(runResult)
            }

            rows.append(ClassifierComparisonRow(
                fileName: fileName,
                filePath: path,
                results: runResults
            ))
        }

        return ClassifierComparisonReport(
            config: config,
            sourceDescription: fileSet.sourceDescription,
            generatedAt: Date(),
            backendsUsed: backendsUsed,
            backendsSkipped: backendsSkipped,
            rows: rows
        )
    }

    /// Discover files and compare classifiers in one step.
    func compareDiscoveredClassifiers(
        config: EvaluationConfig,
        backends: [ClassifierBackend]? = nil,
        includeOpenAI: Bool = true
    ) async throws -> (report: ClassifierComparisonReport, fileSet: EvaluationFileSet) {
        let fileSet = try discoverFiles(config: config)
        let report = await compareClassifiers(
            fileSet: fileSet,
            config: config,
            backends: backends,
            includeOpenAI: includeOpenAI
        )
        return (report, fileSet)
    }

    private func classifyWithBackend(
        _ backend: ClassifierBackend,
        metadata: FileMetadata,
        config: EvaluationConfig,
        fallbackClassifier: FallbackClassifier
    ) async -> ClassifierRunResult {
        var backendConfig = config
        backendConfig.runLabel = backend.rawValue

        let start = Date()
        switch backend {
        case .fallback:
            let result = fallbackClassifier.classify(metadata)
            return ClassifierRunResult(
                backend: backend,
                category: result.category,
                subfolder: result.subfolder,
                confidence: result.confidence,
                method: result.method,
                durationMs: Date().timeIntervalSince(start) * 1000,
                reasoning: result.reasoning,
                error: nil
            )

        case .ollama:
            let manager = backendConfig.makeClassificationManager(llmService: backendConfig.makeOllamaService())
            let result = await manager.classifyFile(metadata)
            return makeRunResult(backend: backend, result: result, start: start, error: nil)

        case .openai:
            guard let apiKey = EvaluationConfig.resolvedOpenAIAPIKey() else {
                return skippedResult(backend: backend)
            }
            let manager = backendConfig.makeClassificationManager(
                llmService: OpenAILLMService(apiKey: apiKey, model: "gpt-4", maxTokens: 500)
            )
            let result = await manager.classifyFile(metadata)
            return makeRunResult(backend: backend, result: result, start: start, error: nil)
        }
    }

    private func makeRunResult(
        backend: ClassifierBackend,
        result: ClassificationResult,
        start: Date,
        error: String?
    ) -> ClassifierRunResult {
        ClassifierRunResult(
            backend: backend,
            category: result.category,
            subfolder: result.subfolder,
            confidence: result.confidence,
            method: result.method,
            durationMs: Date().timeIntervalSince(start) * 1000,
            reasoning: result.reasoning,
            error: error
        )
    }

    private func skippedResult(backend: ClassifierBackend) -> ClassifierRunResult {
        ClassifierRunResult(
            backend: backend,
            category: "",
            subfolder: "",
            confidence: 0,
            method: .fallback,
            durationMs: 0,
            reasoning: nil,
            error: "skipped"
        )
    }

    // MARK: - Ollama availability

    static func isOllamaAvailable(timeout: TimeInterval = 2.0) async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func run(
        fileSet: EvaluationFileSet,
        config: EvaluationConfig,
        classify: (FileMetadata) async -> ClassificationResult,
        expectedByFileName: [String: ExpectedLabel]
    ) async -> EvaluationReport {
        var rows: [EvaluationRow] = []
        let runLabel = config.runLabel

        for fileURL in fileSet.urls {
            let fileName = fileURL.lastPathComponent
            let path = fileURL.path

            guard let metadata = FileMetadata.extract(
                from: fileURL,
                includePreview: config.includePreview,
                maxPreviewLength: config.maxPreviewLength
            ) else {
                rows.append(EvaluationRow(
                    fileName: fileName,
                    filePath: path,
                    result: ClassificationResult(
                        category: "",
                        subfolder: "",
                        confidence: 0,
                        reasoning: nil,
                        method: .fallback
                    ),
                    durationMs: 0,
                    error: "Could not extract metadata",
                    expected: expectedByFileName[fileName]
                ))
                continue
            }

            let start = Date()
            let result = await classify(metadata)
            let durationMs = Date().timeIntervalSince(start) * 1000

            rows.append(EvaluationRow(
                fileName: fileName,
                filePath: path,
                result: result,
                durationMs: durationMs,
                expected: expectedByFileName[fileName]
            ))
        }

        return EvaluationReport(
            config: config,
            runLabel: runLabel,
            sourceDescription: fileSet.sourceDescription,
            generatedAt: Date(),
            rows: rows
        )
    }

    /// Collect regular files under `folderURL`, including subfolders (depth-first).
    private func collectFiles(from folderURL: URL, maxFiles: Int) throws -> [URL] {
        var found: [URL] = []

        func scan(_ url: URL) throws {
            guard found.count < maxFiles else { return }

            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard found.count < maxFiles else { return }
                let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                if values?.isRegularFile == true {
                    found.append(item)
                } else if values?.isDirectory == true {
                    try scan(item)
                }
            }
        }

        try scan(folderURL)
        return found
    }

    private struct FixtureBatch {
        let urls: [URL]
        let cleanupDirectory: URL?
    }

    private func createSampleFixtures(maxFiles: Int) throws -> FixtureBatch {
        let dir = fileManager.temporaryDirectory
            .appendingPathComponent("ClassificationEvaluationFixtures")
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let samples: [(String, String)] = [
            ("visa_application.pdf", "Consulate appointment confirmation for B-1 visa."),
            ("invoice_acme_2024.pdf", "Invoice #4421 — Amount due $1,250.00"),
            ("IMG_vacation.jpg", "Family vacation photo export"),
            ("resume_mrinal.docx", "Curriculum vitae — work history and skills"),
            ("Taxes2025.pdf", "Form 1099-INT interest income statement"),
            ("main.swift", "import Foundation\n\nprint(\"hello\")")
        ]

        var urls: [URL] = []
        for (name, content) in samples.prefix(maxFiles) {
            let url = dir.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        return FixtureBatch(urls: urls, cleanupDirectory: dir)
    }
}
