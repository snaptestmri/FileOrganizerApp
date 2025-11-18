# Quick Tuning Reference

## 🚀 Quick Start: Tuning Ollama LLM Service

> **Note:** This guide has been updated for the new architecture using `OllamaLLMService` with `FileClassificationManager`.

### Basic Usage (Default Settings)

```swift
let llmService = OllamaLLMService()
// Uses: llama3.2:3b, temperature: 0.1, topP: 0.95, topK: 40

let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: ClassificationPromptBuilder()
)
```

### Enable Few-Shot Examples

**Why:** Improves accuracy by showing the model examples of good classifications.

```swift
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true

let manager = FileClassificationManager(
    llmService: OllamaLLMService(),
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

### Change Model

**For Better Accuracy:**
```swift
let llmService = OllamaLLMService(model: "mistral:7b")
```

**For Faster Speed:**
```swift
let llmService = OllamaLLMService(model: "llama3.2:1b")
```

**For Balanced:**
```swift
let llmService = OllamaLLMService(model: "llama3.2:3b")
```

### Adjust Temperature

**For More Consistent Results (Recommended):**
```swift
let llmService = OllamaLLMService(temperature: 0.1)
```

**For Slightly More Variation:**
```swift
let llmService = OllamaLLMService(temperature: 0.3)
```

### Full Customization

```swift
let llmService = OllamaLLMService(
    model: "mistral:7b",           // Better accuracy model
    temperature: 0.2,              // Consistent results
    topP: 0.9,                     // Nucleus sampling
    topK: 40                       // Top-k sampling
)

let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true

let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

---

## 📊 Model Comparison

| Model | Size | Speed | Accuracy | Best For |
|-------|------|-------|----------|----------|
| `llama3.2:1b` | 1.3GB | ⚡⚡⚡ | ⭐⭐ | Quick testing |
| `llama3.2:3b` | 2.0GB | ⚡⚡ | ⭐⭐⭐ | Balanced use |
| `mistral:7b` | 4.1GB | ⚡ | ⭐⭐⭐⭐ | Production |

---

## 🎯 Recommended Configurations

### For Testing
```swift
let llmService = OllamaLLMService(
    model: "llama3.2:1b",
    temperature: 0.2
)
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = false
```

### For Production
```swift
let llmService = OllamaLLMService(
    model: "mistral:7b",
    temperature: 0.2
)
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true
```

### For Maximum Accuracy
```swift
let llmService = OllamaLLMService(
    model: "llama3.1:8b",
    temperature: 0.1
)
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true
```

---

## 🔧 Parameter Guide

### Temperature
- **0.0-0.2**: Very consistent, deterministic
- **0.2-0.4**: Balanced (recommended)
- **0.4-0.7**: More variation, creative

### Top P
- **0.9**: Recommended (nucleus sampling)
- **0.95**: More diverse
- **0.85**: More focused

### Top K
- **40**: Recommended
- **50**: More options
- **30**: More focused

### Use Examples
- **true**: Better accuracy, longer prompts
- **false**: Faster, shorter prompts

---

## 📝 Example: Testing Different Configurations

```swift
// Test 1: Default
let classifier1 = OllamaClassifier()
let result1 = try await classifier1.classify(metadata: metadata)

// Test 2: With examples
let classifier2 = OllamaClassifier(useExamples: true)
let result2 = try await classifier2.classify(metadata: metadata)

// Test 3: Better model
let classifier3 = OllamaClassifier(model: "mistral:7b", useExamples: true)
let result3 = try await classifier3.classify(metadata: metadata)

// Compare results
print("Default: \(result1.category)/\(result1.subfolder) (confidence: \(result1.confidence))")
print("With Examples: \(result2.category)/\(result2.subfolder) (confidence: \(result2.confidence))")
print("Better Model: \(result3.category)/\(result3.subfolder) (confidence: \(result3.confidence))")
```

---

## 🎓 What Changed?

### Before
```swift
let classifier = OllamaClassifier()
// Only model could be changed
```

### After
```swift
let classifier = OllamaClassifier(
    model: "mistral:7b",      // Choose model
    temperature: 0.2,         // Control randomness
    topP: 0.9,                // Nucleus sampling
    topK: 40,                 // Top-k sampling
    useExamples: true         // Enable few-shot examples
)
```

**All parameters have defaults**, so existing code continues to work!

---

## 📚 Full Documentation

See `TUNING_OLLAMA_CLASSIFIER.md` for:
- Detailed prompt engineering
- Advanced techniques
- Performance optimization
- Testing strategies
- Monitoring & metrics

---

**Last Updated:** 2024-12-20

