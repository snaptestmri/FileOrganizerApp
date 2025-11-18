# How Ollama LLM Service Works With Your Data

> **Note:** Updated for new architecture using `OllamaLLMService` with `FileClassificationManager`.

## 🔄 Complete Data Flow

```
┌──────────────┐
│  Your File   │
│ invoice.pdf  │
└──────┬───────┘
       │
       │ 1. Extract Metadata (NO file content read)
       ▼
┌─────────────────────────────────────────┐
│      FileMetadata Extraction            │
│  - fileName: "invoice.pdf"              │
│  - fileSize: 2458624                    │
│  - fileType: "application/pdf"         │
│  - modificationDate: 2024-12-20         │
│  - author: "John Doe" (if available)   │
│  - keywords: ["financial", "report"]    │
│  - whereFrom: "https://..." (if available)│
│  - parentFolder: "Documents"            │
│  - patterns: ["contains_date"]          │
│  - NO file content                      │
└──────┬──────────────────────────────────┘
       │
       │ 2. Build Prompt
       ▼
┌─────────────────────────────────────────┐
│      Classification Prompt              │
│                                         │
│  "Analyze this file metadata...        │
│   File Information:                    │
│   - Name: invoice.pdf                   │
│   - Size: 2.5 MB                        │
│   - Type: application/pdf               │
│   - Author: John Doe                    │
│   - Keywords: financial, report         │
│   - Where From: https://example.com     │
│   ...                                   │
│   Classify into category/subfolder"    │
└──────┬──────────────────────────────────┘
       │
       │ 3. Send to Ollama (localhost)
       ▼
┌─────────────────────────────────────────┐
│      Ollama Server                      │
│      (Running on your Mac)              │
│      localhost:11434                    │
│                                         │
│  HTTP POST /api/generate                │
│  {                                       │
│    "model": "llama3.2:1b",              │
│    "prompt": "...",                     │
│    "format": "json"                     │
│  }                                       │
└──────┬──────────────────────────────────┘
       │
       │ 4. LLM Processes (locally)
       ▼
┌─────────────────────────────────────────┐
│      LLM Model (llama3.2:1b)            │
│      (Running on your Mac's CPU/GPU)    │
│                                         │
│  Analyzes metadata:                     │
│  - "invoice.pdf" → Financial document   │
│  - "application/pdf" → Document type   │
│  - Author "John Doe" → Work document    │
│  - Keywords "financial" → Financial     │
│  - Date pattern → Recent file          │
│                                         │
│  Generates classification:               │
│  {                                       │
│    "category": "Documents",             │
│    "subfolder": "Invoices",             │
│    "confidence": 0.85,                 │
│    "reasoning": "File name contains..." │
│  }                                       │
└──────┬──────────────────────────────────┘
       │
       │ 5. Return Result
       ▼
┌─────────────────────────────────────────┐
│      ClassificationResult              │
│  - category: "Documents"                │
│  - subfolder: "Invoices"               │
│  - confidence: 0.85                    │
│  - reasoning: "File name contains..."  │
└──────┬──────────────────────────────────┘
       │
       │ 6. Move File
       ▼
┌─────────────────────────────────────────┐
│      Organized File                     │
│      Documents/Invoices/invoice.pdf     │
└─────────────────────────────────────────┘
```

---

## 📊 What Data is Sent to Ollama

### Example: Real File Metadata

**Your File:** `Q4_2024_Financial_Report.pdf`

**Metadata Extracted:**
```json
{
  "fileName": "Q4_2024_Financial_Report.pdf",
  "fileExtension": "pdf",
  "fileSize": 2458624,
  "fileSizeFormatted": "2.5 MB",
  "modificationDate": "2024-12-20T14:22:00Z",
  "fileType": "com.adobe.pdf",
  "mimeType": "application/pdf",
  "parentFolder": "Documents",
  "author": "John Doe",
  "keywords": ["financial", "report", "Q4"],
  "whereFrom": "https://company.com/reports/download",
  "commonPatterns": ["contains_date", "uses_underscores"],
  "siblingFiles": ["Invoice_2024.pdf", "Receipt_Nov.pdf"]
}
```

