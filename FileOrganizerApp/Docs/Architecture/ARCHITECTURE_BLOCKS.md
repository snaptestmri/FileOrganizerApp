# Architecture Blocks - Visual Reference

## System Overview Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FILE ORGANIZER APP                                  │
│                         AI Classification System                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            ┌───────▼────────┐            ┌────────▼────────┐
            │  UI Layer      │            │  Business Logic │
            │                │            │                 │
            │ - ContentView   │            │ - AIClassifier  │
            │ - FolderSelect  │            │   Mover         │
            │ - AIClassify    │            │ - FileMetadata  │
            └───────┬────────┘            └────────┬────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │   Classification Layer        │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │ FileClassificationManager│  │
                    │  └───────────┬─────────────┘  │
                    │              │                │
                    │  ┌───────────┴─────────────┐  │
                    │  │                         │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │  LLMService       │  │  │
                    │  │  │  (Protocol)       │  │  │
                    │  │  └───────┬──────────┘  │  │
                    │  │          │              │  │
                    │  │  ┌───────┴──────────┐  │  │
                    │  │  │ OllamaLLMService │  │  │
                    │  │  │ (Local)         │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │                         │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ OpenAILLMService │  │  │
                    │  │  │ (Cloud)          │  │  │
                    │  │  └──────────────────┘  │  │
                    │  │                         │  │
                    │  │  ┌──────────────────┐  │  │
                    │  │  │ FallbackClassifier│  │  │
                    │  │  │ (Rule-Based)     │  │  │
                    │  │  └──────────────────┘  │  │
                    │  └─────────────────────────┘  │
                    └───────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
        ┌───────────▼────────┐        ┌────────────▼────────┐
        │  Local Services    │        │  Cloud Services     │
        │                    │        │                      │
        │  Ollama Server     │        │  OpenAI API         │
        │  (localhost:11434) │        │  (api.openai.com)   │
        └────────────────────┘        └─────────────────────┘
```

## Component Interaction Blocks

### Classification Request Flow

```
┌─────────┐
│  User   │
└────┬────┘
     │
     │ 1. Select Folder & Mode
     ▼
┌─────────────────────┐
│ FolderSelectionView │
└────┬────────────────┘
     │
     │ 2. Open AI Classification
     ▼
┌─────────────────────┐
│ AIClassificationView│
└────┬────────────────┘
     │
     │ 3. Select Classifier
     ▼
┌─────────────────────────────┐
│ FileClassificationManager   │
│  ┌──────────────────────┐   │
│  │ Select LLMService    │   │──┐
│  └──────┬───────────────┘   │  │
│         │                   │  │
│  ┌──────▼───────────────┐   │  │
│  │ Try LLM (Ollama/    │   │  │
│  │  OpenAI/Anthropic)   │   │  │
│  └──────┬───────────────┘   │  │
│         │                   │  │
│  ┌──────▼───────────────┐   │  │
│  │ Fallback if fails    │   │  │
│  │ (FallbackClassifier) │   │  │
│  └──────┬───────────────┘   │  │
│         │                   │  │
│  └──────▼───────────────────┘  │
│  Return Classification          │
└────┬────────────────────────────┘
     │
     │ 4. Start Classification
     ▼
┌─────────────────────┐
│ AIClassifierMover   │
│  ┌──────────────┐   │
│  │ Extract      │   │
│  │ Metadata     │   │
│  └──────┬───────┘   │
│         │           │
│  ┌──────▼───────┐   │
│  │ Batch Files  │   │
│  └──────┬───────┘   │
│         │           │
│  ┌──────▼───────┐   │
│  │ Classify     │   │
│  └──────┬───────┘   │
│         │           │
│  ┌──────▼───────┐   │
│  │ Move Files   │   │
│  └──────────────┘   │
└─────────────────────┘
```

## Data Flow Blocks

### Metadata Extraction Block

```
┌──────────────┐
│   File URL   │
└──────┬───────┘
       │
       │ FileMetadata.extract()
       ▼
