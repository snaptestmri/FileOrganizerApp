# Classifier Tuning Test Guide

> **Note:** This guide references the old `OllamaClassifier` class. The current architecture uses `OllamaLLMService` with `FileClassificationManager`. See [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](../Architecture/ARCHITECTURE_MIGRATION_STATUS.md) for details.

## 🎯 Overview

This guide explains how to test and tune the Ollama LLM Service on real folders.

## 📋 Prerequisites

1. **Ollama Installed**
   ```bash
   brew install ollama
   ```

2. **Ollama Running**
   ```bash
   ollama serve
   ```

3. **Model Downloaded**
   ```bash
   ollama pull llama3.2:1b  # Small, fast
   # or
   ollama pull mistral:7b    # Better accuracy
   ```

## 🧪 Running Tests

### Option 1: As Swift Tests

Add to your test file:

```swift
import XCTest
@testable import FileOrganizerApp

class ClassifierTuningTests: XCTestCase {
    func testCompareConfigurations() async throws {
        try await ClassifierTuningTest.compareConfigurations(
            folderPath: "~/Downloads",  // Change to your folder
            maxFiles: 5
        )
    }
    
    func testMultipleFolders() async throws {
        let llmService = OllamaLLMService()
        let promptBuilder = ClassificationPromptBuilder()
        promptBuilder.useExamples = true
        let manager = FileClassificationManager(
            llmService: llmService,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: promptBuilder
        )
        // Note: ClassifierTuningTest has been removed - use FileClassificationManager directly
    }
}
```

### Option 2: Quick Test Script

Create a simple test:

```swift
import Foundation
@testable import FileOrganizerApp

Task {
    // Test 1: Compare different configurations
    try await ClassifierTuningTest.compareConfigurations(
        folderPath: "~/Downloads",
        maxFiles: 5
    )
    
    // Test 2: Test on specific folder
    let llmService = OllamaLLMService()
    let promptBuilder = ClassificationPromptBuilder()
    promptBuilder.useExamples = true
    let manager = FileClassificationManager(
        llmService: llmService,
        telemetryService: TelemetryService.shared,
        fallbackClassifier: FallbackClassifier(),
        promptBuilder: promptBuilder
    )
    // Note: ClassifierTuningTest has been removed - use FileClassificationManager directly
}
```

## 📊 What Gets Tested

### 1. Configuration Comparison

Tests multiple configurations:
- Default (llama3.2:1b, temp=0.2, no examples)
- With Examples (few-shot examples enabled)
- Low Temperature (temp=0.1 for consistency)
- Better Model (mistral:7b)

**Metrics Collected:**
- Average confidence
- Average classification time
- Category distribution
- Subfolder distribution

### 2. Multi-Folder Testing

Tests classifier on multiple folders:
- Downloads
- Documents
- Desktop
- Custom folders

**Metrics Collected:**
- Per-folder statistics
- Overall performance
- Category distribution per folder

### 3. Analysis & Recommendations

Provides:
- Confidence statistics
- Low-confidence file identification
- Tuning recommendations
- Category distribution

## 🎛️ Customizing Tests

### Change Test Folders

Edit `ClassifierTuningTest.testFolders`:

```swift
static let testFolders: [String] = [
    "~/Documents",
    "~/Downloads",
    "~/Desktop",
    "/path/to/your/folder"  // Add custom folders
]
```

### Add Custom Configurations

Edit `ClassifierTuningTest.testConfigurations`:

```swift
static let testConfigurations: [(String, OllamaClassifier)] = [
    ("My Config", OllamaClassifier(
        model: "mistral:7b",
        temperature: 0.1,
        useExamples: true
    )),
    // Add more...
]
```

### Adjust Test Parameters

```swift
// Test more files
try await ClassifierTuningTest.compareConfigurations(
    folderPath: "~/Downloads",
    maxFiles: 20  // More files = better stats
)

// Test specific classifier
let myClassifier = OllamaClassifier(
    model: "mistral:7b",
    temperature: 0.2,
    useExamples: true
)
let results = try await ClassifierTuningTest.testOnFolder(
    folderPath: "~/Documents",
    classifier: myClassifier,
    maxFiles: 10
)
```

