import SwiftUI
import AppKit
import Combine

// MARK: - Keyword Types

struct ScannedKeyword: Identifiable, Hashable {
    let id = UUID()
    let keyword: String
    let source: String
    let type: KeywordType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(keyword)
    }
    
    static func == (lhs: ScannedKeyword, rhs: ScannedKeyword) -> Bool {
        return lhs.keyword == rhs.keyword
    }
}

enum KeywordType {
    case file
    case folder
}

struct BulkKeywordEntry {
    let keyword: String
    var subfolder: String
    var category: String
}

struct FolderScanView: View {
    @StateObject private var store = KeywordStore()
    @State private var selectedFolder = ""
    @State private var isScanning = false
    @State private var scannedKeywords: [ScannedKeyword] = []
    @State private var scanProgress = 0.0
    @State private var scanStatus = ""
    @State private var totalItems = 0
    @State private var processedItems = 0
    @State private var selectedKeywords: Set<String> = []
    @State private var showBulkAddSheet = false
    @State private var fileBasedKeywords: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            folderSelectionSection
            scanProgressSection
            scannedKeywordsSection
        }
        .frame(minWidth: 600, minHeight: 700)
        .frame(maxWidth: 800, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .padding(20)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text("Folder Scanner")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
        }
    }
    
    private var folderSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected Folder:")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Browse") {
                    selectFolder()
                }
                .buttonStyle(.bordered)
                
                if !selectedFolder.isEmpty {
                    Button(isScanning ? "Scanning..." : "Scan") {
                        scanFolderForKeywords()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)
                }
            }
            
            if selectedFolder.isEmpty {
                Text("No folder selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            } else {
                Text(selectedFolder)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }
    
    private var scanProgressSection: some View {
        Group {
            if isScanning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanning Folder...")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scanStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(processedItems)/\(totalItems)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: scanProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var scannedKeywordsSection: some View {
        Group {
            if !scannedKeywords.isEmpty && !isScanning {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Scanned Keywords")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(scannedKeywords.count) keywords found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Bulk Selection Controls
                    HStack {
                        Button("Select All") {
                            selectedKeywords = Set(scannedKeywords.map { $0.keyword })
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Clear Selection") {
                            selectedKeywords.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        if !selectedKeywords.isEmpty {
                            Button("Add Selected (\(selectedKeywords.count))") {
                                showBulkAddSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .frame(minWidth: 140)
                        }
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(scannedKeywords) { scanned in
                                HStack {
                                    // Checkbox for selection
                                    Button(action: {
                                        if selectedKeywords.contains(scanned.keyword) {
                                            selectedKeywords.remove(scanned.keyword)
                                        } else {
                                            selectedKeywords.insert(scanned.keyword)
                                        }
                                    }) {
                                        Image(systemName: selectedKeywords.contains(scanned.keyword) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedKeywords.contains(scanned.keyword) ? .blue : .gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(scanned.keyword)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if scanned.type == .folder {
                                                Image(systemName: "folder")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "doc")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        Text("Found in: \(scanned.source)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Add") {
                                        addScannedKeyword(scanned)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                }
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showBulkAddSheet) {
            BulkAddKeywordsView(
                selectedKeywords: Array(selectedKeywords),
                scannedKeywords: scannedKeywords
            )
            .frame(minWidth: 600, minHeight: 500)
            .frame(maxWidth: 700, maxHeight: CGFloat.infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .onDisappear {
                // Reset selection after sheet is dismissed
                selectedKeywords.removeAll()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectFolder() {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.title = "Select Folder to Analyze"
        dialog.message = "Choose a folder to analyze for keyword suggestions"
        
        if dialog.runModal() == .OK {
            selectedFolder = dialog.url?.path ?? ""
            analyzeFilesForKeywords()
        }
    }
    
    private func scanFolderForKeywords() {
        guard !selectedFolder.isEmpty else { 
            return 
        }
        isScanning = true
        scannedKeywords.removeAll()
        scanProgress = 0.0
        processedItems = 0
        totalItems = 0
        scanStatus = "Initializing scan..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let folderURL = URL(fileURLWithPath: selectedFolder)
            
            do {
                // Get all items recursively to count them
                let allURLs = try self.getAllItemsRecursively(from: folderURL)
                
                DispatchQueue.main.async {
                    self.totalItems = allURLs.count
                    self.scanStatus = "Scanning files and folders..."
                }
                
                var keywords: [ScannedKeyword] = []
                var keywordFrequency: [String: Int] = [:]
                
                for (index, fileURL) in allURLs.enumerated() {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory == true
                    let isFile = resourceValues?.isRegularFile == true
                    
                    let name = fileURL.lastPathComponent
                    let nameWithoutExtension = name.replacingOccurrences(of: ".\(name.components(separatedBy: ".").last ?? "")", with: "")
                    
                    // Update progress
                    DispatchQueue.main.async {
                        self.processedItems = index + 1
                        guard self.totalItems > 0 else {
                            self.scanProgress = 0.0
                            return
                        }
                        self.scanProgress = Double(index + 1) / Double(self.totalItems)
                        self.scanStatus = "Processing: \(name)"
                    }
                    
                    if isDirectory {
                        // Enhanced folder name processing
                        let folderKeywords = self.extractKeywordsFromName(nameWithoutExtension, source: "Folder: \(name)", type: KeywordType.folder)
                        keywords.append(contentsOf: folderKeywords)
                        
                        // Count frequency
                        for keyword in folderKeywords {
                            keywordFrequency[keyword.keyword, default: 0] += 1
                        }
                    } else if isFile {
                        // Enhanced file name processing
                        let fileKeywords = self.extractKeywordsFromName(nameWithoutExtension, source: "File: \(name)", type: KeywordType.file)
                        keywords.append(contentsOf: fileKeywords)
                        
                        // Count frequency
                        for keyword in fileKeywords {
                            keywordFrequency[keyword.keyword, default: 0] += 1
                        }
                    }
                }
                
                // Remove duplicates and sort by frequency, then alphabetically
                DispatchQueue.main.async {
                    self.scanStatus = "Processing results..."
                }
                
                let uniqueKeywords = Array(Set(keywords)).sorted { first, second in
                    let firstFreq = keywordFrequency[first.keyword] ?? 0
                    let secondFreq = keywordFrequency[second.keyword] ?? 0
                    
                    if firstFreq != secondFreq {
                        return firstFreq > secondFreq // Higher frequency first
                    }
                    return first.keyword < second.keyword // Then alphabetically
                }
                
                DispatchQueue.main.async {
                    self.scannedKeywords = uniqueKeywords
                    self.isScanning = false
                    self.scanStatus = "Scan complete! Found \(uniqueKeywords.count) unique keywords."
                }
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanStatus = "Error: \(error.localizedDescription)"
                }
                print("Error scanning folder: \(error)")
            }
        }
    }
    
    private func getAllItemsRecursively(from folderURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var allItems: [URL] = []
        
        func scanDirectory(_ url: URL) throws {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles])
            
            for item in contents {
                allItems.append(item)
                
                let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues?.isDirectory == true {
                    try scanDirectory(item)
                }
            }
        }
        
        try scanDirectory(folderURL)
        return allItems
    }
    
    private func extractKeywordsFromName(_ name: String, source: String, type: KeywordType) -> [ScannedKeyword] {
        var keywords: [ScannedKeyword] = []
        
        // Common separators and patterns
        let separators = CharacterSet.alphanumerics.inverted
        let words = name.components(separatedBy: separators)
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Enhanced filtering criteria
            guard !cleanWord.isEmpty else { continue }
            guard cleanWord.count >= 2 else { continue } // Allow 2+ character words
            
            // Filter out common non-meaningful words
            let commonWords = Set([
                "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
                "a", "an", "is", "are", "was", "were", "be", "been", "being",
                "have", "has", "had", "do", "does", "did", "will", "would", "could", "should",
                "this", "that", "these", "those", "it", "its", "they", "them", "their",
                "file", "folder", "document", "image", "photo", "picture", "video", "audio",
                "backup", "copy", "new", "old", "temp", "tmp", "draft", "final", "version",
                "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8", "v9", "v10",
                "copy", "copies", "duplicate", "duplicates", "original", "edit", "edited",
                "untitled", "untitled1", "untitled2", "untitled3", "untitled4", "untitled5"
            ])
            
            let lowerWord = cleanWord.lowercased()
            guard !commonWords.contains(lowerWord) else { continue }
            
            // Filter out pure numbers (but allow alphanumeric combinations)
            guard cleanWord.rangeOfCharacter(from: CharacterSet.letters) != nil else { continue }
            
            // Filter out very long words (likely not meaningful keywords)
            guard cleanWord.count <= 20 else { continue }
            
            // Check for camelCase and split
            if cleanWord.contains(where: { $0.isUppercase }) && cleanWord.count > 3 {
                // Improved camelCase splitting that preserves the first letter
                var camelCaseWords: [String] = []
                var currentWord = ""
                
                for (index, char) in cleanWord.enumerated() {
                    if char.isUppercase && index > 0 {
                        if !currentWord.isEmpty {
                            camelCaseWords.append(currentWord)
                            currentWord = ""
                        }
                    }
                    currentWord.append(char)
                }
                
                if !currentWord.isEmpty {
                    camelCaseWords.append(currentWord)
                }
                
                // Filter and add camelCase words
                for camelWord in camelCaseWords {
                    if camelWord.count >= 2 {
                        keywords.append(ScannedKeyword(keyword: camelWord, source: source, type: type))
                    }
                }
            }
            
            // Add the original word if it's meaningful
            keywords.append(ScannedKeyword(keyword: cleanWord, source: source, type: type))
        }
        
        // Extract potential acronyms (all caps words)
        let acronymPattern = "[A-Z]{2,}"
        let acronymRegex = try? NSRegularExpression(pattern: acronymPattern)
        if let matches = acronymRegex?.matches(in: name, range: NSRange(name.startIndex..., in: name)) {
            for match in matches {
                if let range = Range(match.range, in: name) {
                    let acronym = String(name[range])
                    keywords.append(ScannedKeyword(keyword: acronym, source: source, type: type))
                }
            }
        }
        
        return keywords
    }
    
    private func addScannedKeyword(_ scanned: ScannedKeyword) {
        store.add(keyword: scanned.keyword, subfolder: scanned.type == KeywordType.folder ? scanned.keyword : "General", category: "Work")
    }
    
    private func addBulkKeywords(_ keywords: [BulkKeywordEntry]) {
        for entry in keywords {
            store.add(keyword: entry.keyword, subfolder: entry.subfolder, category: entry.category)
        }
        selectedKeywords.removeAll()
    }
    
    private func analyzeFilesForKeywords() {
        guard !selectedFolder.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let folderURL = URL(fileURLWithPath: selectedFolder)
            
            do {
                // Use the same recursive scanning as the main scan function
                let allURLs = try self.getAllItemsRecursively(from: folderURL)
                
                var keywords: Set<String> = []
                
                for fileURL in allURLs {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory == true
                    let isFile = resourceValues?.isRegularFile == true
                    
                    let name = fileURL.lastPathComponent
                    let nameWithoutExtension = name.replacingOccurrences(of: ".\(name.components(separatedBy: ".").last ?? "")", with: "")
                    
                    if isDirectory || isFile {
                        let extractedKeywords = self.extractKeywordsFromName(nameWithoutExtension, source: "", type: KeywordType.file)
                        keywords.formUnion(extractedKeywords.map { $0.keyword })
                    }
                }
                
                DispatchQueue.main.async {
                    self.fileBasedKeywords = Array(keywords).sorted()
                }
            } catch {
                print("Error analyzing files: \(error)")
            }
        }
    }
} 