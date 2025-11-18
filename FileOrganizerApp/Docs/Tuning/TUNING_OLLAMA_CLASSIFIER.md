# Tuning Ollama LLM Service Guide

> **Note:** This guide references the old `OllamaClassifier` class. The current architecture uses `OllamaLLMService` with `FileClassificationManager`. The tuning principles remain the same, but implementation details have changed. See [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](../Architecture/ARCHITECTURE_MIGRATION_STATUS.md) for migration details.

## 🎯 Overview

This guide covers how to tune the Ollama LLM Service for better accuracy, performance, and results. Tuning involves:
1. **Prompt Engineering** - Improving the classification prompt
2. **Model Selection** - Choosing the right Ollama model
3. **Parameter Tuning** - Temperature, top_p, etc.
4. **System Prompts** - Adding context and examples
5. **Testing & Iteration** - Measuring improvements

---

## 1. Prompt Engineering

### Current Prompt Structure

The current prompt in `ClassificationPromptBuilder.buildPrompt()` includes:
- File metadata (name, size, type, dates)
- Author, keywords, whereFrom (if available)
- Sibling files context
- Content preview (if available)
- Classification instructions

### Tuning Strategies

#### A. Add Few-Shot Examples

**Why:** LLMs learn better from examples. Show the model what good classifications look like.

**How to Add:**

```swift
private func buildClassificationPrompt(metadata: FileMetadata) -> String {
    var prompt = """
    You are a file organization assistant. Classify files into categories and subfolders.
    
    Examples of good classifications:
    
    1. File: "invoice_2024_12.pdf"
       Author: "Accounting Department"
       Keywords: ["invoice", "billing"]
       Classification: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.95}
    
    2. File: "vacation_photo.jpg"
       Type: "image/jpeg"
       Parent: "Downloads"
       Classification: {"category": "Media", "subfolder": "Photos", "confidence": 0.90}
    
    3. File: "project_code.swift"
       Extension: "swift"
       Classification: {"category": "Projects", "subfolder": "Code", "confidence": 0.85}
    
    Now classify this file:
    
    File Information:
    - Name: \(metadata.fileName)
    ...
    """
    return prompt
}
```

#### B. Add Category Definitions

**Why:** Help the model understand what each category means.

**How to Add:**

```swift
prompt += """
Categories and their meanings:
- "Documents": Text files, PDFs, spreadsheets, presentations
- "Media": Images, videos, audio files
- "Work": Work-related documents, emails, reports
- "Personal": Personal files, photos, notes
- "Projects": Code, project files, development resources
- "Archive": Old files, backups, completed projects

Subfolders should be specific and descriptive:
- Documents: Invoices, Reports, Financial, Legal, Contracts
- Media: Photos, Videos, Music, Screenshots
- Work: Meetings, Reports, Presentations, Emails
- Personal: Photos, Notes, Recipes, Health
- Projects: Code, Documentation, Assets, Builds
- Archive: Old, Completed, Backup
"""
```

#### C. Add Classification Rules

**Why:** Provide explicit rules for common patterns.

**How to Add:**

```swift
prompt += """
Classification Rules:
1. If filename contains "invoice", "receipt", "bill" → Documents/Invoices or Documents/Financial
2. If filename contains "photo", "image", "pic" → Media/Photos
3. If extension is code (.swift, .js, .py) → Projects/Code
4. If author is a person name → Likely Personal
5. If author is department/company → Likely Work
6. If keywords include "financial", "accounting" → Documents/Financial
7. If "where from" contains "downloads" → Check if temporary
8. If parent folder is "Documents" → Keep in Documents category
9. If parent folder is "Downloads" → May need organization
10. Match subfolder to keywords when possible
"""
```

#### D. Improve Reasoning Instructions

**Why:** Better reasoning leads to better classifications.

**How to Add:**

