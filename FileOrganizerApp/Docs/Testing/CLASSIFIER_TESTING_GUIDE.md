# Classifier Testing Guide

> **Note:** This guide references some old class names. Current architecture uses:
> - `FallbackClassifier` (instead of `RuleBasedClassifier`)
> - `OllamaLLMService` (instead of `OllamaClassifier`)
> - `FileClassificationManager` (instead of `ClassifierManager`)
> See [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](../Architecture/ARCHITECTURE_MIGRATION_STATUS.md) for details.

## Overview

This guide explains how to test the different classifiers (Fallback, Ollama, OpenAI) in the File Organizer App.

## 🧪 Testing Methods

### 1. **Unit Tests** (Automated)

Run the automated test suite:

```bash
# Run all tests
swift test

# Run only AI classification tests
swift test --filter AIClassificationTests

# Run integration tests
swift test --filter AIClassificationIntegrationTests

# Run specific test
swift test --filter testFallbackClassifierPDF
```

### 2. **Manual Testing** (Interactive)

Test classifiers directly in the app:

1. Launch the app
2. Go to "AI Classification" or "Run Organizer"
3. Select a folder with test files
4. Choose a classifier
5. Review results

### 3. **Command Line Testing** (Scripts)

Create test scripts to verify classifier behavior.

---

## 📋 Testing Each Classifier

### Rule-Based Classifier

**Status:** ✅ Always Available (No setup required)

#### Quick Test
```swift
let classifier = FallbackClassifier()
let metadata = FileMetadata.extract(from: fileURL)
let result = classifier.classify(metadata)
print("Category: \(result.category), Subfolder: \(result.subfolder)")
```

#### Test Cases

| File Type | Expected Category | Expected Subfolder |
|-----------|------------------|-------------------|
| `invoice.pdf` | Documents | Invoices |
| `photo.jpg` | Media | Photos |
| `video.mp4` | Media | Videos |
| `code.swift` | Projects | Code |
| `archive.zip` | Archive | Compressed |

#### Test Files to Create

```bash
# Create test files
mkdir -p ~/Desktop/ClassifierTest
cd ~/Desktop/ClassifierTest

# Create various file types
touch invoice_2024.pdf
touch vacation_photo.jpg
touch movie.mp4
touch main.swift
touch backup.zip
```

#### Expected Behavior
- ✅ Instant classification (< 10ms per file)
- ✅ Deterministic results (same file = same classification)
- ✅ Works offline
- ✅ No external dependencies

---

### Ollama Classifier (Local LLM)

**Status:** ⚠️ Requires Ollama Installation

#### Setup

```bash
# 1. Install Ollama
brew install ollama

# 2. Start Ollama server
ollama serve

# 3. In another terminal, download a model
ollama pull llama3.2:1b  # Small, fast (~1.3GB)
# or
ollama pull mistral:7b   # Better accuracy (~4.1GB)
```

#### Quick Test

```swift
let classifier = OllamaClassifier()
if classifier.isAvailable {
    let metadata = FileMetadata.extract(from: fileURL)
    let result = try await classifier.classify(metadata: metadata)
    print("Category: \(result.category), Confidence: \(result.confidence)")
} else {
    print("Ollama not available - is it running?")
}
```

#### Verify Ollama is Running

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Should return JSON with available models
```

#### Test Checklist

- [ ] Ollama server is running (`ollama serve`)
- [ ] Model is downloaded (`ollama list`)
- [ ] Classifier detects Ollama (`classifier.isAvailable == true`)
- [ ] Classification returns results
- [ ] Results are reasonable (category/subfolder make sense)
- [ ] Works offline (disconnect internet, should still work)

#### Common Issues

**Issue:** `isAvailable` returns `false`
- **Solution:** Check if Ollama is running: `curl http://localhost:11434/api/tags`
- **Solution:** Start Ollama: `ollama serve`

**Issue:** Classification fails
- **Solution:** Check Ollama logs in terminal
- **Solution:** Verify model is downloaded: `ollama list`
- **Solution:** Try a different model (smaller = faster)

**Issue:** Slow classification
- **Solution:** Use smaller model (`llama3.2:1b` instead of `mistral:7b`)
- **Solution:** Reduce batch size
- **Solution:** Check system resources (CPU/GPU)

---

### OpenAI Classifier (Cloud LLM)

