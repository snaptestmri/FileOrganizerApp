# How to Run QuickTuningTest - Quick Guide

## 🚀 Easiest Way (Recommended)

### Step 1: Edit Configuration

Open `Tests/QuickTuningTest.swift` and change:

```swift
let testFolder = "~/Downloads"  // ← Change to your folder
let maxFiles = 5                 // ← Adjust if needed
```

### Step 2: Run the Test

```bash
swift test --filter QuickTuningTest.testQuickTuning
```

**That's it!** ✅

---

## 📋 Prerequisites

Before running, make sure Ollama is set up:

```bash
# 1. Install Ollama (if not installed)
brew install ollama

# 2. Start Ollama (in one terminal)
ollama serve

# 3. Download a model (in another terminal)
ollama pull llama3.2:1b
```

---

## 🎯 What It Does

1. **Compares Configurations** - Tests multiple classifier settings
2. **Tests Best Configuration** - Runs with recommended settings
3. **Provides Analysis** - Shows recommendations and statistics

## 📊 Example Output

```
📊 TEST 1: Comparing Configurations
============================================================

Configuration                    Avg Conf    Avg Time       Files
------------------------------------------------------------
Default                             82.50%        342ms           5
With Examples                       87.30%        398ms           5
...

💡 Recommendations:
   ✅ Best Confidence: With Examples (87.3%)
   ⚡ Fastest: Default (342ms avg)
```

---

## 🔧 Troubleshooting

### "Ollama is not available"
```bash
# Check if running
curl http://localhost:11434/api/tags

# Start if not
ollama serve
```

### "Folder does not exist"
- Use absolute path: `"/Users/yourname/Documents"`
- Or use: `"~/Documents"`

### "No files found"
- Check folder has files
- Try a different folder

---

## 📚 More Info

See `HOW_TO_RUN_TUNING_TESTS.md` for detailed instructions.