```swift
prompt += """
When classifying, consider:
1. Primary indicators (filename, extension, type)
2. Secondary indicators (author, keywords, whereFrom)
3. Context (parent folder, sibling files)
4. Confidence based on indicator strength

Confidence scoring:
- 0.9-1.0: Very clear indicators (e.g., "invoice" in name + financial keywords)
- 0.7-0.9: Strong indicators (e.g., extension + filename pattern)
- 0.5-0.7: Moderate indicators (e.g., extension only)
- 0.0-0.5: Weak indicators (generic filename, no metadata)

Always provide reasoning that explains your decision.
"""
```

---

## 2. Model Selection

### Available Ollama Models

Different models have different trade-offs:

| Model | Size | Speed | Accuracy | Use Case |
|-------|------|-------|----------|----------|
| `llama3.2:1b` | ~1.3GB | ⚡⚡⚡ Fast | ⭐⭐ Good | Quick testing, low-resource |
| `llama3.2:3b` | ~2.0GB | ⚡⚡ Fast | ⭐⭐⭐ Better | Balanced performance |
| `mistral:7b` | ~4.1GB | ⚡ Medium | ⭐⭐⭐⭐ Great | Best accuracy |
| `llama3.1:8b` | ~4.7GB | ⚡ Medium | ⭐⭐⭐⭐⭐ Excellent | High accuracy needs |
| `llama3.2:1b-instruct-q4_K_M` | ~1.3GB | ⚡⚡⚡ Fast | ⭐⭐⭐ Good | Quantized, faster |

### How to Change Model

**Option 1: In Code**

```swift
// In LocalLLMClassifier.swift, modify init:
let llmService = OllamaLLMService(
    baseURL: URL(string: "http://localhost:11434")!,
    model: "mistral:7b"  // Change from "llama3.2:3b"
)
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: ClassificationPromptBuilder()
)
```

**Option 2: Make it Configurable**

Create with selected model:

```swift
let selectedModel = "llama3.2:3b"  // or "mistral:7b", etc.

let llmService = OllamaLLMService(model: selectedModel)
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: ClassificationPromptBuilder()
)
```

**Option 3: Test Different Models**

```bash
# Pull different models
ollama pull llama3.2:1b
ollama pull llama3.2:3b
ollama pull mistral:7b

# Test each one
# Update model in code and test
```

### Model Selection Guide

**For Speed:**
- Use `llama3.2:1b` or `llama3.2:1b-instruct-q4_K_M`
- Good for: Quick testing, large batches

**For Accuracy:**
- Use `mistral:7b` or `llama3.1:8b`
- Good for: Production use, important files

**For Balance:**
- Use `llama3.2:3b`
- Good for: General use, moderate accuracy needs

---

## 3. Parameter Tuning

### Current Implementation

The current `classify()` method doesn't use temperature or other parameters:

```swift
let requestBody: [String: Any] = [
    "model": model,
    "prompt": prompt,
    "stream": false,
    "format": "json"
]
```

### Adding Parameters

**Temperature** - Controls randomness (0.0 = deterministic, 1.0 = creative)

```swift
let requestBody: [String: Any] = [
    "model": model,
    "prompt": prompt,
    "stream": false,
    "format": "json",
    "options": [
        "temperature": 0.3,  // Lower = more consistent
        "top_p": 0.9,        // Nucleus sampling
        "top_k": 40,         // Top-k sampling
        "num_predict": 200   // Max tokens in response
    ]
]
```

**Recommended Settings:**

| Use Case | Temperature | Top_p | Top_k |
|----------|-------------|-------|-------|
| Consistent results | 0.1-0.3 | 0.9 | 40 |
| Balanced | 0.3-0.5 | 0.95 | 50 |
| More creative | 0.5-0.7 | 0.95 | 60 |

**For Classification:** Use **temperature: 0.1-0.3** for consistency.

### Updated Implementation

