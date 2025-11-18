# How to Test Classifiers - Quick Guide

> **Note:** This guide references some old class names. Current architecture uses:
> - `FallbackClassifier` (instead of `RuleBasedClassifier`)
> - `OllamaLLMService` (instead of `OllamaClassifier`)
> - `FileClassificationManager` (instead of `ClassifierManager`)
> See [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](../Architecture/ARCHITECTURE_MIGRATION_STATUS.md) for details.

## 🚀 Quick Start

### 1. Run Automated Tests

```bash
# Run all tests
swift test

# Run only classifier tests
swift test --filter AIClassificationTests
swift test --filter ClassifierManualTest
```

### 2. Test in the App

1. Launch the app
2. Go to **"AI Classification"**
3. Select a folder
4. Choose a classifier
5. Review results

---

## 📋 Testing Each Classifier

### Fallback Classifier ✅ (Always Works)

**No setup required!**

```swift
// Quick test
let classifier = FallbackClassifier()
let metadata = FileMetadata.extract(from: fileURL)
let result = try await classifier.classify(metadata: metadata)
print("\(result.category)/\(result.subfolder)")
```

**Test Files:**
- `invoice.pdf` → Documents/Invoices ✅
- `photo.jpg` → Media/Photos ✅
- `video.mp4` → Media/Videos ✅
- `code.swift` → Projects/Code ✅

**Expected:** Instant results (< 10ms), always available

---

### Ollama Classifier 🦙 (Local, Offline)

#### Setup (One Time)

```bash
# 1. Install Ollama
brew install ollama

# 2. Start server (keep running)
ollama serve

# 3. Download model (in another terminal)
ollama pull llama3.2:1b  # Small, fast
```

#### Test

```swift
let llmService = OllamaLLMService()
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: ClassificationPromptBuilder()
)

let result = await manager.classifyFile(metadata)
print("Category: \(result.category)")
```

#### Verify It's Working

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Should return JSON with models
```

**Expected:** Works offline, 200-500ms per file, private

---

### OpenAI Classifier ☁️ (Cloud, Requires Internet)

#### Setup

1. Get API key: https://platform.openai.com/api-keys
2. Set environment variable:
   ```bash
   export OPENAI_API_KEY='sk-...'
   ```

#### Test

```swift
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
let classifier = OpenAIClassifier(apiKey: apiKey)

let result = try await classifier.classify(metadata: metadata)
print("Category: \(result.category), Confidence: \(result.confidence)")
```

**Expected:** High accuracy, 100-200ms per file, requires internet

---

## 🧪 Test Scenarios

### Scenario 1: Basic Test

**Create test files:**
```bash
mkdir ~/Desktop/ClassifierTest
cd ~/Desktop/ClassifierTest

touch invoice.pdf
touch photo.jpg
touch video.mp4
touch code.swift
```

**In app:**
1. Select `~/Desktop/ClassifierTest`
2. Choose classifier
3. Verify classifications

### Scenario 2: Compare All Classifiers

**Use the app:**
1. Select same folder
2. Test with Rule-Based (instant)
3. Test with Ollama (if available)
4. Test with OpenAI (if configured)
5. Compare results

### Scenario 3: Performance Test

**Test with many files:**
```bash
# Create 50 test files
for i in {1..50}; do
    touch "file$i.pdf"
done
```

**Measure:**
- Rule-Based: Should be < 1 second for 50 files
- Ollama: Should be < 30 seconds for 50 files
- OpenAI: Should be < 10 seconds for 50 files

---

## 🔍 Debugging

### Check Classifier Availability

```swift
// Create manager with desired service
let llmService = OllamaLLMService()  // or OpenAILLMService, etc.
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: ClassificationPromptBuilder()
)

// Manager automatically uses fallback if LLM fails
let result = await manager.classifyFile(metadata)
print("Category: \(result.category), Method: \(result.method)")
```

### Test Metadata Extraction

```swift
let metadata = FileMetadata.extract(from: fileURL)
print("Author: \(metadata?.author ?? "none")")
print("Keywords: \(metadata?.keywords?.joined(separator: ", ") ?? "none")")
print("Where From: \(metadata?.whereFrom ?? "none")")
```

### View Classification Prompt

For LLM classifiers, the prompt includes:
- File name and extension
- File size and type
- Modification date
- Parent folder
- Patterns detected
- Author (if available)
- Keywords (if available)
- Where from (if available)

---

## ✅ Test Checklist

### Rule-Based
- [ ] Classifies PDFs → Documents
- [ ] Classifies images → Media/Photos
- [ ] Classifies videos → Media/Videos
- [ ] Classifies code → Projects/Code
- [ ] Works instantly
- [ ] Always available

### Ollama
- [ ] Detects when running
- [ ] Detects when not running
- [ ] Classifies files correctly
- [ ] Works offline
- [ ] Reasonable confidence scores

### OpenAI
- [ ] Validates API key
- [ ] Classifies files correctly
- [ ] Handles errors gracefully
- [ ] Tracks costs

---

## 🐛 Common Issues

### Ollama Not Detected
```bash
# Check if running
curl http://localhost:11434/api/tags

# If not, start it
ollama serve
```

### OpenAI Errors
- Check API key is correct
- Check internet connection
- Check API quota

### Slow Performance
- Rule-Based: Should be instant
- Ollama: Use smaller model (`llama3.2:1b`)
- OpenAI: Check network speed

---

## 📊 Expected Results

| Classifier | Speed | Accuracy | Cost | Offline |
|------------|-------|----------|------|---------|
| Rule-Based | ⚡ Instant | ⭐⭐⭐ | ✅ Free | ✅ Yes |
| Ollama | ⚡ Fast | ⭐⭐⭐⭐ | ✅ Free | ✅ Yes |
| OpenAI | ⚡ Very Fast | ⭐⭐⭐⭐⭐ | 💰 Paid | ❌ No |

---

## 🎯 Quick Test Commands

```bash
# Test Rule-Based (always works)
swift test --filter testRuleBasedQuick

# Test Ollama (if running)
swift test --filter testOllamaQuick

# Test OpenAI (if API key set)
export OPENAI_API_KEY='sk-...'
swift test --filter testOpenAIQuick

# Compare all classifiers
swift test --filter testCompareClassifiers
```

---

**For detailed testing guide, see:** [CLASSIFIER_TESTING_GUIDE.md](./CLASSIFIER_TESTING_GUIDE.md)