## 📈 Understanding Results

### Confidence Scores

- **0.9-1.0**: Very clear indicators (excellent)
- **0.7-0.9**: Strong indicators (good)
- **0.5-0.7**: Moderate indicators (acceptable)
- **0.0-0.5**: Weak indicators (needs improvement)

### Time Performance

- **< 500ms**: Fast (good for batch processing)
- **500-1000ms**: Acceptable
- **> 1000ms**: Slow (consider smaller model)

### Recommendations

The test will suggest:
- ✅ Enable examples if confidence is low
- ✅ Use better model if many low-confidence results
- ✅ Lower temperature for consistency
- ⚠️ Improve prompt if many ambiguous files

## 🔧 Tuning Based on Results

### If Average Confidence < 0.7

**Try:**
1. Enable examples: `useExamples: true`
2. Use better model: `model: "mistral:7b"`
3. Lower temperature: `temperature: 0.1`

### If Many Low-Confidence Results

**Try:**
1. Add more metadata (author, keywords, whereFrom)
2. Use larger model
3. Improve prompt with more examples

### If Too Slow

**Try:**
1. Use smaller model: `model: "llama3.2:1b"`
2. Reduce max files per test
3. Use quantized model

### If Inconsistent Results

**Try:**
1. Lower temperature: `temperature: 0.1`
2. Enable examples for consistency
3. Use better model

## 📝 Example Workflow

1. **Initial Test**
   ```swift
   try await ClassifierTuningTest.compareConfigurations(
       folderPath: "~/Downloads",
       maxFiles: 5
   )
   ```

2. **Review Results**
   - Check average confidence
   - Identify low-confidence files
   - Review recommendations

3. **Tune Configuration**
   ```swift
   let tunedClassifier = OllamaClassifier(
       model: "mistral:7b",      // Better model
       temperature: 0.1,         // More consistent
       useExamples: true         // Better accuracy
   )
   ```

4. **Re-test**
   ```swift
   let results = try await ClassifierTuningTest.testOnFolder(
       folderPath: "~/Downloads",
       classifier: tunedClassifier,
       maxFiles: 10
   )
   ClassifierTuningTest.analyzeAndRecommend(results: results)
   ```

5. **Iterate**
   - Adjust parameters based on results
   - Test on different folders
   - Fine-tune until satisfied

## 🎯 Quick Test Commands

### Test Single Folder
```swift
let classifier = OllamaClassifier(useExamples: true)
let results = try await ClassifierTuningTest.testOnFolder(
    folderPath: "~/Downloads",
    classifier: classifier,
    maxFiles: 10
)
```

### Compare All Configurations
```swift
try await ClassifierTuningTest.compareConfigurations(
    folderPath: "~/Documents",
    maxFiles: 5
)
```

### Test Multiple Folders
```swift
try await ClassifierTuningTest.testMultipleFolders(
    folders: ["~/Downloads", "~/Documents"],
    classifier: OllamaClassifier(useExamples: true),
    maxFilesPerFolder: 5
)
```

## 📊 Expected Output

```
🔍 Comparing Classifier Configurations
📁 Folder: ~/Downloads
============================================================

📄 Testing with 5 files

🧪 Testing: Default
----------------------------------------
   invoice.pdf
      → Documents/Invoices
      Confidence: 0.85
      Time: 342ms
...

📊 COMPARISON SUMMARY
============================================================

Configuration                    Avg Conf    Avg Time       Files
------------------------------------------------------------
Default                             82.50%        342ms           5
With Examples                       87.30%        398ms           5
Low Temp                            83.10%        335ms           5
...

💡 Recommendations:
   ✅ Best Confidence: With Examples (87.3%)
   ⚡ Fastest: Low Temp (335ms avg)
   ✅ Examples improve confidence by 4.8%
```

## 🚀 Next Steps

1. Run initial tests on your folders
2. Review results and recommendations
3. Tune configuration based on findings
4. Re-test to verify improvements
5. Use best configuration in production

---

**Last Updated:** 2024-12-20