┌─────────────────────────────────┐
│      Metadata Extraction         │
├─────────────────────────────────┤
│  ┌──────────────────────────┐   │
│  │ File System API          │   │
│  │ - Get file attributes    │   │
│  │ - Read resource values   │   │
│  └──────┬───────────────────┘   │
│         │                        │
│  ┌──────▼───────────────────┐   │
│  │ Pattern Detection        │   │
│  │ - Date patterns          │   │
│  │ - Version numbers        │   │
│  │ - Separators             │   │
│  └──────┬───────────────────┘   │
│         │                        │
│  ┌──────▼───────────────────┐   │
│  │ Context Extraction       │   │
│  │ - Parent folder           │   │
│  │ - Sibling files           │   │
│  └──────┬───────────────────┘   │
│         │                        │
│  ┌──────▼───────────────────┐   │
│  │ Optional: Text Preview   │   │
│  │ (First 200-500 chars)    │   │
│  └──────┬───────────────────┘   │
│         │                        │
└─────────┼────────────────────────┘
          │
          ▼
┌─────────────────────┐
│   FileMetadata       │
│  - fileName          │
│  - fileSize          │
│  - fileType          │
│  - dates             │
│  - patterns          │
│  - context           │
└─────────────────────┘
```

### Classification Block

```
┌─────────────────────┐
│   FileMetadata       │
└──────┬──────────────┘
       │
       │ Build Prompt
       ▼
┌─────────────────────┐
│  Classification      │
│     Prompt          │
│                     │
│  "Classify file:    │
│   {metadata}"       │
└──────┬──────────────┘
       │
       │ Send to LLM
       ▼
┌─────────────────────┐
│   LLM Classifier    │
│  ┌──────────────┐   │
│  │ Process      │   │
│  │ Request      │   │
│  └──────┬───────┘   │
│         │            │
│  ┌──────▼───────┐   │
│  │ Generate     │   │
│  │ Response     │   │
│  └──────┬───────┘   │
│         │            │
└─────────┼────────────┘
          │
          ▼
┌─────────────────────┐
│ ClassificationResult│
│  - category          │
│  - subfolder         │
│  - confidence        │
│  - reasoning         │
└─────────────────────┘
```

## Class Hierarchy Blocks

### LLMClassifier Hierarchy

```
                    ┌─────────────────────┐
                    │  LLMClassifier      │
                    │   (Protocol)        │
                    │                     │
                    │ + isAvailable       │
                    │ + name              │
                    │ + classify()         │
                    │ + classifyBatch()   │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
    ┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
    │ OllamaLLMService │ │OpenAILLMService│ │FallbackClassifier│
    │                  │ │                │ │                  │
    │ - baseURL        │ │ - apiKey       │ │ (No properties)  │
    │ - model          │ │ - model        │ │                  │
    │                  │ │ - baseURL     │ │                  │
    │ + checkOllama()   │ │                │ │ + matchPattern() │
    │ + buildPrompt()   │ │ + buildPrompt()│ │                  │
    └──────────────────┘ └────────────────┘ └──────────────────┘
```

### Data Model Blocks

```
┌─────────────────────┐
│   FileMetadata       │
├─────────────────────┤
│ + fileName           │
│ + fileExtension      │
│ + fileSize           │
│ + modificationDate   │
│ + fileType           │
│ + parentFolder       │
│ + siblingFiles       │
│ + commonPatterns     │
│ + contentPreview     │
├─────────────────────┤
│ + extract()          │
│ + toJSONString()     │
│ + toDescription()    │
└─────────────────────┘
         │
         │ creates
         ▼
