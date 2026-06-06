//
//  EvaluationConfig.swift
//  File Organizer App
//
//  Configuration for classification evaluation runs (compare, tuning, accuracy).
//

import Foundation

// MARK: - Evaluation Config

/// Settings for a single evaluation run. Load defaults or override via environment variables.
struct EvaluationConfig: Equatable, Codable {
    /// Folder to scan for files. When nil, sample fixtures are used if the resolved folder is missing or empty.
    var folderPath: String?

    var maxFiles: Int = 5
    var includePreview: Bool = true
    var maxPreviewLength: Int = 500

    /// Ollama / manager tuning
    var model: String = "llama3.2:3b"
    var temperature: Double = 0.1
    var useExamples: Bool = true
    var promptVariant: PromptVariant = .standard

    /// Label printed in reports (e.g. "mock", "ollama-default", "fallback").
    var runLabel: String = "default"

    /// When the folder has no files, create temporary sample files so evaluation can still run.
    var useSampleFixturesWhenEmpty: Bool = true

    /// Default folder when `folderPath` and `EVAL_FOLDER` are unset.
    static let defaultFolder = "~/Downloads"

    // MARK: - Environment

    /// Builds config from environment variables.
    ///
    /// - `EVAL_FOLDER` or `QUICK_TUNING_FOLDER` — folder path (`~` expanded)
    /// - `EVAL_MAX_FILES` — max files to classify
    /// - `EVAL_MODEL` — Ollama model name
    /// - `EVAL_TEMPERATURE` — LLM temperature
    /// - `EVAL_USE_EXAMPLES` — `1` / `true` / `yes` enables few-shot examples
    /// - `EVAL_PROMPT_VARIANT` — `standard`, `concise`, `detailed`, `chain_of_thought`
    /// - `EVAL_RUN_LABEL` — report label for this run
    /// - `EVAL_USE_OLLAMA` — reserved for gated Ollama tests (`1` / `true`)
    static func fromEnvironment() -> EvaluationConfig {
        let env = ProcessInfo.processInfo.environment
        var config = EvaluationConfig()

        if let folder = env["EVAL_FOLDER"] ?? env["QUICK_TUNING_FOLDER"],
           !folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.folderPath = (folder as NSString).expandingTildeInPath
        }

        if let maxStr = env["EVAL_MAX_FILES"], let max = Int(maxStr), max > 0 {
            config.maxFiles = max
        }

        if let model = env["EVAL_MODEL"], !model.isEmpty {
            config.model = model
        }

        if let tempStr = env["EVAL_TEMPERATURE"], let temp = Double(tempStr) {
            config.temperature = temp
        }

        if let examples = env["EVAL_USE_EXAMPLES"] {
            config.useExamples = Self.parseBool(examples)
        }

        if let variantRaw = env["EVAL_PROMPT_VARIANT"],
           let variant = PromptVariant(rawValue: variantRaw) {
            config.promptVariant = variant
        }

        if let label = env["EVAL_RUN_LABEL"], !label.isEmpty {
            config.runLabel = label
        }

        return config
    }

    /// Config for harness/integration tests: reads env vars, then `defaultFolder` when no folder is set.
    static func forHarnessTests(customize: ((inout EvaluationConfig) -> Void)? = nil) -> EvaluationConfig {
        var config = fromEnvironment()
        if config.folderPath == nil {
            config.folderPath = (defaultFolder as NSString).expandingTildeInPath
        }
        customize?(&config)
        return config
    }

    /// Whether Ollama-backed evaluation is explicitly requested (for future gated tests).
    static var useOllamaFromEnvironment: Bool {
        guard let value = ProcessInfo.processInfo.environment["EVAL_USE_OLLAMA"] else {
            return false
        }
        return parseBool(value)
    }

    /// Resolved folder path for discovery, or nil to rely on fixtures only.
    func resolvedFolderPath() -> String? {
        if let folderPath {
            return (folderPath as NSString).expandingTildeInPath
        }
        return nil
    }

    /// Builds a `FileClassificationManager` wired with this config's prompt settings.
    func makeClassificationManager(
        llmService: LLMService,
        telemetryService: TelemetryService = .shared,
        fallbackClassifier: FallbackClassifier = FallbackClassifier(),
        enableTelemetry: Bool = false
    ) -> FileClassificationManager {
        let promptBuilder = ClassificationPromptBuilder()
        promptBuilder.useExamples = useExamples
        promptBuilder.promptVariant = promptVariant

        let manager = FileClassificationManager(
            llmService: llmService,
            telemetryService: telemetryService,
            fallbackClassifier: fallbackClassifier,
            promptBuilder: promptBuilder
        )
        manager.useExamples = useExamples
        manager.enableTelemetry = enableTelemetry
        return manager
    }

    /// Ollama service matching this config's model and temperature.
    func makeOllamaService() -> OllamaLLMService {
        OllamaLLMService(model: model, temperature: temperature)
    }

    private static func parseBool(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }
}

// MARK: - PromptVariant + Codable

extension PromptVariant: Codable {}
