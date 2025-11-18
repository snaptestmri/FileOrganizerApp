# Offline File Classification Guide

## ✅ Yes, Classification Can Work Offline!

The app supports **multiple offline classification methods** that work without internet connectivity.

## 🔧 Offline Options

### 1. **Ollama (Local LLM)** ⭐ Recommended for Offline AI

**What it is:**
- Runs a local LLM server on your Mac
- Completely offline and private
- No data leaves your device
- Free to use

**Setup:**
```bash
# Install Ollama
brew install ollama

# Start Ollama service
ollama serve

# Pull a small model (in another terminal)
ollama pull llama3.2:1b  # Small, fast model (~1.3GB)
# or
ollama pull mistral:7b   # Better accuracy (~4.1GB)
```

**How it works:**
- App connects to `http://localhost:11434`
- Sends file metadata to local LLM
- Gets classification back
- **100% offline** - no internet needed

**Pros:**
- ✅ Completely private
- ✅ No API costs
- ✅ Works offline
- ✅ No rate limits
- ✅ Fast (local processing)

**Cons:**
- ⚠️ Requires ~1-4GB disk space for model
- ⚠️ Uses CPU/GPU resources
- ⚠️ Slightly slower than cloud (but acceptable)

### 2. **Rule-Based Classifier** ⚡ Always Available

**What it is:**
- Built-in pattern matching
- No LLM needed
- Instant classification
- Works offline by default

**How it works:**
- Analyzes file extension (.pdf, .jpg, etc.)
- Matches filename patterns (invoice, receipt, etc.)
- Uses predefined rules

**Example:**
- `invoice_2024.pdf` → Documents/Invoices
- `vacation_photo.jpg` → Media/Photos
- `project_code.swift` → Projects/Code

**Pros:**
- ✅ Instant (no API calls)
- ✅ Always available
- ✅ No setup required
- ✅ Zero cost
- ✅ Works offline

**Cons:**
- ⚠️ Less intelligent than LLM
- ⚠️ Limited to predefined patterns
- ⚠️ Lower accuracy for ambiguous files

### 3. **Hybrid Approach** 🎯 Best of Both Worlds

**Strategy:**
1. Try Ollama first (if available)
2. Fall back to rule-based if Ollama unavailable
3. Optionally use cloud LLM if user prefers

## 📊 Comparison

| Feature | Ollama (Local) | Rule-Based | Cloud LLM |
|---------|---------------|------------|-----------|
| **Offline** | ✅ Yes | ✅ Yes | ❌ No |
| **Privacy** | ✅ 100% | ✅ 100% | ⚠️ Data sent to cloud |
| **Cost** | ✅ Free | ✅ Free | 💰 Paid |
| **Accuracy** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Speed** | ⚡ Fast | ⚡ Instant | ⚡ Very Fast |
| **Setup** | ⚠️ Install Ollama | ✅ None | ⚠️ API key |

## 🚀 Quick Start: Offline Classification

### Option A: Use Rule-Based (No Setup)

1. Open the app
2. Select files to classify
3. Choose "Rule-Based Classifier"
4. Done! Works immediately offline

### Option B: Use Ollama (Better Accuracy)

1. **Install Ollama:**
   ```bash
   brew install ollama
   ```

2. **Start Ollama:**
   ```bash
   ollama serve
   ```

3. **Download a model** (in another terminal):
   ```bash
   ollama pull llama3.2:1b  # Small, fast
   ```

4. **In the app:**
   - Go to Settings → LLM Provider
   - Select "Ollama (Local)"
   - App will auto-detect Ollama running
   - Start classifying!

## 🔍 How Offline Classification Works

### Metadata-Only Approach

The app sends **only metadata** to the classifier:

```json
{
  "fileName": "Q4_2024_Report.pdf",
  "fileExtension": "pdf",
  "fileSize": "2.5 MB",
  "modificationDate": "2024-12-20",
  "fileType": "application/pdf",
  "parentFolder": "Documents",
  "commonPatterns": ["contains_date", "uses_underscores"]
}
```

**No file content is sent** - only metadata that's already "public" (filename, size, dates).

### Classification Process

1. **Extract metadata** from files (offline)
2. **Send metadata** to classifier:
   - Ollama: `localhost:11434` (local)
   - Rule-based: In-app logic (local)
3. **Receive classification** (category, subfolder, confidence)
4. **Apply classification** (move files)

## 🎯 Recommended Setup

### For Maximum Privacy & Offline Use:

1. **Primary:** Ollama with `llama3.2:1b` or `mistral:7b`
2. **Fallback:** Rule-based classifier
3. **Never use:** Cloud LLM (unless explicitly needed)

### For Best Accuracy (When Online):

1. **Primary:** Cloud LLM (OpenAI GPT-3.5/4)
2. **Fallback:** Ollama (if cloud unavailable)
3. **Last resort:** Rule-based

## 💡 Tips

### Ollama Model Selection

- **llama3.2:1b** - Smallest, fastest (~1.3GB)
  - Good for: Quick classifications
  - Best for: Low-end Macs

- **mistral:7b** - Balanced (~4.1GB)
  - Good for: Better accuracy
  - Best for: Mid-range Macs

- **llama3:8b** - Best accuracy (~4.7GB)
  - Good for: Complex classifications
  - Best for: High-end Macs

### Performance Optimization

- **Batch processing:** Classify multiple files at once
- **Caching:** Store results to avoid re-classifying
- **Parallel processing:** Use multiple CPU cores

## 🛠️ Troubleshooting

### Ollama Not Detected

1. Check if Ollama is running:
   ```bash
   curl http://localhost:11434/api/tags
   ```

2. If not running:
   ```bash
   ollama serve
   ```

3. Check if model is downloaded:
   ```bash
   ollama list
   ```

### Slow Classification

- Use smaller model (`llama3.2:1b`)
- Reduce batch size
- Use rule-based for simple files

### Classification Errors

- Check Ollama logs: `ollama serve` (in terminal)
- Verify model is downloaded: `ollama list`
- Try rule-based classifier as fallback

## 📝 Summary

**Yes, classification works offline!** You have two options:

1. **Rule-Based** - Instant, always available, no setup
2. **Ollama** - Better accuracy, requires installation, still 100% offline

Both methods use **metadata-only** classification - no file content is analyzed, ensuring privacy and speed.