┌─────────────────────┐
│ ClassificationResult │
├─────────────────────┤
│ + category           │
│ + subfolder          │
│ + confidence         │
│ + reasoning          │
└─────────────────────┘
```

## Network Architecture Blocks

### Ollama (Local) Architecture

```
┌─────────────────────┐
│  macOS Application   │
│                     │
│  OllamaLLMService   │
└──────┬──────────────┘
       │
       │ HTTP POST
       │ localhost:11434
       ▼
┌─────────────────────┐
│   Ollama Server      │
│  (Running locally)   │
│                     │
│  ┌──────────────┐   │
│  │ LLM Model    │   │
│  │ (llama3.2:1b)│   │
│  └──────────────┘   │
└──────┬──────────────┘
       │
       │ JSON Response
       ▼
┌─────────────────────┐
│ ClassificationResult │
└─────────────────────┘

✅ No internet required
✅ 100% private
✅ Runs on localhost
```

### OpenAI (Cloud) Architecture

```
┌─────────────────────┐
│  macOS Application   │
│                     │
│  OpenAIClassifier   │
└──────┬──────────────┘
       │
       │ HTTPS POST
       │ api.openai.com
       │ (Encrypted)
       ▼
┌─────────────────────┐
│   Internet           │
│   (HTTPS/TLS)        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│   OpenAI API         │
│                     │
│  ┌──────────────┐   │
│  │ GPT Models   │   │
│  │ (gpt-3.5/4)  │   │
│  └──────────────┘   │
└──────┬──────────────┘
       │
       │ JSON Response
       │ (Encrypted)
       ▼
┌─────────────────────┐
│ ClassificationResult │
└─────────────────────┘

⚠️ Requires internet
⚠️ Data sent to cloud
✅ High accuracy
```

## Batch Processing Block

```
┌─────────────────────────────────────────┐
│         File List (100 files)           │
└──────┬──────────────────────────────────┘
       │
       │ Group into batches (10 files each)
       ▼
┌─────────────────────────────────────────┐
│  Batch 1: Files 1-10                    │
│  Batch 2: Files 11-20                  │
│  Batch 3: Files 21-30                  │
│  ...                                    │
│  Batch 10: Files 91-100                │
└──────┬──────────────────────────────────┘
       │
       │ Process in parallel (3-5 concurrent)
       ▼
┌─────────────────────────────────────────┐
│  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │ Batch 1  │  │ Batch 2  │  │ Batch 3  ││
│  │ Classify │  │ Classify │  │ Classify ││
│  └────┬─────┘  └────┬─────┘  └────┬─────┘│
│       │             │             │       │
│       ▼             ▼             ▼       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐│
│  │ Results 1│  │ Results 2│  │ Results 3││
│  └──────────┘  └──────────┘  └──────────┘│
└──────┬──────────────────────────────────┘
       │
       │ Merge all results
       ▼
┌─────────────────────────────────────────┐
│      All Classifications (100 results)   │
└──────┬──────────────────────────────────┘
       │
       │ Move files
       ▼
┌─────────────────────────────────────────┐
│      Organized Files                     │
└─────────────────────────────────────────┘
```

## Error Handling Block

```
┌─────────────────────┐
│  Classification      │
│     Request         │
└──────┬──────────────┘
       │
       │ Try Classifier 1
       ▼
┌─────────────────────┐
│   Success?          │
│   ┌────┐            │
│   │Yes │──► Return Result
│   └────┘            │
│   │No               │
│   └────► Error      │
└──────┬──────────────┘
       │
       │ Retry? (with backoff)
       ▼
┌─────────────────────┐
│   Success?           │
│   ┌────┐            │
│   │Yes │──► Return Result
│   └────┘            │
│   │No               │
│   └────► Fallback   │
└──────┬──────────────┘
       │
       │ Try Next Classifier
       ▼
┌─────────────────────┐
│  FallbackClassifier  │
│  (Always available)  │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────┐
│  ClassificationResult│
│  (Lower confidence)  │
└─────────────────────┘
```

## State Machine Block

```
┌─────────────┐
│   Idle      │
└──────┬──────┘
       │
       │ User selects folder
       ▼
