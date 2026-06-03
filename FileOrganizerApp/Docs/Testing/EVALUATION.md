# Classification Evaluation

Shared harness for comparing classifiers, tuning Ollama, and measuring labeled accuracy (phases 1–3).

## Overview

| Component | Role |
|-----------|------|
| `EvaluationConfig` | Folder, limits, model/temperature, prompt variant, run label |
| `ClassificationEvaluationHarness` | Discover files, run classification, build rows |
| `EvaluationReport` | Aggregates + `printReport()` / `exportJSON()` / `exportCSV()` |

Implementation lives under `FileOrganizerApp/Models/Services/Evaluation/`.

## Prerequisites

- **Mock / Fallback tests:** No extra setup; run in CI.
- **Ollama tests (later phases):** `ollama serve`, model pulled, `EVAL_USE_OLLAMA=1`.

## Environment variables

| Variable | Description |
|----------|-------------|
| `EVAL_FOLDER` | Folder to scan (`~` expanded). Alias: `QUICK_TUNING_FOLDER` |
| `EVAL_MAX_FILES` | Max files per run (default: 5) |
| `EVAL_MODEL` | Ollama model name (default: `llama3.2:3b`) |
| `EVAL_TEMPERATURE` | LLM temperature (default: `0.1`) |
| `EVAL_USE_EXAMPLES` | `1` / `true` / `yes` enables few-shot examples |
| `EVAL_PROMPT_VARIANT` | `standard`, `concise`, `detailed`, `chain_of_thought` |
| `EVAL_RUN_LABEL` | Label in reports and CSV |
| `EVAL_USE_OLLAMA` | Gate live Ollama tests (`1` / `true`) — phase 1+ |

## Running tests (phase 0)

```bash
# All evaluation harness tests (no Ollama required)
swift test --filter EvaluationHarnessTests

# With a real folder (optional)
EVAL_FOLDER=~/Downloads EVAL_MAX_FILES=5 swift test --filter EvaluationHarnessTests
```

## Swift usage

```swift
let harness = ClassificationEvaluationHarness()
var config = EvaluationConfig.fromEnvironment()
config.runLabel = "mock"

let fileSet = try harness.discoverFiles(config: config)
defer {
    if let dir = fileSet.cleanupDirectory {
        try? FileManager.default.removeItem(at: dir)
    }
}

let report = await harness.evaluate(
    fileSet: fileSet,
    config: config,
    llmService: MockLLMService.fast()
)

report.printReport()
let csv = report.exportCSV()
let json = report.exportJSON()
```

### Fallback-only run

```swift
let report = await harness.evaluateFallbackOnly(fileSet: fileSet, config: config)
```

### One-shot discover + evaluate

```swift
let (report, fileSet) = try await harness.evaluateDiscoveredFiles(
    config: config,
    llmService: MockLLMService.fast()
)
```

## Report metrics

- **averageConfidence** — mean model confidence (not the same as accuracy)
- **averageDurationMs** — mean latency per file
- **fallbackRate** — share of rows where `method == fallback`
- **categoryDistribution** / **subfolderDistribution** — counts for tuning

## Next phases

1. **Compare** — `ClassifierComparisonTests` using the same harness  
2. **Tuning** — multi-config runs + optional `ABTestingService` wiring  
3. **Accuracy** — `labels.json` fixtures + strict/category accuracy scores  

See the evaluation plan in project chat / roadmap for details.
