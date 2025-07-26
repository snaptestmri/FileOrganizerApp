import SwiftUI
import AppKit

struct FileMoverView: View {
    @StateObject private var keywordStore = KeywordStore()
    @State private var selectedFolderPath = ""
    @State private var isRunning = false
    @State private var progress = 0.0
    @State private var currentFile = ""
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var showResults = false
    @State private var results: FileMoveResults?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lastRunTime = UserDefaults.standard.string(forKey: "lastRunTime") ?? "Never"
    
    var body: some View {
        VStack(spacing: 20) {
            // Header Section
            VStack(alignment: .leading, spacing: 8) {
                Text("File Organizer")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Automatically organize files based on your keyword rules")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Last run:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lastRunTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.systemGray))
            .cornerRadius(12)
            
            // Folder Selection Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Source Folder")
                    .font(.headline)
                
                HStack {
                    TextField("Select folder to organize", text: $selectedFolderPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isRunning)
                    
                    Button("Browse") {
                        selectFolder()
                    }
                    .disabled(isRunning)
                }
                
                if !selectedFolderPath.isEmpty {
                    Text("Selected: \(selectedFolderPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Keywords Preview Section
            if !keywordStore.keywords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Rules (\(keywordStore.keywords.count))")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(keywordStore.keywords) { keyword in
                                HStack {
                                    Text("📁")
                                    Text(keyword.keyword)
                                        .fontWeight(.medium)
                                    Text("→")
                                    Text(keyword.category)
                                        .foregroundColor(.blue)
                                    Text("/")
                                    Text(keyword.subfolder)
                                        .foregroundColor(.green)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.systemGray))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            } else {
                VStack(spacing: 8) {
                    Text("⚠️ No keyword rules found")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("Add keyword rules in the Keyword Manager to organize files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemYellow).opacity(0.1))
                .cornerRadius(12)
            }
            
            // Progress Section
            if isRunning {
                VStack(spacing: 12) {
                    Text("Organizing Files...")
                        .font(.headline)
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(processedFiles) of \(totalFiles) files processed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !currentFile.isEmpty {
                        Text("Current: \(currentFile)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(12)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Manage Keywords") {
                    // This would navigate to KeywordManagerView in a real app
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)
                
                Spacer()
                
                Button(isRunning ? "Stop" : "Run Organizer") {
                    if isRunning {
                        stopOrganizing()
                    } else {
                        runOrganizer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFolderPath.isEmpty || keywordStore.keywords.isEmpty)
            }
            
            // Results Section
            if showResults, let results = results {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Results")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ResultRow(title: "Files Processed", value: "\(results.processedFiles)")
                        ResultRow(title: "Files Moved", value: "\(results.movedFiles)")
                        ResultRow(title: "Skipped", value: "\(results.skippedFiles)")
                        ResultRow(title: "Errors", value: "\(results.errorFiles)")
                        ResultRow(title: "Time Taken", value: results.timeTaken)
                    }
                }
                .padding()
                .background(Color(.systemGreen).opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Run Organizer")
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func selectFolder() {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.title = "Select Folder to Organize"
        dialog.message = "Choose the folder containing files you want to organize"
        
        if dialog.runModal() == .OK {
            selectedFolderPath = dialog.url?.path ?? ""
        }
    }
    
    private func runOrganizer() {
        guard !selectedFolderPath.isEmpty else {
            showError(message: "Please select a folder first")
            return
        }
        
        guard !keywordStore.keywords.isEmpty else {
            showError(message: "No keyword rules found. Please add rules in the Keyword Manager.")
            return
        }
        
        isRunning = true
        progress = 0.0
        processedFiles = 0
        showResults = false
        results = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let sourceFolder = URL(fileURLWithPath: selectedFolderPath)
            let mover = FileMover(sourceFolder: sourceFolder)
            
            do {
                let results = try mover.runWithProgress(
                    with: keywordStore.keywords,
                    progressCallback: { current, total, currentFileName in
                        DispatchQueue.main.async {
                            self.processedFiles = current
                            self.totalFiles = total
                            self.progress = total > 0 ? Double(current) / Double(total) : 0.0
                            self.currentFile = currentFileName
                        }
                    }
                )
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.showResults = true
                    self.results = results
                    
                    // Update last run time
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    self.lastRunTime = formatter.string(from: Date())
                    UserDefaults.standard.set(self.lastRunTime, forKey: "lastRunTime")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopOrganizing() {
        isRunning = false
        // In a real implementation, you'd want to cancel the background operation
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct FileMoveResults {
    let processedFiles: Int
    let movedFiles: Int
    let skippedFiles: Int
    let errorFiles: Int
    let timeTaken: String
}