┌─────────────┐
│  Ready      │
│  - Folder   │
│  - Mode     │
└──────┬──────┘
       │
       │ User starts
       ▼
┌─────────────┐
│  Selecting  │
│  Classifier │
└──────┬──────┘
       │
       │ Classifier selected
       ▼
┌─────────────┐
│  Processing │
│  - Extract  │
│  - Classify │
│  - Move     │
└──────┬──────┘
       │
       │ Complete / Error
       ▼
┌─────────────┐
│  Complete   │
│  - Results  │
│  - Stats    │
└──────┬──────┘
       │
       │ User dismisses
       ▼
┌─────────────┐
│   Idle      │
└─────────────┘
```

---

**Document Version:** 1.0  
**Last Updated:** 2024-12-20

# File Classification System

A robust, production-ready file classification system using LLM (Large Language Models) with intelligent fallback, comprehensive telemetry, and A/B testing capabilities.

## Features

- 🤖 **LLM-Powered Classification**: Intelligent file categorization using GPT-4 or Claude
- 🔄 **Fallback System**: Rule-based classifier for when LLM is unavailable
- 📊 **Comprehensive Telemetry**: Track performance, accuracy, and system health
- 🧪 **A/B Testing Framework**: Compare prompt variants and classification approaches
- ⚡ **Batch Processing**: Classify multiple files concurrently
- 🎯 **High Accuracy**: Optimized prompts with few-shot examples
- 📈 **Performance Monitoring**: Real-time metrics and analytics

## Architecture

```
┌─────────────────────────────────────┐
│   FileClassificationManager         │
│   (Orchestrates classification)     │
└──────────────┬──────────────────────┘
               │
       ┌───────┴───────┐
       │               │
┌──────▼─────┐  ┌─────▼──────┐
│ LLM        │  │ Fallback   │
│ Service    │  │ Classifier │
└────────────┘  └────────────┘
       │               │
       └───────┬───────┘
               │
    ┌──────────▼──────────┐
    │  TelemetryService   │
    │  ABTestingService   │
    └─────────────────────┘
```

## Installation

### Requirements
- Swift 5.5+
- iOS 15.0+ / macOS 12.0+
- Xcode 13.0+

### Add to Your Project

1. Copy all `.swift` files to your project
2. Add your LLM API key (OpenAI or Anthropic)
3. Initialize the classification manager

```swift
// Using OpenAI
let llmService = OpenAILLMService(apiKey: "your-api-key")

// Or using Anthropic Claude
let llmService = AnthropicLLMService(apiKey: "your-api-key")

let classifier = FileClassificationManager(llmService: llmService)
```

## Quick Start

### Basic Classification

```swift
// Create file metadata
let metadata = FileMetadata(
    fileName: "vacation_photo.jpg",
    fileExtension: "jpg",
    fileSize: 2_500_000
)

// Classify
let result = await classifier.classifyFile(metadata)

print("Category: \(result.category)")
print("Subfolder: \(result.subfolder)")
print("Destination: \(result.destinationPath)")
// Output: "Media/Photos"
```

### Batch Classification

```swift
let files = [
    FileMetadata(fileName: "report.pdf", fileExtension: "pdf", fileSize: 500_000),
    FileMetadata(fileName: "video.mp4", fileExtension: "mp4", fileSize: 50_000_000),
    FileMetadata(fileName: "code.swift", fileExtension: "swift", fileSize: 10_000)
]

let results = await classifier.classifyFiles(files)