**Status:** ⚠️ Requires API Key and Internet

#### Setup

1. Get OpenAI API key from https://platform.openai.com/api-keys
2. Store in app settings (or environment variable for testing)

#### Quick Test

```swift
let apiKey = "sk-..." // Your API key
let classifier = OpenAIClassifier(apiKey: apiKey)

let metadata = FileMetadata.extract(from: fileURL)
let result = try await classifier.classify(metadata: metadata)
print("Category: \(result.category), Confidence: \(result.confidence)")
```

#### Test Checklist

- [ ] API key is valid
- [ ] Internet connection available
- [ ] API quota not exceeded
- [ ] Classification returns results
- [ ] Results are accurate
- [ ] Cost is acceptable (track token usage)

#### Cost Estimation

```
GPT-3.5-turbo: ~$0.0015 per 1K tokens
Average classification: ~200-500 tokens
Cost per file: ~$0.0003 - $0.00075

100 files = ~$0.03 - $0.075
```

#### Common Issues

**Issue:** API error
- **Solution:** Check API key is correct
- **Solution:** Verify internet connection
- **Solution:** Check API quota/balance

**Issue:** Rate limiting
- **Solution:** Reduce batch size
- **Solution:** Add delays between requests
- **Solution:** Use lower tier model

---

## 🧪 Test Scenarios

### Scenario 1: Basic Classification

**Goal:** Verify classifier can categorize common file types

**Test Files:**
```
test_folder/
├── invoice_2024.pdf
├── receipt_nov.pdf
├── vacation_photo.jpg
├── family_picture.jpg
├── movie.mp4
├── code.swift
└── archive.zip
```

**Expected Results:**
- PDFs → Documents/Invoices or Documents/Receipts
- Images → Media/Photos
- Video → Media/Videos
- Code → Projects/Code
- Archive → Archive/Compressed

### Scenario 2: Ambiguous Files

**Goal:** Test classifier with unclear file names

**Test Files:**
```
test_folder/
├── file1.pdf
├── document.txt
├── image.png
└── data.zip
```

**Expected Behavior:**
- Classifier should still categorize (may use default categories)
- Confidence may be lower for ambiguous files
- Should not crash or error

### Scenario 3: Batch Processing

**Goal:** Test classification of many files

**Test Files:** 50+ files of various types

**Expected Behavior:**
- All files processed
- Progress updates shown
- Results returned for all files
- Performance acceptable (< 5 seconds for rule-based, < 2 minutes for LLM)

### Scenario 4: Error Handling

**Goal:** Test classifier with problematic inputs

**Test Cases:**
- Missing files
- Corrupted files
- Very large files
- Files with special characters
- Empty folder

**Expected Behavior:**
- Graceful error handling
- No crashes
- Error messages logged
- Continues processing other files

---

## 📊 Performance Testing

### Benchmark Script

```swift
func benchmarkClassifier(_ classifier: LLMClassifier, files: [URL]) async throws {
    let startTime = Date()
    var metadataList: [FileMetadata] = []
    
    // Extract metadata
    for file in files {
        if let metadata = FileMetadata.extract(from: file) {
            metadataList.append(metadata)
        }
    }
    
    // Classify
    let results = try await classifier.classifyBatch(metadata: metadataList)
    
    let duration = Date().timeIntervalSince(startTime)
    let filesPerSecond = Double(files.count) / duration
    
    print("Classifier: \(classifier.name)")
    print("Files: \(files.count)")
    print("Time: \(duration)s")
    print("Speed: \(filesPerSecond) files/sec")
}
```

### Expected Performance

| Classifier | Files/sec | Latency per File |
|------------|-----------|------------------|
| Rule-Based | 1000+ | < 10ms |
| Ollama (llama3.2:1b) | 2-5 | 200-500ms |
| Ollama (mistral:7b) | 1-3 | 300-1000ms |
| OpenAI (GPT-3.5) | 5-10 | 100-200ms |

---

## 🔍 Debugging Classifiers

### Enable Debug Logging

Add logging to see what's happening:

