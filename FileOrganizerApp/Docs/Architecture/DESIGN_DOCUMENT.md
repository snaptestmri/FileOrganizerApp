# AI File Classification - Design Document

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Component Design](#component-design)
4. [Data Flow](#data-flow)
5. [Class Diagrams](#class-diagrams)
6. [Sequence Diagrams](#sequence-diagrams)
7. [API Contracts](#api-contracts)
8. [Error Handling](#error-handling)
9. [Performance Considerations](#performance-considerations)
10. [Security & Privacy](#security--privacy)

---

## Overview

### Purpose
The AI File Classification system intelligently organizes files using LLM-based classification, supporting both online (cloud) and offline (local) modes.

### Key Features
- **Metadata-only classification** - No file content sent to LLM
- **Multiple classifier backends** - Ollama (local), OpenAI (cloud), Rule-based (fallback)
- **Offline support** - Works without internet connection
- **Batch processing** - Efficient handling of multiple files
- **Progress tracking** - Real-time updates during classification

### Design Principles
1. **Privacy First** - Only metadata, never file content
2. **Offline Capable** - Local LLM support for complete privacy
3. **Extensible** - Easy to add new classifier providers
4. **Resilient** - Automatic fallback chain
5. **User Control** - User selects classifier and reviews results

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface Layer                      │
├─────────────────────────────────────────────────────────────────┤
│  ContentView → FolderSelectionView → AIClassificationView       │
│                    ↓                        ↓                    │
│              OrganizationMode          Classifier Selection      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Business Logic Layer                        │
├─────────────────────────────────────────────────────────────────┤
│  AIClassifierMover  │  FileMetadata  │  FileClassificationManager│
│         ↓                  ↓                    ↓                │
│   File Organization   Metadata Extraction   Classification      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Classification Layer                        │
├─────────────────────────────────────────────────────────────────┤
│  LLMService Protocol (Interface)                                │
│         ├── OllamaLLMService (Local, Offline)                    │
│         ├── OpenAILLMService (Cloud, Online)                     │
│         ├── AnthropicLLMService (Cloud, Online)                  │
│         └── MockLLMService (Testing)                             │
│  FallbackClassifier (Rule-Based, Always Available)              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      External Services                           │
├─────────────────────────────────────────────────────────────────┤
│  Ollama Server (localhost:11434)  │  OpenAI API (api.openai.com)│
│  Local LLM Models                 │  Cloud LLM Service          │
└─────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
┌──────────────┐
│   User       │
└──────┬───────┘
       │
       │ 1. Select Folder
       ▼
┌─────────────────────┐
│ FolderSelectionView │
└──────┬──────────────┘
       │
       │ 2. Choose Mode (AI/Keywords)
       ▼
┌──────────────────────┐
│ AIClassificationView │
└──────┬───────────────┘
       │
       │ 3. Select Classifier
       ▼
┌──────────────────────┐
│ FileClassificationManager │──┐
└──────┬─────────────────────┘  │
       │                  │ 4. Get Available
       │                  │    Classifiers
       │                  │
       │ 5. Start Classification
       ▼                  │
┌──────────────────────┐  │
│ AIClassifierMover    │  │
└──────┬───────────────┘  │
       │                  │
       │ 6. Extract Metadata
       ▼                  │
┌──────────────────────┐  │
│ FileMetadata         │  │
└──────┬───────────────┘  │
       │                  │
       │ 7. Classify
       ▼                  │
┌──────────────────────┐  │
│ LLMService           │◄─┘
│ (Ollama/OpenAI/Anthropic/Mock) │
│ FallbackClassifier   │
└──────┬───────────────┘
       │
       │ 8. Return Classification
       ▼
┌──────────────────────┐
│ Move Files            │
└──────────────────────┘
```

---

## Component Design

### 1. User Interface Components

#### FolderSelectionView
```
┌─────────────────────────────────────────┐
│         FolderSelectionView              │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - selectedFolderPath: String            │
│  - organizationMode: OrganizationMode    │
│  - showOrganizer: Bool                   │
│  - showAIClassifier: Bool                 │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  - selectFolder()                        │
│  - runOrganizer()                        │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Folder selection UI
- Mode selection (Keyword vs AI)
- Navigation to appropriate organizer view

#### AIClassificationView
```
┌─────────────────────────────────────────┐
│       AIClassificationView              │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - classificationManager: FileClassificationManager  │
│  - selectedServiceType: ServiceType      │
│  - isRunning: Bool                       │
│  - progress: Double                      │
│  - classifications: [(Metadata, Result)] │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  - startClassification()                │
│  - stopClassification()                  │
│  - addActivity()                         │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Display available classifiers
- Show classification progress
- Display results and activities
- Handle user interactions

### 2. Business Logic Components

#### AIClassifierMover
```
┌─────────────────────────────────────────┐
│         AIClassifierMover               │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - sourceFolder: URL                     │
│  - baseTargetFolder: URL                 │
│  - classificationManager: FileClassificationManager │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + runWithProgress(                      │
│      progressCallback,                   │
│      classificationCallback              │
│    ) async throws -> FileMoveResults     │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Extract file metadata
- Batch files for classification
- Coordinate classification and file movement
- Track progress and report results

#### FileMetadata
```
┌─────────────────────────────────────────┐
│           FileMetadata                  │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - fileName: String                      │
│  - fileExtension: String                 │
│  - fileSize: Int64                       │
│  - modificationDate: Date?               │
│  - fileType: String?                     │
│  - parentFolder: String?                 │
│  - siblingFiles: [String]?               │
│  - commonPatterns: [String]              │
│  - contentPreview: String? (optional)    │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + extract(from: URL) -> FileMetadata?   │
│  + toJSONString() -> String?             │
│  + toDescription() -> String             │
└─────────────────────────────────────────┘
```

**Responsibilities:**
- Extract metadata from files
- Format metadata for LLM consumption
- Provide human-readable descriptions

### 3. Classification Layer

#### LLMService Protocol
```
┌─────────────────────────────────────────┐
│        LLMService Protocol              │
├─────────────────────────────────────────┤
│ Properties:                              │
│  + isAvailable: Bool { get }             │
│  + name: String { get }                  │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + classify(metadata)                   │
│      async throws -> ClassificationResult│
│  + classifyBatch(metadata)               │
│      async throws -> [ClassificationResult]│
└─────────────────────────────────────────┘
```

**Implementations:**

```
┌──────────────────────┐
│  LLMService          │
└──────────┬───────────┘
           │
    ┌──────┴──────┬──────────────┐
    │             │              │
    ▼             ▼              ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐
│ OllamaLLM │ │ OpenAILLM │ │ Fallback    │
│ Service   │ │ Service   │ │ Classifier  │
└───────────┘ └───────────┘ └─────────────┘
```

#### OllamaLLMService
```
┌─────────────────────────────────────────┐
│         OllamaLLMService                │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - baseURL: URL (localhost:11434)        │
│  - model: String (e.g., "llama3.2:3b")  │
│  - temperature: Double                   │
│  - topP: Double                           │
│  - topK: Int                              │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + generateCompletion(prompt) -> String │
└─────────────────────────────────────────┘
```

**Communication:**
```
OllamaLLMService → HTTP POST → Ollama Server
                    ↓
              JSON Response
                    ↓
         ClassificationResult
```

#### OpenAILLMService
```
┌─────────────────────────────────────────┐
│         OpenAILLMService                │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - apiKey: String                        │
│  - model: String (e.g., "gpt-4")        │
│  - maxTokens: Int                        │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + generateCompletion(prompt) -> String │
└─────────────────────────────────────────┘
```

**Communication:**
```
OpenAILLMService → HTTPS POST → OpenAI API
                      ↓
                JSON Response
                      ↓
           ClassificationResult
```

#### FallbackClassifier
```
┌─────────────────────────────────────────┐
│       FallbackClassifier               │
├─────────────────────────────────────────┤
│ Properties:                              │
│  (No external dependencies)              │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + classify(metadata) -> Result          │
│  + determineCategoryFromExtension()      │
│  + determineSubfolder()                  │
└─────────────────────────────────────────┘
```

**Logic:**
```
File Extension → Category Mapping
File Name Patterns → Subfolder Mapping
No external calls - instant classification
```

#### FileClassificationManager
```
┌─────────────────────────────────────────┐
│     FileClassificationManager          │
├─────────────────────────────────────────┤
│ Properties:                              │
│  - llmService: LLMService                │
│  - fallbackClassifier: FallbackClassifier│
│  - promptBuilder: ClassificationPromptBuilder│
│  - telemetryService: TelemetryService    │
├─────────────────────────────────────────┤
│ Methods:                                 │
│  + classifyFile(metadata) -> Result      │
│  + classifyFiles([metadata]) -> [Result]│
└─────────────────────────────────────────┘
```

**Fallback Chain:**
```
1. Try LLMService (Ollama/OpenAI/Anthropic)
2. FallbackClassifier (always available)
```

---

## Data Flow

### Classification Request Flow

```
┌──────────┐
│   File  │
└────┬─────┘
     │
     │ 1. Extract Metadata
     ▼
┌──────────────┐
│ FileMetadata │
│  - fileName  │
│  - size      │
│  - type      │
│  - dates     │
│  - patterns  │
└────┬─────────┘
     │
     │ 2. Build Prompt
     ▼
┌──────────────┐
│   Prompt     │
│  "Classify   │
│   this file  │
│   based on   │
│   metadata"  │
└────┬─────────┘
     │
     │ 3. Send to LLM
     ▼
┌──────────────┐
│ LLMService   │
│  (Ollama/    │
│   OpenAI/    │
│   Anthropic/ │
│   Mock)      │
│ FallbackClassifier │
└────┬─────────┘
     │
     │ 4. Get Response
     ▼
┌──────────────┐
│ Classification│
│   Result     │
│  - category  │
│  - subfolder │
│  - confidence│
└────┬─────────┘
     │
     │ 5. Move File
     ▼
┌──────────────┐
│ Organized    │
│   File       │
└──────────────┘
```

### Batch Processing Flow

```
Files: [File1, File2, ..., FileN]
         │
         │ Group into batches (size: 10)
         ▼
    ┌─────────┐
    │ Batch 1 │ → Classify → Results 1
    │ Batch 2 │ → Classify → Results 2
    │ Batch 3 │ → Classify → Results 3
    │   ...   │
    └─────────┘
         │
         │ Merge Results
         ▼
    All Classifications
         │
         │ Move Files
         ▼
    Organized Files
```

---

## Class Diagrams

### Core Classification Classes

```
┌─────────────────────┐
│   LLMService        │ (Protocol)
│  + generateCompletion() │
└──────────┬──────────┘
           │
    ┌──────┴──────┬──────────────┐
    │             │              │
    ▼             ▼              ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐
│ OllamaLLM│ │ OpenAILLM│ │ Fallback    │
│ Service  │ │ Service  │ │ Classifier   │
└──────────┘ └──────────┘ └──────────────┘
```

### Data Model Classes

```
┌─────────────────────┐
│   FileMetadata      │
│  - fileName         │
│  - fileSize         │
│  - fileType         │
│  - dates            │
│  - patterns         │
│  + extract()        │
│  + toJSONString()   │
└──────────┬──────────┘
           │
           │ uses
           ▼
┌─────────────────────┐
│ ClassificationResult│
│  - category         │
│  - subfolder        │
│  - confidence       │
│  - reasoning        │
└─────────────────────┘
```

### Manager Classes

```
┌─────────────────────┐
│ FileClassificationManager │
│  - llmService: LLMService  │
│  - fallbackClassifier      │
│  - promptBuilder           │
│  + classifyFile()          │
└──────────┬─────────────────┘
           │
           │ uses
           ▼
┌─────────────────────┐
│  LLMService         │
│  FallbackClassifier │
└─────────────────────┘
```

---

## Sequence Diagrams

### AI Classification Sequence

```
User    AIClassificationView    FileClassificationManager    AIClassifierMover    LLMService    FileSystem
 │              │                       │                    │                  │              │
 │──Select Folder──────────────────────>│                    │                  │              │
 │              │                       │                    │                  │              │
 │──Start Classification───────────────>│                    │                  │              │
 │              │                       │                    │                  │              │
 │              │──Start Processing────>│                    │                  │              │
 │              │                       │                    │                  │              │
 │              │                       │──Extract Metadata──>│                  │              │
 │              │                       │                    │──Read File───────>│              │
 │              │                       │                    │<──Metadata────────│              │
 │              │                       │                    │                  │              │
 │              │                       │──Classify──────────>│                  │              │
 │              │                       │                    │                  │              │
 │              │                       │                    │──Generate─────────>│              │
 │              │                       │                    │                  │──Process─────>│
 │              │                       │                    │<──Result──────────│              │
 │              │                       │<──Classification────│                  │              │
 │              │<──Progress Update─────│                    │                  │              │
 │              │                       │                    │                  │              │
 │              │                       │──Move File─────────>│                  │              │
 │              │                       │                    │                  │──Move───────>│
 │              │                       │                    │                  │<──Success────│
 │              │<──Progress Update─────│                    │                  │              │
 │              │                       │                    │                  │              │
 │<──Results─────────────────────────────│                    │                  │              │
```

### Fallback Chain Sequence

```
AIClassificationView    FileClassificationManager    OllamaLLM    Fallback    OpenAILLM
 │              │              │              │            │          │
 │──Get Classifier─────────────>│              │            │          │
 │              │              │              │            │          │
 │              │──Try Ollama──>│              │            │          │
 │              │              │──Check──────>│            │          │
 │              │              │<──Unavailable│            │          │
 │              │              │              │            │          │
 │              │──Try Rule────>│              │            │          │
 │              │              │              │──Available>│          │
 │              │<──Return──────│              │            │          │
 │<──Classifier─────────────────│              │            │          │
```

---

## API Contracts

### LLMService Protocol

```swift
protocol LLMService {
    func generateCompletion(prompt: String) async throws -> String
}
```

**Note:** `LLMService` only handles prompt generation. Classification logic is handled by `FileClassificationManager` which uses `LLMService` for LLM calls and `FallbackClassifier` for rule-based classification.

### ClassificationResult

```swift
struct ClassificationResult: Codable {
    let category: String      // e.g., "Documents", "Media", "Work"
    let subfolder: String     // e.g., "Invoices", "Photos", "Reports"
    let confidence: Double    // 0.0 to 1.0
    let reasoning: String?   // Optional explanation
}
```

### FileMetadata

```swift
struct FileMetadata: Codable {
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let fileSizeFormatted: String
    let modificationDate: Date?
    let fileType: String?
    let parentFolder: String?
    let siblingFiles: [String]?
    let commonPatterns: [String]
    let contentPreview: String?  // Optional, only for text files
}
```

### Prompt Template

```
Analyze this file metadata and classify it into a category and subfolder.

File Information:
- Name: {fileName}
- Extension: {fileExtension}
- Size: {fileSizeFormatted}
- Type: {fileType}
- Modified: {modificationDate}
- Parent Folder: {parentFolder}
- Patterns: {commonPatterns}

{contentPreview if available}

Based on this information, classify the file into:
1. A category (e.g., "Documents", "Media", "Work", "Personal", "Projects", "Archive")
2. A subfolder within that category (e.g., "Financial", "Photos", "Reports", "Invoices")

Respond in JSON format:
{
    "category": "category_name",
    "subfolder": "subfolder_name",
    "confidence": 0.0-1.0,
    "reasoning": "brief explanation"
}
```

---

## Error Handling

### Error Types

```
┌──────────────────────┐
│ ClassificationError   │ (Enum)
├──────────────────────┤
│ - apiError(String)   │
│ - parseError(String) │
│ - unavailable(String)│
└──────────────────────┘
```

### Error Handling Flow

```
┌─────────────────────────────────────────┐
│         Error Handling Strategy         │
├─────────────────────────────────────────┤
│ 1. API Error                            │
│    → Retry with exponential backoff    │
│    → Fallback to next classifier       │
│                                         │
│ 2. Parse Error                          │
│    → Log error                          │
│    → Skip file                          │
│    → Continue with next file           │
│                                         │
│ 3. Unavailable Service                  │
│    → Try next classifier in chain      │
│    → Use RuleBased as final fallback   │
│                                         │
│ 4. File System Error                    │
│    → Log error                          │
│    → Increment error count              │
│    → Continue processing                │
└─────────────────────────────────────────┘
```

### Retry Logic

```
Attempt 1 → Wait 1s → Attempt 2 → Wait 2s → Attempt 3 → Fallback
```

---

## Performance Considerations

### Optimization Strategies

```
┌─────────────────────────────────────────┐
│      Performance Optimizations          │
├─────────────────────────────────────────┤
│ 1. Batch Processing                     │
│    - Group 10-20 files per API call     │
│    - Reduces API overhead                │
│                                         │
│ 2. Parallel Processing                  │
│    - Process multiple batches concurrently│
│    - Use async/await for concurrency    │
│                                         │
│ 3. Caching                               │
│    - Cache classifications by filename  │
│    - Avoid re-classifying similar files │
│                                         │
│ 4. Metadata Extraction                   │
│    - Extract once, reuse                 │
│    - Lazy loading for large folders     │
│                                         │
│ 5. Progress Reporting                   │
│    - Throttle updates (max 10/sec)      │
│    - Batch UI updates                    │
└─────────────────────────────────────────┘
```

### Performance Metrics

```
┌─────────────────────────────────────────┐
│         Target Performance               │
├─────────────────────────────────────────┤
│ Rule-Based:  < 10ms per file            │
│ Ollama:      100-500ms per file          │
│ OpenAI:      200-1000ms per file         │
│                                         │
│ Batch Size:  10-20 files optimal         │
│ Max Concurrent: 3-5 batches             │
└─────────────────────────────────────────┘
```

---

## Security & Privacy

### Privacy Model

```
┌─────────────────────────────────────────┐
│         Privacy Architecture             │
├─────────────────────────────────────────┤
│ ✅ Metadata Only                         │
│    - Filename, size, dates, type        │
│    - NO file content                     │
│                                         │
│ ✅ Local Processing                      │
│    - Ollama runs on localhost            │
│    - No data leaves device               │
│                                         │
│ ✅ Optional Cloud                        │
│    - User explicitly chooses             │
│    - Clear privacy warnings              │
│                                         │
│ ✅ Secure Storage                        │
│    - API keys in Keychain                │
│    - No credentials in logs              │
└─────────────────────────────────────────┘
```

### Data Flow Privacy

```
┌──────────┐
│   File   │
└────┬─────┘
     │
     │ Extract ONLY metadata
     ▼
┌──────────────┐
│ FileMetadata │ ← No content, only metadata
└────┬─────────┘
     │
     │ Send to classifier
     ▼
┌──────────────┐
│ LLMService   │
│  (Local or   │
│   Cloud)     │
└──────────────┘
```

---

## Extension Points

### Adding New Classifiers

```
1. Implement LLMService protocol
2. Create FileClassificationManager with new service
3. Configure in settings (if needed)
4. Test with sample files
```

### Custom Classification Rules

```
1. Extend FallbackClassifier
2. Add custom pattern matching
3. Define category mappings
4. Integrate with existing system
```

---

## Testing Strategy

### Unit Tests
- FileMetadata extraction
- Classification result parsing
- Error handling
- Batch processing logic

### Integration Tests
- Ollama connectivity
- OpenAI API calls
- File movement operations
- Progress tracking

### End-to-End Tests
- Complete classification workflow
- Fallback chain behavior
- UI interactions
- Error recovery

---

## Future Enhancements

1. **Learning System** - Learn from user corrections
2. **Custom Prompts** - User-defined classification rules
3. **Image Classification** - Vision models for images
4. **Document Understanding** - Extract metadata from PDFs
5. **Smart Renaming** - Suggest better filenames
6. **Duplicate Detection** - Semantic duplicate finding

---

## Appendix

### File Structure

```
FileOrganizerApp/
├── Models/
│   ├── Core/
│   │   ├── FileMetadata.swift
│   │   ├── ClassificationResult.swift
│   │   └── KeywordEntry.swift
│   ├── Services/
│   │   ├── Classification/
│   │   │   ├── FileClassificationManager.swift
│   │   │   ├── FallbackClassifier.swift
│   │   │   └── ClassificationPromptBuilder.swift
│   │   ├── LLM/
│   │   │   ├── LLMService.swift (protocol)
│   │   │   ├── OllamaLLMService.swift
│   │   │   ├── OpenAILLMService.swift
│   │   │   ├── AnthropicLLMService.swift
│   │   │   └── MockLLMService.swift
│   │   ├── TelemetryService.swift
│   │   ├── ABTestingService.swift
│   │   ├── AIClassifierMover.swift
│   │   └── FileMover.swift
│   ├── Storage/
│   │   └── KeywordStore.swift
│   └── Constants/
│       └── ClassificationConstants.swift
├── Views/
│   ├── AIClassificationView.swift
│   ├── FolderSelectionView.swift
│   ├── ContentView.swift
│   └── (other view files)
└── Docs/
    ├── Architecture/
    │   ├── DESIGN_DOCUMENT.md (this file)
    │   ├── ARCHITECTURE_BLOCKS.md
    │   └── ARCHITECTURE_MIGRATION_STATUS.md
    ├── Testing/
    ├── Tuning/
    └── Guides/
```

### Dependencies

- SwiftUI (UI framework)
- Foundation (File operations)
- UniformTypeIdentifiers (File type detection)
- URLSession (HTTP requests for LLM APIs)

---

**Document Version:** 1.0  
**Last Updated:** 2024-12-20  
**Author:** File Organizer App Team

