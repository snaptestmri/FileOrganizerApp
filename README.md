# File Organizer App

A macOS app for organizing files with **keyword rules** or **AI-powered classification**. Built with SwiftUI and Swift Package Manager.

## Features

| Feature | Description |
|---------|-------------|
| **Run Organizer** | Move files using user-defined keyword rules |
| **AI Classification** | Classify and organize files with Ollama, OpenAI, or Anthropic |
| **Manage Keywords** | Create and edit keyword → folder mappings |
| **Duplicate Checker** | Find duplicate files across folders |
| **iCloud File Browser** | Browse and manage iCloud Drive files |
| **Settings** | Configure API keys, profiles, and app preferences |

## Requirements

- macOS 14+
- Swift 5.9+
- [Ollama](https://ollama.com/) (optional, for local AI classification)

## Quick start

```bash
# Clone and enter the repo
cd FileOrganizerApp

# Build and run
swift build
swift run

# Run tests
swift test

# Run a focused test suite
swift test --filter EvaluationHarnessTests
swift test --filter ClassifierComparisonTests
```

### Local AI (Ollama)

```bash
brew install ollama
ollama serve
ollama pull llama3.2:3b
```

Then choose **Ollama (Local AI)** in the app’s AI Classification flow.

### Cloud AI (optional)

Configure API keys via **Settings** in the app, or see [API_KEY_CONFIGURATION.md](API_KEY_CONFIGURATION.md).

---

## Classification backends

| Backend | Internet | API key | Best for |
|---------|----------|---------|----------|
| **Ollama** | No (localhost) | None | Private, offline AI filing |
| **OpenAI** | Yes | Required | High-quality cloud classification |
| **Anthropic** | Yes | Required | Claude-based classification |
| **Fallback** | No | None | Rule-based offline backup when LLM fails |

The app extracts **file metadata and a short text preview** (when available), sends that to the selected classifier, and falls back to rule-based classification if the LLM is unavailable.

Evaluation and comparison tooling lives under `FileOrganizerApp/Models/Services/Evaluation/`.

---

## Project structure

```
FileOrganizerApp/
├── FileOrganizerApp/           # App target
│   ├── FileOrganizerApp.swift  # App entry point
│   ├── Views/                  # SwiftUI views
│   └── Models/
│       ├── Core/               # FileMetadata, ClassificationResult, …
│       ├── Services/
│       │   ├── Classification/ # Manager, fallback, prompts, filing
│       │   ├── Evaluation/     # Harness, compare, config
│       │   └── LLM/            # Ollama, OpenAI, Anthropic
│       ├── Storage/            # Keywords, profiles
│       └── Constants/          # Taxonomy, regions
├── Tests/                      # XCTest suites
├── Docs/Guides/                # Cross-cutting developer guides
└── FileOrganizerApp/Docs/      # Detailed app documentation
```

See also [FileOrganizerApp/Models/README.md](FileOrganizerApp/Models/README.md) for the models layer.

---

## Documentation

All project documentation is indexed here. Start with the section that matches your goal.

### Getting started

| Document | Description |
|----------|-------------|
| [Offline Classification Guide](FileOrganizerApp/Docs/Guides/OFFLINE_CLASSIFICATION_GUIDE.md) | Install, run offline, troubleshoot |
| [How Ollama Works](FileOrganizerApp/Docs/Guides/HOW_OLLAMA_WORKS.md) | Local LLM setup and behavior |
| [API Key Configuration](API_KEY_CONFIGURATION.md) | OpenAI and Anthropic key setup |
| [LLM Classification Requirements](FileOrganizerApp/Docs/Guides/LLM_CLASSIFICATION_REQUIREMENTS.md) | Requirements for LLM-based filing |

### Architecture & design

| Document | Description |
|----------|-------------|
| [Design Document](FileOrganizerApp/Docs/Architecture/DESIGN_DOCUMENT.md) | System architecture, components, data flow |
| [Architecture Blocks](FileOrganizerApp/Docs/Architecture/ARCHITECTURE_BLOCKS.md) | Visual diagrams and component blocks |
| [Classification Evaluation Design](FileOrganizerApp/Docs/Architecture/CLASSIFICATION_EVALUATION_DESIGN.md) | Evaluation harness design (phases 0–3) |
| [Subject & Location Filing](FileOrganizerApp/Docs/Architecture/SUBJECT_AND_LOCATION_FILING_DESIGN.md) | Subject/location-based filing design |
| [Subfolder Analysis](FileOrganizerApp/Docs/Architecture/SUBFOLDER_ANALYSIS.md) | Subfolder taxonomy analysis |

### Testing & evaluation

| Document | Description |
|----------|-------------|
| [Evaluation Guide](FileOrganizerApp/Docs/Testing/EVALUATION.md) | **Start here** — harness, env vars, compare runs |
| [How to Test Classifiers](FileOrganizerApp/Docs/Testing/HOW_TO_TEST_CLASSIFIERS.md) | Manual and automated classifier testing |
| [Classifier Testing Guide](FileOrganizerApp/Docs/Testing/CLASSIFIER_TESTING_GUIDE.md) | Detailed testing strategies and scenarios |
| [Manual Test Instructions](FileOrganizerApp/Docs/Testing/MANUAL_TEST_INSTRUCTIONS.md) | Step-by-step manual QA |
| [AI Classification Tests](FileOrganizerApp/Docs/Testing/AIClassificationTests_README.md) | `AIClassificationTests` suite |
| [Automated Tests](FileOrganizerApp/Docs/Testing/AutomatedTests-README.md) | Automated test overview |
| [XCTest HTML Report Setup](FileOrganizerApp/Docs/Testing/XCTEST_HTML_REPORT_SETUP.md) | HTML test reporting |

**Common evaluation commands:**

```bash
# Harness tests (no Ollama required)
swift test --filter EvaluationHarnessTests

# Compare Fallback vs Ollama on your folder
EVAL_FOLDER=~/Downloads EVAL_MAX_FILES=10 \
  swift test --filter ClassifierComparisonTests.testCompareWithOllamaWhenAvailable

# Compare all available backends
EVAL_FOLDER=~/Downloads swift test --filter ClassifierComparisonTests.testCompareAll
```

### Tuning & optimization

| Document | Description |
|----------|-------------|
| [Tuning Ollama Classifier](FileOrganizerApp/Docs/Tuning/TUNING_OLLAMA_CLASSIFIER.md) | Model, temperature, prompt tuning |
| [Tuning Test Guide](FileOrganizerApp/Docs/Tuning/TUNING_TEST_GUIDE.md) | How to run tuning experiments |
| [Run Tuning Test](FileOrganizerApp/Docs/Tuning/RUN_TUNING_TEST.md) | Quick tuning test commands |
| [Quick Tuning Reference](FileOrganizerApp/Docs/Tuning/QUICK_TUNING_REFERENCE.md) | Cheat sheet for tuning parameters |
| [Tuning Summary](FileOrganizerApp/Docs/Tuning/TUNING_SUMMARY.md) | Tuning results and notes |

### Developer guides

| Document | Description |
|----------|-------------|
| [Best Practices](Docs/Guides/BEST_PRACTICES.md) | Code quality, security, performance, testing |
| [Classifier Improvements](FileOrganizerApp/Docs/Guides/CLASSIFIER_IMPROVEMENTS.md) | Improvement notes and ideas |
| [Models README](FileOrganizerApp/Models/README.md) | Models directory layout |

---

## Key concepts

**Privacy:** Classification uses filename, extension, folder context, and an optional short text preview — not full file uploads to cloud services (unless you choose a cloud LLM backend).

**Fallback chain:** `FileClassificationManager` tries the selected LLM first; on failure it uses `FallbackClassifier` (filename intent, content preview keywords, extension rules).

**Evaluation phases:**

| Phase | Status | Purpose |
|-------|--------|---------|
| 0 — Shared harness | Done | `EvaluationConfig`, `ClassificationEvaluationHarness`, reports |
| 1 — Compare | Done | Side-by-side Fallback / Ollama / OpenAI comparison |
| 2 — Tuning / A/B | Planned | Multi-config sweeps, `ABTestingService` wiring |
| 3 — Labeled accuracy | Planned | Golden set, strict/category accuracy, regression gates |

---

## Implementation status

**Done:** Core classification, Ollama/OpenAI/Anthropic integration, fallback classifier (with preview-based routing), keyword organizer, duplicate checker, evaluation harness, classifier comparison, telemetry, A/B testing framework.

**In progress / planned:** Labeled accuracy fixtures, tuning comparison matrix, learning from user corrections, image classification.

---

## License

See repository settings for license information.
