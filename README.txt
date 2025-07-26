# 📁 FileOrganizerApp (macOS SwiftUI)

A macOS SwiftUI application for smart file management — including automated sorting, keyword-based categorization, iCloud support, and duplicate file detection with preview and logging.

---

## 🚀 Features

### ✅ File Organizer
- Move files into `Work` or `Personal` folders based on user-defined keywords
- Supports subfolder mapping and real-time folder creation
- Organizes files from local or external drives

### 🔍 Duplicate Checker
- Scan any folder for duplicate files based on content hash (SHA-256)
- Preview duplicates with Quick Look before deletion
- Selectively delete or ignore groups
- Log deleted file paths to `~/Documents/duplicate_delete_log.txt`

### ☁️ iCloud Integration
- View, delete, and manage files in your app’s iCloud container
- All iCloud logic handled in `iCloudFileManager.swift`

### 🔒 Secure and Sandboxed
- macOS App Sandbox and user-scoped folder access
- Prepared for App Store submission with proper entitlements

---

## 🧱 Architecture

FileOrganizerApp/
├── Models/
│ ├── FileMover.swift
│ ├── KeywordEntry.swift
│ ├── KeywordStore.swift
│ └── DuplicateChecker.swift
├── Views/
│ ├── ContentView.swift
│ ├── FileMoverView.swift
│ ├── KeywordManagerView.swift
│ ├── DuplicateCheckerView.swift
│ └── iCloudFileBrowserView.swift
└── FileOrganizerApp.swift

 
