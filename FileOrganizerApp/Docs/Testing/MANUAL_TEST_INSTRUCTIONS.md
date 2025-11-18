# Manual Test Instructions - Use Your Own Files!

## 🎯 Quick Start

**Just change the folder path and run!**

### Step 1: Edit the Test File

Open `Tests/ManualClassifierTest.swift` and find this line:

```swift
let testFolderPath = "/Users/\(NSUserName())/Desktop/TestFiles"  // ← Change this!
```

Change it to your folder:

```swift
let testFolderPath = "/Users/yourname/Documents/Downloads"  // Your folder here
```

### Step 2: Run the Test

```bash
# Test Rule-Based (always works, instant)
swift test --filter testRuleBasedWithMyFolder

# Test Ollama (if running)
swift test --filter testOllamaWithMyFolder

# Compare all classifiers
swift test --filter testCompareAllWithMyFolder
```

That's it! The test will use **your real files** from the folder you specified.

---

## 📋 What Each Test Does

### `testRuleBasedWithMyFolder`
- ✅ Uses Rule-Based classifier (always works)
- ✅ Tests all files in your folder
- ✅ Shows classification results
- ✅ Instant results (< 1 second for 100 files)

### `testOllamaWithMyFolder`
- 🦙 Uses Ollama (if running)
- 🦙 Tests first file in your folder
- 🦙 Shows detailed metadata (author, keywords, where from)
- 🦙 Shows AI reasoning

### `testCompareAllWithMyFolder`
- 🔍 Tests same file with all available classifiers
- 🔍 Compares results side-by-side
- 🔍 Shows which classifier is fastest/most accurate

---

## 💡 Example Usage

### Example 1: Test Downloads Folder

```swift
let testFolderPath = "/Users/yourname/Downloads"
```

Then run:
```bash
swift test --filter testRuleBasedWithMyFolder
```

### Example 2: Test Documents Folder

```swift
let testFolderPath = "/Users/yourname/Documents"
```

### Example 3: Test Any Folder

```swift
let testFolderPath = "/path/to/your/folder"
```

---

## 📊 What You'll See

### Rule-Based Test Output

```
🧪 Testing Rule-Based Classifier
📁 Folder: /Users/yourname/Desktop/TestFiles
============================================================
📄 Found 5 files

📄 invoice.pdf
   → Documents/Invoices
   Confidence: 0.70

📄 photo.jpg
   → Media/Photos
   Confidence: 0.80

...

✅ Classified 5 files

📊 Category Distribution:
   Documents: 2
   Media: 2
   Projects: 1
```

### Ollama Test Output

```
🧪 Testing Ollama Classifier
📁 Folder: /Users/yourname/Desktop/TestFiles
============================================================
✅ Ollama is available

📄 invoice_2024.pdf
   Extracting metadata...
   Author: John Doe
   Keywords: financial, report
   Where From: https://example.com/download
   → Documents/Financial
   Confidence: 0.85
   Time: 342.50ms
   Reasoning: File name contains date and financial terms...
```

---

## 🔧 Troubleshooting

### "Folder does not exist"
- Check the path is correct
- Use absolute path (full path starting with `/`)
- Make sure folder exists

### "No files found"
- Folder might be empty
- Files might be hidden (test skips hidden files)
- Check folder permissions

### Ollama not available
- Start Ollama: `ollama serve`
- Download model: `ollama pull llama3.2:1b`
- Check: `curl http://localhost:11434/api/tags`

---

## 🎯 Tips

1. **Start with Rule-Based** - Always works, instant results
2. **Use a small folder first** - Test with 5-10 files
3. **Check the output** - See what classifications you get
4. **Try different folders** - Test with different file types

---

## 📝 Quick Reference

```bash
# 1. Edit testFolderPath in ManualClassifierTest.swift

# 2. Run test
swift test --filter testRuleBasedWithMyFolder

# 3. View results in terminal
```

**No need to create test files - just use your real files!** 🎉

