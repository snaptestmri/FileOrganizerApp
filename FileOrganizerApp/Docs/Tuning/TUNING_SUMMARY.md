# Classifier Tuning Test Suite - Summary

## ✅ What's Been Created

### 1. **ClassifierTuningTest.swift** - Main Test Framework
   - Test classifier on real folders
   - Compare multiple configurations
   - Collect metrics (confidence, time, distribution)
   - Generate recommendations

### 2. **QuickTuningTest.swift** - Quick Start Script
   - Simple test script you can run immediately
   - Tests default vs tuned configurations
   - Provides quick feedback

### 3. **TUNING_TEST_GUIDE.md** - Complete Guide
   - How to run tests
   - Understanding results
   - Tuning strategies
   - Example workflows

## 🚀 Quick Start

### Step 1: Ensure Ollama is Running

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# If not, start it
ollama serve

# In another terminal, download a model
ollama pull llama3.2:1b
```

### Step 2: Run Quick Test

Edit `QuickTuningTest.swift`:
- Update `testFolder` to your folder path
- Adjust `maxFiles` if needed

Then run as a test or create a simple command-line tool.

### Step 3: Review Results

The test will show:
- ✅ Average confidence scores
- ⏱️ Classification times
- 📊 Category distributions
- 💡 Tuning recommendations

### Step 4: Tune Configuration

Based on results, adjust:
- Model (llama3.2:1b vs mistral:7b)
- Temperature (0.1-0.3)
- Examples (true/false)

## 📊 Test Capabilities

### 1. Configuration Comparison
Tests multiple configurations side-by-side:
- Default
- With Examples
- Low Temperature
- Better Model

**Output:**
- Comparison table
- Best configuration recommendation
- Performance metrics

### 2. Multi-Folder Testing
Tests classifier across different folders:
- Downloads
- Documents
- Desktop
- Custom folders

**Output:**
- Per-folder statistics
- Overall performance
- Category distribution

### 3. Analysis & Recommendations
Analyzes results and suggests improvements:
- Low-confidence file identification
- Tuning recommendations
- Performance insights

## 🎯 Example Test Results

```
📊 COMPARISON SUMMARY
============================================================

Configuration                    Avg Conf    Avg Time       Files
------------------------------------------------------------
Default                             82.50%        342ms           5
With Examples                       87.30%        398ms           5
Low Temp                            83.10%        335ms           5
With Examples + Low Temp            88.20%        401ms           5
Better Model                        91.50%        512ms           5

💡 Recommendations:
   ✅ Best Confidence: Better Model (91.5%)
   ⚡ Fastest: Low Temp (335ms avg)
   ✅ Examples improve confidence by 4.8%
```

## 🔧 Tuning Workflow

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

3. **Create Tuned Configuration**
   ```swift
   let llmService = OllamaLLMService(
       model: "mistral:7b",      // Better model
       temperature: 0.1          // More consistent
   )
   let promptBuilder = ClassificationPromptBuilder()
   promptBuilder.useExamples = true  // Better accuracy
   
   let manager = FileClassificationManager(
       llmService: llmService,
       telemetryService: TelemetryService.shared,
       fallbackClassifier: FallbackClassifier(),
       promptBuilder: promptBuilder
   )
   ```

4. **Re-test**
   ```swift
   let results = try await ClassifierTuningTest.testOnFolder(
       folderPath: "~/Downloads",
       classifier: tunedClassifier,
       maxFiles: 10
   )
   ```

5. **Iterate**
   - Adjust based on results
   - Test on different folders
   - Fine-tune until satisfied

## 📈 Metrics Tracked

### Confidence
- Average confidence across all files
- High-confidence count (≥0.8)
- Low-confidence count (<0.5)
- Per-file confidence scores

### Performance
- Average classification time
- Total processing time
- Files per second

### Distribution
- Category distribution
- Subfolder distribution
- Per-folder breakdown

## 💡 Common Tuning Scenarios

### Scenario 1: Low Average Confidence (<0.7)

**Solution:**
```swift
let llmService = OllamaLLMService(model: "mistral:7b")
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true  // Enable examples
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

### Scenario 2: Inconsistent Results

**Solution:**
```swift
let llmService = OllamaLLMService(temperature: 0.1)  // Lower = more consistent
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

### Scenario 3: Too Slow

**Solution:**
```swift
let llmService = OllamaLLMService(model: "llama3.2:1b")  // Smaller = faster
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = false  // Disable examples
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

### Scenario 4: Many Low-Confidence Files

**Solution:**
```swift
let llmService = OllamaLLMService(
    model: "mistral:7b",     // Better model
    temperature: 0.1         // More consistent
)
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true  // Better accuracy
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)
```

## 🎓 Next Steps

1. **Run Initial Tests**
   - Test on your actual folders
   - Compare configurations
   - Review recommendations

2. **Tune Configuration**
   - Adjust based on results
   - Test different models
   - Fine-tune parameters

3. **Validate on More Folders**
   - Test on different folder types
   - Verify consistency
   - Check edge cases

4. **Use in Production**
   - Apply best configuration
   - Monitor performance
   - Iterate as needed

## 📚 Files Reference

- **ClassifierTuningTest.swift** - Main test framework
- **QuickTuningTest.swift** - Quick start script
- **TUNING_TEST_GUIDE.md** - Detailed guide
- **TUNING_OLLAMA_CLASSIFIER.md** - Tuning documentation
- **QUICK_TUNING_REFERENCE.md** - Quick reference

## 🚨 Troubleshooting

### Ollama Not Available
```bash
# Check if running
curl http://localhost:11434/api/tags

# Start if not running
ollama serve

# Download model
ollama pull llama3.2:1b
```

### Low Confidence Results
- Enable examples: `useExamples: true`
- Use better model: `model: "mistral:7b"`
- Lower temperature: `temperature: 0.1`

### Slow Performance
- Use smaller model: `model: "llama3.2:1b"`
- Disable examples: `useExamples: false`
- Reduce test files: `maxFiles: 3`

### Errors
- Check Ollama is running
- Verify model is downloaded
- Check folder paths are correct

---

**Ready to test!** Start with `QuickTuningTest.swift` and iterate from there.