for (file, result) in zip(files, results) {
    print("\(file.fileName) → \(result.destinationPath)")
}
```

## Classification Categories

### Supported Categories

| Category | Subfolders | Example Extensions |
|----------|------------|-------------------|
| **Media** | Photos, Videos, Audio, Screenshots | .jpg, .mp4, .mp3, .png |
| **Projects** | Code, 3D, Design, Assets, Web | .swift, .stl, .psd, .html |
| **Documents** | General, Presentations, Invoices, Financial, Reports, Receipts | .pdf, .pptx, .doc |
| **Archive** | Compressed, Installers, Backups | .zip, .dmg, .tar |

### Classification Rules

1. **Extension-based** (Highest Priority): File extension determines category
2. **Filename Patterns**: Keywords in filename suggest subfolder
3. **Context**: File size, modification date, and metadata provide additional hints

## Configuration

### Enable/Disable Features

```swift
let classifier = FileClassificationManager(llmService: llmService)

// Enable telemetry tracking
classifier.enableTelemetry = true

// Use fallback when LLM fails
classifier.useFallbackOnFailure = true

// Include few-shot examples in prompts
classifier.useExamples = true
```

### Prompt Variants

Choose different prompt styles for your use case:

```swift
let promptBuilder = ClassificationPromptBuilder()

// Standard: Balanced detail and performance
promptBuilder.promptVariant = .standard

// Concise: Minimal prompt for faster responses
promptBuilder.promptVariant = .concise

// Detailed: Comprehensive prompt with extra guidance
promptBuilder.promptVariant = .detailed

// Chain of Thought: Encourages step-by-step reasoning
promptBuilder.promptVariant = .chainOfThought
```

## Telemetry

### View Metrics

```swift
let metrics = TelemetryService.shared.getMetrics()

print("Total Classifications: \(metrics.totalClassifications)")
print("Success Rate: \(metrics.successRate * 100)%")
print("Average Confidence: \(metrics.averageConfidence)")
print("Average Duration: \(metrics.averageDuration)s")
```

### Generate Performance Report

```swift
let report = TelemetryService.shared.generatePerformanceReport()

print("LLM Success Rate: \(report.llmSuccessRate * 100)%")
print("Fallback Success Rate: \(report.fallbackSuccessRate * 100)%")

for recommendation in report.recommendations {
    print(recommendation)
}
```

### Export Data

```swift
if let data = TelemetryService.shared.exportData() {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("telemetry.json")
    try? data.write(to: url)
}
```

## A/B Testing

### Create Experiment

```swift
let variants = [
    ExperimentVariant(
        id: "variant_a",
        name: "Standard Prompt",
        configuration: ["promptVariant": "standard"]
    ),
    ExperimentVariant(
        id: "variant_b",
        name: "Detailed Prompt",
        configuration: ["promptVariant": "detailed"]
    )
]

