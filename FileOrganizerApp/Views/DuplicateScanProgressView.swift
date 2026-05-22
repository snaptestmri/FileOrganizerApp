import SwiftUI
import AppKit
import Foundation

struct DuplicateScanProgressView: View {
    let folderPath: String
    let onComplete: (([String: [URL]]) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var progress = 0.0
    @State private var currentFile = ""
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var activities: [ActivityLog] = []
    @State private var duplicates: [String: [URL]] = [:]
    @State private var canDismiss = false
    @State private var showResults = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duplicate Scan Progress")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Scanning: \(folderPath)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Button("✕") { dismiss() }
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
            
            if isScanning {
                VStack(spacing: 16) {
                    HStack {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(y: 2)
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    Text("\(processedFiles) of \(totalFiles) files scanned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !currentFile.isEmpty {
                        HStack {
                            Image(systemName: "doc")
                                .foregroundColor(.blue)
                            Text("Current: \(currentFile)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activities")
                        .font(.headline)
                    Spacer()
                    if isScanning {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Live").font(.caption).foregroundColor(.green)
                        }
                    }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(activities) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            if showResults {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Found \(duplicates.count) duplicate file groups.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if !duplicates.isEmpty {
                        ScrollView {
                            ForEach(Array(duplicates.keys.sorted()), id: \.self) { filename in
                                VStack(alignment: .leading) {
                                    Text(filename)
                                        .font(.headline)
                                    ForEach(duplicates[filename] ?? [], id: \.self) { url in
                                        Text(url.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                if isScanning {
                    Button("Stop") {
                        isScanning = false
                        addActivity("Scan stopped by user", type: .warning)
                        canDismiss = true
                    }
                    .buttonStyle(.bordered)
                }
                if showResults || canDismiss {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear(perform: startScan)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startScan() {
        addActivity("Starting duplicate scan...", type: .info)
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let folderURL = URL(fileURLWithPath: folderPath)
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                let total = fileURLs.count
                var fileHashes: [String: [URL]] = [:]
                for (idx, fileURL) in fileURLs.enumerated() {
                    if !isScanning { break }
                    let fileName = fileURL.lastPathComponent
                    DispatchQueue.main.async {
                        self.processedFiles = idx + 1
                        self.totalFiles = total
                        self.progress = total > 0 ? Double(idx + 1) / Double(total) : 0.0
                        self.currentFile = fileName
                        self.addActivity("Scanning: \(fileName)", type: .processing)
                    }
                    // Check file size before loading into memory (limit to 100MB)
                    let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize,
                       Int64(fileSize) <= maxFileSize,
                       let data = try? Data(contentsOf: fileURL) {
                        let hash = data.sha256()
                        if fileHashes[hash] == nil {
                            fileHashes[hash] = []
                        }
                        fileHashes[hash]?.append(fileURL)
                    } else if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                              let fileSize = resourceValues.fileSize,
                              Int64(fileSize) > maxFileSize {
                        // Skip files larger than 100MB to avoid memory issues
                        DispatchQueue.main.async {
                            self.addActivity("Skipped large file: \(fileName) (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))", type: .info)
                        }
                    }
                }
                let foundDuplicates = fileHashes.filter { $0.value.count > 1 }
                DispatchQueue.main.async {
                    self.duplicates = foundDuplicates
                    self.isScanning = false
                    self.showResults = true
                    self.addActivity("Scan complete! Found \(foundDuplicates.count) duplicate groups.", type: .success)
                    self.canDismiss = true
                    self.onComplete?(foundDuplicates)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.showError(message: error.localizedDescription)
                    self.canDismiss = true
                }
            }
        }
    }
    
    private func addActivity(_ message: String, type: ActivityType) {
        let activity = ActivityLog(message: message, type: type, timestamp: Date())
        activities.append(activity)
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
} 