```swift
// Create OllamaLLMService with tuning parameters
let llmService = OllamaLLMService(
    baseURL: URL(string: "http://localhost:11434")!,
    model: "llama3.2:3b",
    temperature: 0.2,  // Low for consistency
    topP: 0.9,
    topK: 40
)

// Create prompt builder with examples
let promptBuilder = ClassificationPromptBuilder()
promptBuilder.useExamples = true

// Create manager
let manager = FileClassificationManager(
    llmService: llmService,
    telemetryService: TelemetryService.shared,
    fallbackClassifier: FallbackClassifier(),
    promptBuilder: promptBuilder
)

// Use manager to classify
let result = await manager.classifyFile(metadata)
```

---

## 4. System Prompts

### What is a System Prompt?

A system prompt sets the context and behavior for the LLM. Ollama supports system prompts.

### Adding System Prompt

**Option 1: In the Prompt**

```swift
private func buildClassificationPrompt(metadata: FileMetadata) -> String {
    let systemPrompt = """
    You are an expert file organization assistant. Your task is to classify files
    into logical categories and subfolders based on their metadata.
    
    Guidelines:
    - Be consistent with classifications
    - Use clear, descriptive subfolder names
    - Consider all available metadata
    - Provide confidence scores based on indicator strength
    - Always return valid JSON
    """
    
    let userPrompt = """
    File Information:
    - Name: \(metadata.fileName)
    ...
    """
    
    return systemPrompt + "\n\n" + userPrompt
}
```

**Option 2: Using Ollama's System Parameter**

```swift
let requestBody: [String: Any] = [
    "model": model,
    "system": systemPrompt,  // Ollama supports this
    "prompt": userPrompt,
    "stream": false,
    "format": "json",
    "options": [
        "temperature": 0.2
    ]
]
```

### Example System Prompt

```swift
let systemPrompt = """
You are a file organization assistant. Classify files into categories and subfolders.

Categories:
- Documents: Text files, PDFs, spreadsheets, presentations
- Media: Images, videos, audio files
- Work: Work-related documents, emails, reports
- Personal: Personal files, photos, notes
- Projects: Code, project files, development resources
- Archive: Old files, backups, completed projects

Rules:
1. Use filename patterns as primary indicator
2. Use author/keywords/whereFrom as secondary indicators
3. Match subfolder to keywords when possible
4. Provide confidence 0.0-1.0 based on indicator strength
5. Always return valid JSON with category, subfolder, confidence, reasoning

Examples:
- "invoice_2024.pdf" → {"category": "Documents", "subfolder": "Invoices", "confidence": 0.95}
- "vacation.jpg" → {"category": "Media", "subfolder": "Photos", "confidence": 0.90}
- "project.swift" → {"category": "Projects", "subfolder": "Code", "confidence": 0.85}
"""
```

---

## 5. Testing & Iteration

### A. Create Test Suite

**Test File Set:**

Create a test folder with diverse files:
```
test_files/
├── invoice_2024_12.pdf          # Should → Documents/Invoices
├── receipt_2024.pdf              # Should → Documents/Invoices
├── vacation_photo.jpg            # Should → Media/Photos
├── meeting_notes.docx            # Should → Documents/Meetings
├── project_code.swift            # Should → Projects/Code
├── financial_report.xlsx         # Should → Documents/Financial
└── ambiguous_file.pdf            # Test edge case
```

### B. Measure Accuracy

**Create Test Script:**