**What Gets Sent to Ollama:**
```
Analyze this file metadata and classify it into a category and subfolder.

File Information:
- Name: Q4_2024_Financial_Report.pdf
- Extension: pdf
- Size: 2.5 MB
- Type: application/pdf
- Modified: Dec 20, 2024 at 2:22 PM
- Parent Folder: Documents
- Patterns: contains_date, uses_underscores
- Author: John Doe
- Keywords: financial, report, Q4
- Where From: https://company.com/reports/download
- Siblings: Invoice_2024.pdf, Receipt_Nov.pdf

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

**What Does NOT Get Sent:**
- ❌ File content (the actual PDF data)
- ❌ Full file paths (privacy)
- ❌ Binary data
- ❌ File hashes

---

## 🧠 How Ollama Processes It

### Step-by-Step LLM Processing

1. **Receives Prompt**
   - Ollama gets the text prompt with metadata
   - No file content, just metadata description

2. **LLM Analysis** (happens on YOUR Mac)
   ```
   LLM thinks:
   - "Q4_2024" → Quarter 4, 2024 (temporal)
   - "Financial_Report" → Financial document
   - "pdf" → Document type
   - "Author: John Doe" → Work-related
   - "Keywords: financial, report" → Financial category
   - "Where From: company.com" → Work source
   - "Parent: Documents" → Already in documents
   - "Siblings: Invoice, Receipt" → Financial documents
   
   Conclusion: This is a financial report document
   Category: Documents
   Subfolder: Financial or Reports
   Confidence: High (0.85) - clear indicators
   ```

3. **Generates Response**
   ```json
   {
     "category": "Documents",
     "subfolder": "Financial",
     "confidence": 0.85,
     "reasoning": "File name contains 'Financial_Report', 
                   has financial keywords, author suggests 
                   work document, and is in Documents folder"
   }
   ```

4. **Returns JSON**
   - Ollama sends back JSON response
   - App parses and uses it

---

## 🔐 Privacy & Security

### What Stays Local

```
┌─────────────────────────────────────────┐
│         YOUR MAC (Local)                │
│                                         │
│  ✅ File on disk                         │
│  ✅ Metadata extraction                  │
│  ✅ Prompt building                      │
│  ✅ Ollama server (localhost:11434)     │
│  ✅ LLM model (running locally)          │
│  ✅ Classification processing            │
│  ✅ File movement                        │
│                                         │
│  ❌ NO data leaves your Mac              │
│  ❌ NO internet required                 │
│  ❌ NO cloud services                    │
└─────────────────────────────────────────┘
```

### Data Privacy Guarantees

1. **100% Local Processing**
   - Ollama runs on `localhost:11434`
   - LLM model is on your Mac
   - No network calls outside your machine

2. **Metadata Only**
   - Only metadata sent to LLM
   - File content never read or sent
   - Even metadata is processed locally

3. **No Data Collection**
   - Ollama doesn't collect data
   - No telemetry
   - No usage tracking
   - Completely private

---

## 📝 Detailed Example

### Real-World Scenario

**Your File:**
```
/Users/you/Documents/invoice_2024_12_20.pdf
- Size: 1.2 MB
- Author: "Accounting Department"
- Keywords: ["invoice", "billing", "2024"]
- Where From: "https://accounting.company.com/invoices"
- Modified: Dec 20, 2024
```

**What Happens:**

1. **Metadata Extraction** (App)
   ```swift
   let metadata = FileMetadata.extract(from: fileURL)
   // Extracts: name, size, dates, author, keywords, whereFrom
   // Does NOT read PDF content
   ```

2. **Prompt Building** (App)
   ```
   "Analyze this file metadata...
    - Name: invoice_2024_12_20.pdf
    - Author: Accounting Department
    - Keywords: invoice, billing, 2024
    - Where From: https://accounting.company.com/invoices
    ..."
   ```

3. **Send to Ollama** (HTTP POST to localhost)
   ```http
   POST http://localhost:11434/api/generate
   {
     "model": "llama3.2:1b",
     "prompt": "...",
     "format": "json"
   }
   ```

4. **Ollama Processes** (Your Mac's CPU/GPU)
   - LLM analyzes the metadata
   - Considers: filename, author, keywords, source
   - Determines: This is an invoice document
   - Generates classification

5. **Response** (Ollama → App)
   ```json
   {
     "category": "Documents",
     "subfolder": "Invoices",
     "confidence": 0.90,
     "reasoning": "File name contains 'invoice', 
                   has invoice keywords, author is 
                   Accounting Department, and source 
                   is accounting website"
   }
   ```

6. **File Organization** (App)
   ```
   Moves file to:
   Documents/Invoices/invoice_2024_12_20.pdf
   ```

---

## 🎯 How Author, Keywords, and Where From Help

### Author Field

**Example:** `author: "John Doe"`

**How Ollama Uses It:**
- If author is a person name → Likely personal document
- If author is "Accounting" → Likely work/financial document
- If author is company name → Likely business document

**Classification Impact:**
```
Without author: "Documents/General" (confidence: 0.6)
With author "Accounting": "Documents/Financial" (confidence: 0.9)
```

### Keywords Field

**Example:** `keywords: ["financial", "report", "Q4"]`

**How Ollama Uses It:**
- Keywords provide semantic context
- "financial" → Financial category
- "report" → Report subfolder
- "Q4" → Time-based organization

**Classification Impact:**
```
Without keywords: "Documents/General" (confidence: 0.7)
With keywords ["financial", "report"]: "Documents/Financial" (confidence: 0.95)
```

### Where From Field

**Example:** `whereFrom: "https://accounting.company.com/invoices"`

**How Ollama Uses It:**
- Source URL indicates document type
- "accounting" in URL → Financial documents
- "downloads" → Might be temporary
- Company domain → Work-related

**Classification Impact:**
```
Without whereFrom: "Documents/General" (confidence: 0.7)
With whereFrom "accounting.company.com": "Documents/Financial" (confidence: 0.9)
```

---

## 🔄 Batch Processing Flow

### Processing Multiple Files

```
Files: [file1.pdf, file2.jpg, file3.mp4, ...]
         │
         │ Extract metadata for all
         ▼