```swift
// In classifier implementation
print("🔍 Classifying: \(metadata.fileName)")
print("🔍 Metadata: \(metadata.toDescription())")
print("🔍 Result: \(result.category)/\(result.subfolder)")
```

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
print("✅ Classification: \(result.category)/\(result.subfolder), Method: \(result.method)")
```

### Test Individual Components

```swift
// Test metadata extraction
let metadata = FileMetadata.extract(from: fileURL)
print("Author: \(metadata?.author ?? "none")")
print("Keywords: \(metadata?.keywords?.joined(separator: ", ") ?? "none")")
print("Where From: \(metadata?.whereFrom ?? "none")")

// Test prompt building (for LLM classifiers)
let prompt = buildPrompt(metadata: metadata!)
print("Prompt:\n\(prompt)")

// Test classification
let result = try await classifier.classify(metadata: metadata!)
print("Result: \(result)")
```

---

## 📝 Test Data Preparation

### Create Test Files with Metadata

#### PDF with Author
```bash
# Use a PDF editor or script to add author metadata
# Or download a PDF that has author info
```

#### Image with EXIF Data
```bash
# Take a photo with your phone/camera
# Transfer to Mac (will have EXIF data)
```

#### File with "Where From"
```bash
# Download a file from a website
# macOS automatically adds "where from" metadata
curl -o test.pdf https://example.com/document.pdf
```

### Test File Generator Script

```swift
func createTestFiles(in directory: URL) throws {
    let files = [
        ("invoice_2024.pdf", "PDF content"),
        ("vacation.jpg", "Image content"),
        ("code.swift", "Swift code"),
        ("archive.zip", "Archive content")
    ]
    
    for (name, content) in files {
        let file = directory.appendingPathComponent(name)
        try content.write(to: file, atomically: true, encoding: .utf8)
    }
}
```

---

## ✅ Test Checklist

### Rule-Based Classifier
- [ ] Classifies PDFs correctly
- [ ] Classifies images correctly
- [ ] Classifies videos correctly
- [ ] Classifies code files correctly
- [ ] Handles unknown file types gracefully
- [ ] Performance is acceptable (< 10ms/file)

### Ollama Classifier
- [ ] Detects when Ollama is running
- [ ] Detects when Ollama is not running
- [ ] Classifies files correctly
- [ ] Returns reasonable confidence scores
- [ ] Works offline
- [ ] Handles errors gracefully

### OpenAI Classifier
- [ ] Validates API key
- [ ] Classifies files correctly
- [ ] Returns reasonable confidence scores
- [ ] Handles API errors
- [ ] Handles rate limiting
- [ ] Tracks costs

### FileClassificationManager
- [ ] Returns available classifiers
- [ ] Falls back correctly
- [ ] Prioritizes correctly (Ollama > Rule-Based > OpenAI)

### Integration
- [ ] Complete workflow works
- [ ] Files are moved correctly
- [ ] Progress updates work
- [ ] Error recovery works
- [ ] UI updates correctly

---

## 🐛 Troubleshooting

### Classifier Not Available

**Rule-Based:**
- Should always be available
- If not, check code compilation

**Ollama:**
```bash
# Check if running
curl http://localhost:11434/api/tags

# Start if not running
ollama serve

# Check models
ollama list
```

**OpenAI:**
- Check API key is set
- Check internet connection
- Check API quota

### Classification Errors

**Check Logs:**
- Look for error messages in console
- Check classifier-specific logs
- Verify file metadata extraction

**Common Fixes:**
- Restart Ollama server
- Re-download model
- Check API key
- Verify file permissions

### Performance Issues

**Rule-Based:**
- Should be instant
- If slow, check for blocking operations

**Ollama:**
- Use smaller model
- Check CPU/GPU usage
- Reduce batch size

**OpenAI:**
- Check network speed
- Reduce batch size
- Use faster model (GPT-3.5 vs GPT-4)

---

## 📈 Test Results Template

```
Classifier: [Name]
Date: [Date]
Files Tested: [Count]

Results:
- Correct Classifications: [Count] ([%])
- Incorrect Classifications: [Count] ([%])
- Average Confidence: [Score]
- Average Time per File: [ms]
- Total Time: [seconds]

Issues Found:
- [Issue 1]
- [Issue 2]

Notes:
[Any additional observations]
```

---

## 🎯 Next Steps

1. **Run automated tests:** `swift test`
2. **Test manually:** Use app with real files
3. **Benchmark performance:** Measure speed and accuracy
4. **Compare classifiers:** Test same files with different classifiers
5. **Report issues:** Document any problems found

---

**Last Updated:** 2024-12-20