```swift
func testClassifierAccuracy() async {
    let llmService = OllamaLLMService(model: "llama3.2:3b")
    let manager = FileClassificationManager(
        llmService: llmService,
        telemetryService: TelemetryService.shared,
        fallbackClassifier: FallbackClassifier(),
        promptBuilder: ClassificationPromptBuilder()
    )
    
    let testFiles = [
        ("invoice_2024.pdf", "Documents", "Invoices"),
        ("photo.jpg", "Media", "Photos"),
        ("code.swift", "Projects", "Code"),
        // ... more test cases
    ]
    
    var correct = 0
    var total = 0
    
    for (filename, expectedCategory, expectedSubfolder) in testFiles {
        let url = URL(fileURLWithPath: "/path/to/\(filename)")
        if let metadata = FileMetadata.extract(from: url) {
            let result = await manager.classifyFile(metadata)
            
            total += 1
            if result.category == expectedCategory && 
               result.subfolder == expectedSubfolder {
                correct += 1
            }
            
            print("\(filename): \(result.category)/\(result.subfolder) (expected: \(expectedCategory)/\(expectedSubfolder))")
        }
    }
    
    print("Accuracy: \(Double(correct) / Double(total) * 100)%")
}

### C. A/B Testing Prompts

**Test Different Prompts:**

```swift
// Prompt Version A (current)
let promptA = buildClassificationPrompt(metadata: metadata)

// Prompt Version B (with examples)
let promptB = buildClassificationPromptWithExamples(metadata: metadata)

// Test both
let resultA = try await classifyWithPrompt(promptA, metadata: metadata)
let resultB = try await classifyWithPrompt(promptB, metadata: metadata)

