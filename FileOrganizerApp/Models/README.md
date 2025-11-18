# Models Directory Structure

This directory contains all business logic, models, services, and constants for the File Organizer App.

## Directory Organization

```
Models/
├── Core/                          # Core data models
│   ├── FileMetadata.swift         # File metadata extraction and structure
│   ├── ClassificationResult.swift  # Classification result with method tracking
│   └── KeywordEntry.swift        # Keyword entry data structure
│
├── Services/                      # Business logic services
│   ├── Classification/           # Classification-related services
│   │   ├── FileClassificationManager.swift  # Main classification orchestrator
│   │   ├── FallbackClassifier.swift         # Rule-based fallback classifier
│   │   └── ClassificationPromptBuilder.swift # LLM prompt construction
│   │
│   ├── LLM/                      # LLM service implementations
│   │   ├── LLMService.swift       # LLM service protocol
│   │   ├── OllamaLLMService.swift # Local Ollama implementation
│   │   ├── OpenAILLMService.swift # OpenAI cloud implementation
│   │   ├── AnthropicLLMService.swift # Anthropic Claude implementation
│   │   └── MockLLMService.swift   # Mock service for testing
│   │
│   ├── TelemetryService.swift    # Analytics and telemetry
│   ├── ABTestingService.swift    # A/B testing framework
│   ├── AIClassifierMover.swift   # AI-powered file mover
│   ├── FileMover.swift           # Keyword-based file mover
│   └── iCloudFileManager.swift   # iCloud file management
│
├── Storage/                       # Data persistence
│   └── KeywordStore.swift        # Keyword storage and persistence
│
└── Constants/                    # Application constants
    └── ClassificationConstants.swift # Classification categories, subfolders, extensions
```

## Design Principles

1. **Separation of Concerns**: Models, services, storage, and constants are clearly separated
2. **Modularity**: Related services are grouped in subdirectories
3. **Testability**: Services are designed to be easily testable with dependency injection
4. **Extensibility**: New LLM services or classifiers can be added without modifying existing code

## Usage

All files in subdirectories are automatically included in the Swift package. No special imports are needed - Swift Package Manager handles the module structure automatically.