Metadata: [meta1, meta2, meta3, ...]
         │
         │ Process in batches (10 files)
         ▼
Batch 1: [meta1...meta10]
         │
         │ Send to Ollama (one by one)
         ▼
Results: [result1...result10]
         │
         │ Continue with next batch
         ▼
Batch 2: [meta11...meta20]
         │
         ▼
Final: All files classified
```

### Why Sequential (Current Implementation)

- Ollama processes one request at a time
- Ensures stable results
- Can be optimized to parallel later

---

## 💡 How the LLM Makes Decisions

### Decision Process

```
LLM receives metadata:
├─ Filename: "invoice_2024.pdf"
├─ Extension: "pdf"
├─ Author: "Accounting"
├─ Keywords: ["invoice", "billing"]
├─ Where From: "accounting.com"
└─ Parent: "Documents"

LLM reasoning:
1. "invoice" in filename → Invoice document
2. "pdf" extension → Document type
3. Author "Accounting" → Work/Financial
4. Keywords "invoice, billing" → Financial category
5. Source "accounting.com" → Confirms financial
6. Already in "Documents" → Stays in Documents

Decision:
Category: "Documents" (file type + location)
Subfolder: "Invoices" (filename + keywords)
Confidence: 0.90 (strong indicators)
```

### Confidence Scoring

**High Confidence (0.8-1.0):**
- Clear filename patterns ("invoice", "receipt")
- Matching keywords
- Author/source alignment
- File type matches category

**Medium Confidence (0.5-0.8):**
- Some indicators present
- Ambiguous filename
- Missing metadata

**Low Confidence (0.0-0.5):**
- Unclear file type
- No clear patterns
- Generic filename

---

## 🚀 Performance Characteristics

### Processing Time

```
Single File Classification:
├─ Metadata extraction: ~5-10ms
├─ Prompt building: ~1ms
├─ Ollama processing: 200-500ms (depends on model)
├─ Response parsing: ~1ms
└─ Total: ~200-500ms per file

Batch of 10 files:
├─ Sequential processing: 2-5 seconds
└─ Can be optimized to parallel later
```

### Resource Usage

```
CPU: Moderate (LLM inference)
GPU: If available, uses GPU (faster)
RAM: Model size (1-4GB depending on model)
Disk: Model storage (1-4GB)
```

---

## 🔧 Technical Details

### HTTP Request to Ollama

```http
POST http://localhost:11434/api/generate
Content-Type: application/json

{
  "model": "llama3.2:1b",
  "prompt": "Analyze this file metadata...",
  "stream": false,
  "format": "json"
}
```

### Ollama Response

```json
{
  "response": "{\"category\":\"Documents\",\"subfolder\":\"Invoices\",\"confidence\":0.85,\"reasoning\":\"...\"}",
  "done": true
}
```

### Parsing Response

```swift
// Extract JSON from response string
let json = parseJSON(ollamaResponse.response)

