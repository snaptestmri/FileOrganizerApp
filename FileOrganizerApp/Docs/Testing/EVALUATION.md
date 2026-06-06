# Classification Evaluation

Shared harness for comparing classifiers, tuning Ollama, and measuring labeled accuracy (phases 1–3).

**Design (architecture, pros/cons, alternatives):** [CLASSIFICATION_EVALUATION_DESIGN.md](../Architecture/CLASSIFICATION_EVALUATION_DESIGN.md)

## Overview


| Component                         | Role                                                          |
| --------------------------------- | ------------------------------------------------------------- |
| `EvaluationConfig`                | Folder, limits, model/temperature, prompt variant, run label  |
| `ClassificationEvaluationHarness` | Discover files, run classification, build rows                |
| `EvaluationReport`                | Aggregates + `printReport()` / `exportJSON()` / `exportCSV()` |


Implementation lives under `FileOrganizerApp/Models/Services/Evaluation/`.

## Prerequisites

- **Fallback / stub tests:** No extra setup; run in CI (`StubLLMService` lives in the test target only).
- **Ollama tests (later phases):** `ollama serve`, model pulled, `EVAL_USE_OLLAMA=1`.

## Environment variables


| Variable              | Description                                                 |
| --------------------- | ----------------------------------------------------------- |
| `EVAL_FOLDER`         | Folder to scan (`~` expanded). Alias: `QUICK_TUNING_FOLDER` |
| `EVAL_MAX_FILES`      | Max files per run (default: 5)                              |
| `EVAL_MODEL`          | Ollama model name (default: `llama3.2:3b`)                  |
| `EVAL_TEMPERATURE`    | LLM temperature (default: `0.1`)                            |
| `EVAL_USE_EXAMPLES`   | `1` / `true` / `yes` enables few-shot examples              |
| `EVAL_PROMPT_VARIANT` | `standard`, `concise`, `detailed`, `chain_of_thought`       |
| `EVAL_RUN_LABEL`      | Label in reports and CSV                                    |
| `EVAL_USE_OLLAMA`     | Gate live Ollama tests (`1` / `true`) — phase 1+            |


## Running tests (phase 0)

```bash
# Uses ~/Downloads when EVAL_FOLDER is unset (sample fixtures if empty)
swift test --filter EvaluationHarnessTests

# Override folder and file count
EVAL_FOLDER=~/Documents EVAL_MAX_FILES=5 swift test --filter EvaluationHarnessTests
```

`EvaluationHarnessTests` loads config via `EvaluationConfig.forHarnessTests()`, which calls `fromEnvironment()` and defaults to `~/Downloads` when no folder env var is set.

## Swift usage

```swift
let harness = ClassificationEvaluationHarness()
var config = EvaluationConfig.forHarnessTests { $0.runLabel = "mock" }

let fileSet = try harness.discoverFiles(config: config)
defer {
    if let dir = fileSet.cleanupDirectory {
        try? FileManager.default.removeItem(at: dir)
    }
}

let report = await harness.evaluate(
    fileSet: fileSet,
    config: config,
    llmService: StubLLMService.fast()
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
    llmService: StubLLMService.fast()
)
```

## Report metrics

- **averageConfidence** — mean model confidence (not the same as accuracy)
- **averageDurationMs** — mean latency per file
- **fallbackRate** — share of rows where `method == fallback`
- **categoryDistribution** / **subfolderDistribution** — counts for tuning

## Phase 1: Compare classifiers

Runs the **same files** through Fallback, Ollama (if running), and OpenAI (if API key set), then reports agreements and disagreements.

```bash
# Fallback always; Ollama/OpenAI when available (OpenAI skipped without key)
swift test --filter ClassifierComparisonTests.testCompareAll

# Controlled fixture folder (fallback only)
swift test --filter ClassifierComparisonTests.testCompareFallbackOnFixtures

# Include Ollama (skips if not running)
swift test --filter ClassifierComparisonTests.testCompareWithOllamaWhenAvailable

EVAL_FOLDER=~/Downloads EVAL_MAX_FILES=10 swift test --filter ClassifierComparisonTests.testCompareAll
```

OpenAI key: `OPENAI_API_KEY` env var or `openai_api_key` in app UserDefaults.

Output: console report (`printReport`) and `exportCSV()` with columns per backend plus `allAgree`.

## Next phases

1. ~~**Compare**~~ — `ClassifierComparisonTests`
2. **Tuning** — multi-config runs + optional `ABTestingService` wiring
3. **Accuracy** — `labels.json` fixtures + strict/category accuracy scores