ABTestingService.shared.createExperiment(
    name: "PromptComparison",
    variants: variants
)
```

### Get Variant for User

```swift
if let variant = ABTestingService.shared.getVariant(experimentName: "PromptComparison") {
    // Use this variant for classification
    promptBuilder.promptVariant = PromptVariant(rawValue: variant.configuration["promptVariant"] as? String ?? "standard")
}
```

### Record Results

```swift
ABTestingService.shared.recordResult(
    experimentName: "PromptComparison",
    variantId: variant.id,
    success: true,
    confidence: result.confidence,
    duration: 0.5,
    metadata: fileMetadata
)
```

### Analyze Experiment

```swift
if let analysis = ABTestingService.shared.getExperimentAnalysis(experimentName: "PromptComparison") {
    print("Winner: \(analysis.winner ?? "TBD")")
    print("Statistical Significance: \(analysis.statisticalSignificance)")
    
    for recommendation in analysis.recommendations {
        print(recommendation)
    }
}
```

## Fallback Classifier

The fallback classifier uses deterministic rules and doesn't require an LLM:

```swift
let fallbackClassifier = FallbackClassifier()
let result = fallbackClassifier.classify(metadata)
```

### When is Fallback Used?

- LLM service is unavailable
- LLM request times out
- LLM response is invalid or unparseable
- Manual fallback mode enabled

## Performance Optimization

### Tips for Best Performance

1. **Batch Processing**: Use `classifyFiles()` for multiple files
2. **Choose Right Prompt**: Use `.concise` for speed, `.detailed` for accuracy
3. **Pre-categorization**: Pass `preCategory` when extension determines category
4. **Enable Caching**: Implement LLM response caching for common patterns
5. **Monitor Metrics**: Use telemetry to identify bottlenecks

### Expected Performance

| Metric | LLM | Fallback |
|--------|-----|----------|
| **Average Duration** | 0.5-2.0s | <0.01s |
| **Accuracy** | 95%+ | 85%+ |
| **Confidence** | 0.85-0.95 | 0.65-0.90 |

## Error Handling

```swift
do {
    let result = await classifier.classifyFile(metadata)
    // Handle result
} catch ClassificationError.invalidLLMResponse(let response) {
    print("Invalid response: \(response)")
} catch ClassificationError.validationFailed(let result) {
    print("Validation failed: \(result)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing

### Mock LLM Service

For testing without API calls:

```swift
let mockService = MockLLMService()
mockService.shouldFail = false
mockService.delay = 0.1 // 100ms simulated delay

let classifier = FileClassificationManager(llmService: mockService)
```

### Unit Tests

```swift
func testBasicClassification() async {
    let mockService = MockLLMService()
    let classifier = FileClassificationManager(llmService: mockService)
    
    let metadata = FileMetadata(
        fileName: "test.jpg",
        fileExtension: "jpg",
        fileSize: 1_000_000
    )
    
    let result = await classifier.classifyFile(metadata)
    
    XCTAssertEqual(result.category, "Media")
    XCTAssertEqual(result.subfolder, "Photos")
    XCTAssertGreaterThan(result.confidence, 0.8)
}
```

## Examples

See `ExampleUsage.swift` for comprehensive examples:

1. Basic Classification
2. Batch Classification
3. Classification with Telemetry
4. Fallback Classifier Only
5. A/B Testing
6. Different Prompt Variants
7. Export Telemetry Data
8. Real-world Integration

Run all examples:

```swift
let examples = FileClassificationExample()
await examples.runAllExamples()
```

## API Keys

### OpenAI

Get your API key from: https://platform.openai.com/api-keys

```swift
let llmService = OpenAILLMService(
    apiKey: "sk-...",
    model: "gpt-4",
    maxTokens: 500
)
```

### Anthropic Claude

Get your API key from: https://console.anthropic.com/

```swift
let llmService = AnthropicLLMService(
    apiKey: "sk-ant-...",
    model: "claude-3-sonnet-20240229",
    maxTokens: 500
)
```

## Best Practices

1. **Always use telemetry** in production to monitor performance
2. **Start with A/B testing** to find optimal prompt variant
3. **Enable fallback** for reliability
4. **Monitor confidence scores** - investigate low confidence classifications
5. **Review error logs** regularly to improve rules
6. **Use batch processing** for bulk operations
7. **Cache common results** to reduce API costs

## Troubleshooting

### Low Classification Accuracy

- Enable detailed prompt variant
- Add more few-shot examples
- Check telemetry for patterns
- Review fallback rules

### Slow Performance

- Use concise prompt variant
- Reduce max_tokens
- Implement response caching
- Consider batch processing

### High API Costs

- Use fallback for simple cases
- Implement caching layer
- Reduce few-shot examples
- Lower max_tokens

## Contributing

Contributions welcome! Areas for improvement:

- Additional file type support
- More sophisticated fallback rules
- Advanced A/B testing metrics
- Performance optimizations
- Additional LLM providers

## License

MIT License - feel free to use in your projects

## Support

For issues or questions:
- Open an issue on GitHub
- Check telemetry for debugging info
- Review example usage code

---

Built with ❤️ for intelligent file organization