// Create ClassificationResult
ClassificationResult(
    category: json["category"],
    subfolder: json["subfolder"],
    confidence: json["confidence"],
    reasoning: json["reasoning"]
)
```

---

## 📊 Data Flow Summary

```
YOUR FILE
    ↓
Extract Metadata (author, keywords, whereFrom, etc.)
    ↓
Build Prompt (text description of metadata)
    ↓
Send to Ollama (localhost:11434)
    ↓
LLM Analyzes (on your Mac)
    ↓
Returns Classification (JSON)
    ↓
Move File to Category/Subfolder
```

**Key Points:**
- ✅ Only metadata, never file content
- ✅ All processing happens on your Mac
- ✅ No data leaves your machine
- ✅ Works completely offline
- ✅ Author, keywords, whereFrom enhance accuracy

---

## 🎯 Example with All Metadata

### Real File Example

**File:** `Q4_Financial_Report_2024.pdf`

**Extracted Metadata:**
```swift
FileMetadata(
    fileName: "Q4_Financial_Report_2024.pdf",
    fileExtension: "pdf",
    fileSize: 2458624,
    fileSizeFormatted: "2.5 MB",
    modificationDate: 2024-12-20,
    fileType: "application/pdf",
    author: "Finance Team",              // ← Helps classification
    keywords: ["financial", "Q4", "report"], // ← Strong indicators
    whereFrom: "https://finance.company.com/reports", // ← Context
    parentFolder: "Documents",
    commonPatterns: ["contains_date"]
)
```

**Prompt Sent to Ollama:**
```
Analyze this file metadata and classify it...

File Information:
- Name: Q4_Financial_Report_2024.pdf
- Extension: pdf
- Size: 2.5 MB
- Type: application/pdf
- Modified: Dec 20, 2024
- Parent Folder: Documents
- Author: Finance Team              ← Added context
- Keywords: financial, Q4, report   ← Strong signals
- Where From: https://finance.company.com/reports  ← Source context
- Patterns: contains_date
```

**Ollama's Analysis:**
```
LLM sees:
- "Q4" + "Financial" + "Report" → Financial report
- Author "Finance Team" → Work/Financial document
- Keywords "financial, Q4, report" → All point to financial
- Source "finance.company.com" → Confirms financial
- Date pattern → Time-based (Q4 2024)

Decision: Documents/Financial (confidence: 0.95)
```

**Result:**
```json
{
  "category": "Documents",
  "subfolder": "Financial",
  "confidence": 0.95,
  "reasoning": "File name contains 'Financial_Report', 
                author is Finance Team, keywords include 
                'financial', and source is finance website. 
                Strong indicators this is a financial document."
}
```

---

## 🔍 Debugging: See What's Sent

### Enable Debug Logging

Add this to see the exact prompt:

```swift
let prompt = buildClassificationPrompt(metadata: metadata)
print("📤 Sending to Ollama:")
print(prompt)
```

### Example Output

```
📤 Sending to Ollama:
Analyze this file metadata and classify it into a category and subfolder.

File Information:
- Name: invoice_2024.pdf
- Extension: pdf
- Size: 1.2 MB
- Type: application/pdf
- Modified: Dec 20, 2024 at 2:22 PM
- Parent Folder: Documents
- Author: Accounting Department
- Keywords: invoice, billing, 2024
- Where From: https://accounting.company.com/invoices
- Patterns: contains_date, uses_underscores
- Siblings: Receipt_Nov.pdf, Invoice_2023.pdf

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

## ✅ Summary

### What OllamaLLMService Does:

1. **Extracts metadata** from your files (author, keywords, whereFrom, etc.)
2. **Builds a text prompt** describing the file metadata
3. **Sends prompt to Ollama** (running on localhost)
4. **Ollama's LLM analyzes** the metadata locally
5. **Returns classification** (category/subfolder)
6. **Moves file** to organized location

### Privacy Guarantees:

- ✅ **100% local** - Everything runs on your Mac
- ✅ **Metadata only** - Never reads file content
- ✅ **No internet** - Works completely offline
- ✅ **No data collection** - Ollama doesn't track anything

### How Author/Keywords/WhereFrom Help:

- **Author:** Indicates document type (personal vs work)
- **Keywords:** Provide semantic context for better classification
- **Where From:** Source URL gives context about document origin

**Result:** More accurate classifications with higher confidence scores!

---

**Last Updated:** 2024-12-20