// Compare results
print("A: \(resultA.category)/\(resultA.subfolder) (confidence: \(resultA.confidence))")
print("B: \(resultB.category)/\(resultB.subfolder) (confidence: \(resultB.confidence))")
```

### D. Logging & Analysis

**Add Logging:**

```swift
func classify(metadata: FileMetadata) async throws -> ClassificationResult {
    let prompt = buildClassificationPrompt(metadata: metadata)
    
    // Log the prompt (for debugging)
    if ProcessInfo.processInfo.environment["DEBUG_PROMPTS"] == "1" {
        print("📤 Prompt for \(metadata.fileName):")
        print(prompt)
        print("---")
    }
    
    // ... make request ...
    
    // Log the response
    if ProcessInfo.processInfo.environment["DEBUG_RESPONSES"] == "1" {
        print("📥 Response for \(metadata.fileName):")
        print(result)
        print("---")
    }
    
    return result
}
```

**Run with Debug:**

```bash
DEBUG_PROMPTS=1 DEBUG_RESPONSES=1 swift run
```

---

## 6. Performance Tuning

### A. Batch Processing

**Current:** Sequential processing (one at a time)

```swift
func classifyBatch(metadata: [FileMetadata]) async throws -> [ClassificationResult] {
    var results: [ClassificationResult] = []
    for meta in metadata {
        let result = try await classify(metadata: meta)
        results.append(result)
    }
    return results
}
```

**Optimized:** Parallel processing (if Ollama supports it)

```swift
func classifyBatch(metadata: [FileMetadata]) async throws -> [ClassificationResult] {
    return try await withThrowingTaskGroup(of: ClassificationResult.self) { group in
        for meta in metadata {
            group.addTask {
                try await self.classify(metadata: meta)
            }
        }
        
        var results: [ClassificationResult] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

**Note:** Ollama may process requests sequentially, so parallel may not help. Test to see.

### B. Caching

**Cache Similar Files:**

```swift
class OllamaClassifier: LLMClassifier {
    private var cache: [String: ClassificationResult] = [:]
    
    func classify(metadata: FileMetadata) async throws -> ClassificationResult {
        // Create cache key from filename pattern
        let cacheKey = createCacheKey(from: metadata)
        
        if let cached = cache[cacheKey] {
            return cached
        }
        
        let result = try await performClassification(metadata: metadata)
        cache[cacheKey] = result
        return result
    }
    
    private func createCacheKey(from metadata: FileMetadata) -> String {
        // Use extension + filename pattern
        return "\(metadata.fileExtension)_\(extractPattern(from: metadata.fileName))"
    }
}
```

### C. Model Quantization

**Use Quantized Models:**

Quantized models are smaller and faster:

```bash
# Pull quantized model
ollama pull llama3.2:1b-instruct-q4_K_M

# Use in code
let classifier = OllamaClassifier(model: "llama3.2:1b-instruct-q4_K_M")
```

**Quantization Levels:**
- `q4_K_M`: 4-bit, balanced (recommended)
- `q5_K_M`: 5-bit, better quality
- `q8_0`: 8-bit, highest quality

---

## 7. Advanced Techniques

### A. Chain-of-Thought Prompting

**Why:** Makes the LLM think step-by-step, improving accuracy.

**How:**

```swift
prompt += """
Think step by step:
1. Analyze the filename for patterns
2. Check the file extension and type
3. Review author, keywords, and whereFrom
4. Consider parent folder context
5. Look at sibling files for patterns
6. Make classification decision
7. Assign confidence score

Now provide your classification:
"""
```

### B. Confidence Thresholds

**Filter Low-Confidence Results:**

```swift
func classify(metadata: FileMetadata) async throws -> ClassificationResult {
    let result = try await performClassification(metadata: metadata)
    
    // If confidence is too low, use rule-based fallback
    if result.confidence < 0.5 {
        let ruleBased = RuleBasedClassifier()
        let fallback = try await ruleBased.classify(metadata: metadata)
        
        // Use fallback but note it's low confidence
        return ClassificationResult(
            category: fallback.category,
            subfolder: fallback.subfolder,
            confidence: fallback.confidence,
            reasoning: "Low LLM confidence, used rule-based fallback"
        )
    }
    
    return result
}
```

### C. Multi-Pass Classification

**First Pass:** Broad category
**Second Pass:** Specific subfolder

```swift
func classify(metadata: FileMetadata) async throws -> ClassificationResult {
    // First pass: Get category
    let categoryPrompt = buildCategoryPrompt(metadata: metadata)
    let categoryResult = try await classifyWithPrompt(categoryPrompt)
    
    // Second pass: Get subfolder within category
    let subfolderPrompt = buildSubfolderPrompt(
        metadata: metadata,
        category: categoryResult.category
    )
    let subfolderResult = try await classifyWithPrompt(subfolderPrompt)
    
    return ClassificationResult(
        category: categoryResult.category,
        subfolder: subfolderResult.subfolder,
        confidence: min(categoryResult.confidence, subfolderResult.confidence),
        reasoning: "Two-pass classification"
    )
}
```

---

## 8. Quick Tuning Checklist

### ✅ Prompt Tuning
- [ ] Add few-shot examples
- [ ] Add category definitions
- [ ] Add classification rules
- [ ] Improve reasoning instructions
- [ ] Add system prompt

### ✅ Model Selection
- [ ] Test different models (1b, 3b, 7b)
- [ ] Choose based on speed vs accuracy needs
- [ ] Consider quantized models for speed

### ✅ Parameters
- [ ] Set temperature (0.1-0.3 for consistency)
- [ ] Set top_p (0.9)
- [ ] Set top_k (40)
- [ ] Limit response length (num_predict: 200)

### ✅ Testing
- [ ] Create test file set
- [ ] Measure accuracy
- [ ] A/B test different prompts
- [ ] Add logging for debugging

### ✅ Performance
- [ ] Test parallel vs sequential
- [ ] Consider caching
- [ ] Use quantized models if needed

---

## 9. Example: Complete Tuned Implementation

```swift
class OllamaClassifier: LLMClassifier {
    let baseURL: URL
    let model: String
    let temperature: Double
    let useExamples: Bool
    
    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "llama3.2:1b",
        temperature: Double = 0.2,
        useExamples: Bool = true
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.useExamples = useExamples
    }
    
    private func buildClassificationPrompt(metadata: FileMetadata) -> String {
        var prompt = ""
        
        // System prompt
        prompt += """
        You are an expert file organization assistant. Classify files into categories and subfolders.
        
        Categories:
        - Documents: Text files, PDFs, spreadsheets, presentations
        - Media: Images, videos, audio files
        - Work: Work-related documents, emails, reports
        - Personal: Personal files, photos, notes
        - Projects: Code, project files, development resources
        - Archive: Old files, backups, completed projects
        
        """
        
        // Few-shot examples (if enabled)
        if useExamples {
            prompt += """
            Examples:
            1. "invoice_2024.pdf" + keywords: ["invoice"] → {"category": "Documents", "subfolder": "Invoices", "confidence": 0.95}
            2. "vacation.jpg" + type: "image/jpeg" → {"category": "Media", "subfolder": "Photos", "confidence": 0.90}
            3. "code.swift" + extension: "swift" → {"category": "Projects", "subfolder": "Code", "confidence": 0.85}
            
            """
        }
        
        // File information
        prompt += """
        File Information:
        - Name: \(metadata.fileName)
        - Extension: \(metadata.fileExtension)
        - Size: \(metadata.fileSizeFormatted)
        - Type: \(metadata.mimeType ?? metadata.fileType ?? "unknown")
        - Modified: \(metadata.modificationDate?.formatted() ?? "unknown")
        - Parent Folder: \(metadata.parentFolder ?? "root")
        - Patterns: \(metadata.commonPatterns.joined(separator: ", "))
        """
        
        if let author = metadata.author, !author.isEmpty {
            prompt += "\n- Author: \(author)"
        }
        if let keywords = metadata.keywords, !keywords.isEmpty {
            prompt += "\n- Keywords: \(keywords.joined(separator: ", "))"
        }
        if let whereFrom = metadata.whereFrom, !whereFrom.isEmpty {
            prompt += "\n- Where From: \(whereFrom)"
        }
        
        // Instructions
        prompt += """
        
        
        Classify this file. Consider:
        1. Filename patterns and keywords
        2. File type and extension
        3. Author, keywords, whereFrom (if available)
        4. Parent folder context
        5. Sibling files context
        
        Respond in JSON format:
        {
            "category": "category_name",
            "subfolder": "subfolder_name",
            "confidence": 0.0-1.0,
            "reasoning": "brief explanation"
        }
        """
        
        return prompt
    }
    
    func classify(metadata: FileMetadata) async throws -> ClassificationResult {
        let prompt = buildClassificationPrompt(metadata: metadata)
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "format": "json",
            "options": [
                "temperature": temperature,
                "top_p": 0.9,
                "top_k": 40,
                "num_predict": 200
            ]
        ]
        
        // ... rest of implementation
    }
}
```

---

## 10. Monitoring & Metrics

### Track These Metrics

1. **Accuracy Rate**
   - % of files classified correctly
   - Track by file type, category

2. **Confidence Distribution**
   - Average confidence score
   - % of low-confidence (<0.5) classifications

3. **Performance**
   - Average classification time
   - Throughput (files/second)

4. **Error Rate**
   - % of failed classifications
   - Parse errors, API errors

### Create Dashboard

```swift
struct ClassificationMetrics {
    var totalFiles: Int = 0
    var correctClassifications: Int = 0
    var averageConfidence: Double = 0.0
    var averageTime: TimeInterval = 0.0
    var errors: Int = 0
    
    var accuracy: Double {
        totalFiles > 0 ? Double(correctClassifications) / Double(totalFiles) : 0.0
    }
}
```

---

## 🎯 Summary

**Quick Wins:**
1. ✅ Add few-shot examples to prompt
2. ✅ Set temperature to 0.2 for consistency
3. ✅ Add category definitions
4. ✅ Test different models (try mistral:7b)

**Medium Effort:**
1. ✅ Add system prompt
2. ✅ Implement confidence thresholds
3. ✅ Add logging for debugging
4. ✅ Create test suite

**Advanced:**
1. ✅ Multi-pass classification
2. ✅ Caching
3. ✅ Chain-of-thought prompting
4. ✅ Performance optimization

**Start with quick wins, then iterate based on results!**

---

**Last Updated:** 2024-12-20

