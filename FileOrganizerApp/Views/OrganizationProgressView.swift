import SwiftUI
import AppKit

struct OrganizationProgressView: View {
    let folderPath: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keywordStore = KeywordStore()
    @State private var isRunning = false
    @State private var progress = 0.0
    @State private var currentFile = ""
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var showResults = false
    @State private var results: FileMoveResults?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var activities: [ActivityLog] = []
    @State private var canDismiss = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(spacing: 8) {
                    Text("File Organization Progress")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Organizing files in: \(folderPath)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("✕") {
                    dismiss()
                }
                .font(.title2)
                .foregroundColor(.secondary)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
            
            // Progress Section
            if isRunning {
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
                    
                    Text("\(processedFiles) of \(totalFiles) files processed")
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
            
            // Activities Log
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activities")
                        .font(.headline)
                    
                    Spacer()
                    
                    if isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.caption)
                                .foregroundColor(.green)
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
                .frame(maxHeight: 300)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            // Results Section
            if showResults, let results = results {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Organization Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ResultRow(title: "Files Processed", value: "\(results.processedFiles)")
                        ResultRow(title: "Files Moved", value: "\(results.movedFiles)")
                        ResultRow(title: "Skipped", value: "\(results.skippedFiles)")
                        ResultRow(title: "Errors", value: "\(results.errorFiles)")
                        ResultRow(title: "Time Taken", value: results.timeTaken)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                if !isRunning && !showResults {
                    Button("Start Organization") {
                        startOrganization()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if isRunning {
                    Button("Stop") {
                        stopOrganization()
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
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startOrganization() {
        guard !keywordStore.keywords.isEmpty else {
            showError(message: "No keyword rules found. Please add rules in the Keyword Manager.")
            return
        }
        
        isRunning = true
        progress = 0.0
        processedFiles = 0
        showResults = false
        results = nil
        activities.removeAll()
        canDismiss = false
        
        // Add initial activity
        addActivity("Starting file organization...", type: .info)
        addActivity("Found \(keywordStore.keywords.count) keyword rules", type: .info)
        
        DispatchQueue.global(qos: .userInitiated).async(execute: DispatchWorkItem {
            let sourceFolder = URL(fileURLWithPath: folderPath)
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
                            
                            // Add activity for current file
                            if !currentFileName.isEmpty {
                                self.addActivity("Processing: \(currentFileName)", type: .processing)
                            }
                        }
                    }
                )
                
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.showResults = true
                    self.results = results
                    self.canDismiss = true
                    
                    // Add completion activities
                    self.addActivity("Organization completed successfully!", type: .success)
                    self.addActivity("Moved \(results.movedFiles) files", type: .success)
                    if results.skippedFiles > 0 {
                        self.addActivity("Skipped \(results.skippedFiles) files (no matching rules)", type: .warning)
                    }
                    if results.errorFiles > 0 {
                        self.addActivity("\(results.errorFiles) files had errors", type: .error)
                    }
                    
                    // Update last run time
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let lastRunTime = formatter.string(from: Date())
                    UserDefaults.standard.set(lastRunTime, forKey: "lastRunTime")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.canDismiss = true
                    self.addActivity("Error: \(error.localizedDescription)", type: .error)
                    self.showError(message: error.localizedDescription)
                }
            }
        })
    }
    
    private func stopOrganization() {
        isRunning = false
        addActivity("Organization stopped by user", type: .warning)
        canDismiss = true
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

struct ActivityRow: View {
    let activity: ActivityLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Activity icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch activity.type {
        case .info: return "info.circle"
        case .processing: return "arrow.right.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch activity.type {
        case .info: return .blue
        case .processing: return .orange
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: activity.timestamp)
    }
}

struct ActivityLog: Identifiable {
    let id = UUID()
    let message: String
    let type: ActivityType
    let timestamp: Date
}

enum ActivityType {
    case info
    case processing
    case success
    case warning
    case error
} 