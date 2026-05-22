import SwiftUI
import AppKit

struct AIClassificationView: View {
    let folderPath: String
    @Environment(\.dismiss) private var dismiss
    @State private var classificationManager: FileClassificationManager?
    @State private var selectedServiceType: ServiceType = .ollama
    @State private var classificationMode: ClassificationMode = ClassificationMode.persisted
    @State private var isRunning = false
    @State private var progress = 0.0
    @State private var currentFile = ""
    @State private var currentClassification: String?
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var showResults = false
    @State private var results: FileMoveResults?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var activities: [ActivityLog] = []
    @State private var canDismiss = false
    @ObservedObject private var profileStore = ProfileStore.shared
    @State private var classifications: [(FileMetadata, ClassificationResult, OrganizeDestination)] = []
    @State private var csvExportPath: String? = nil
    @State private var showExportSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(spacing: 8) {
                    Text("AI File Classification")
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
            
            // Service Selection (before starting)
            if !isRunning && !showResults {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Classification Service")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ServiceOption(
                            title: "Ollama (Local AI)",
                            description: "Works offline, private, free. Requires Ollama installed.",
                            isSelected: selectedServiceType == .ollama,
                            isAvailable: checkOllamaAvailable()
                        ) {
                            selectedServiceType = .ollama
                            updateClassificationManager()
                        }
                        
                        ServiceOption(
                            title: "OpenAI (ChatGPT)",
                            description: "Requires internet and API key. GPT-4/GPT-3.5 models.",
                            isSelected: selectedServiceType == .openai,
                            isAvailable: checkOpenAIAvailable()
                        ) {
                            selectedServiceType = .openai
                            updateClassificationManager()
                        }
                        
                        ServiceOption(
                            title: "Anthropic (Claude)",
                            description: "Requires internet and API key. Claude 3 models.",
                            isSelected: selectedServiceType == .anthropic,
                            isAvailable: checkAnthropicAvailable()
                        ) {
                            selectedServiceType = .anthropic
                            updateClassificationManager()
                        }
                        
                        ServiceOption(
                            title: "Fallback (Rule-Based)",
                            description: "Instant, always available. Pattern matching only.",
                            isSelected: selectedServiceType == .fallback,
                            isAvailable: true
                        ) {
                            selectedServiceType = .fallback
                            updateClassificationManager()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Classification Style")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(ClassificationMode.allCases, id: \.self) { mode in
                            ServiceOption(
                                title: mode.displayName,
                                description: mode.description,
                                isSelected: classificationMode == mode,
                                isAvailable: true
                            ) {
                                classificationMode = mode
                                ClassificationMode.persisted = mode
                                updateClassificationManager()
                            }
                        }
                    }
                }
            }
            
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
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.blue)
                                Text("Current: \(currentFile)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if let classification = currentClassification {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.green)
                                    Text("→ \(classification)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
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
            }
            
            // Results Section
            if showResults, let results = results {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Classification Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ResultRow(title: "Files Processed", value: "\(results.processedFiles)")
                        ResultRow(title: "Files Moved", value: "\(results.movedFiles)")
                        ResultRow(title: "Skipped", value: "\(results.skippedFiles)")
                        ResultRow(title: "Errors", value: "\(results.errorFiles)")
                        ResultRow(title: "Time Taken", value: results.timeTaken)
                    }
                    
                    Divider()
                    
                    // CSV Export Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Results")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            exportToCSV()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Export to CSV")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(classifications.isEmpty)
                        
                        if showExportSuccess, let csvPath = csvExportPath {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Exported to: \(csvPath)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
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
                    Button("Start AI Classification") {
                        startClassification()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(classificationManager == nil)
                }
                
                if isRunning {
                    Button("Stop") {
                        stopClassification()
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
        .alert("CSV Exported", isPresented: $showExportSuccess) {
            Button("OK") { }
            if let csvPath = csvExportPath {
                Button("Show in Finder") {
                    let url = URL(fileURLWithPath: csvPath)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } message: {
            if let csvPath = csvExportPath {
                Text("CSV file exported to:\n\(csvPath)")
            } else {
                Text("CSV file exported successfully")
            }
        }
        .onAppear {
            classificationMode = ClassificationMode.persisted
            // Initialize with best available service
            if checkOllamaAvailable() {
                selectedServiceType = .ollama
            } else if checkOpenAIAvailable() {
                selectedServiceType = .openai
            } else if checkAnthropicAvailable() {
                selectedServiceType = .anthropic
            } else {
                selectedServiceType = .fallback
            }
            updateClassificationManager()
        }
    }
    
    enum ServiceType {
        case ollama
        case openai
        case anthropic
        case fallback
    }
    
    private func checkOllamaAvailable() -> Bool {
        // Quick check if Ollama is available
        let url = URL(string: "http://localhost:11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        var isAvailable = false
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                isAvailable = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 1.5)
        return isAvailable
    }
    
    private func checkOpenAIAvailable() -> Bool {
        // Check if OpenAI API key is configured
        return UserDefaults.standard.string(forKey: "openai_api_key") != nil
    }
    
    private func checkAnthropicAvailable() -> Bool {
        // Check if Anthropic API key is configured
        return UserDefaults.standard.string(forKey: "anthropic_api_key") != nil
    }
    
    // MARK: - CSV Export
    
    private func exportToCSV() {
        guard !classifications.isEmpty else {
            showError(message: "No classification data to export")
            return
        }
        
        // Generate CSV content
        var csvContent = "File Name,Category,Subfolder,Folder Path,Ownership,Subject,Region Segment,Confidence,Method,Reasoning\n"
        
        for (metadata, result, destination) in classifications {
            let fileName = metadata.fileName
            let category = result.category
            let subfolder = result.subfolder
            let folderPath = destination.relativePath(profile: profileStore.profile)
            let ownership = destination.subject.ownership.rawValue
            let subject = destination.subject.primarySubjectName ?? ""
            let region = destination.location.pathRegionSegment ?? ""
            let confidence = String(format: "%.2f", result.confidence)
            let method = result.method.rawValue
            let reasoning = result.reasoning?.replacingOccurrences(of: "\"", with: "\"\"") ?? "" // Escape quotes in CSV
            
            // Escape commas and quotes in file name
            let escapedFileName = fileName.contains(",") || fileName.contains("\"") 
                ? "\"\(fileName.replacingOccurrences(of: "\"", with: "\"\""))\""
                : fileName
            
            let escapedReasoning = reasoning.isEmpty ? "" : (reasoning.contains(",") || reasoning.contains("\"") 
                ? "\"\(reasoning)\""
                : reasoning)
            
            let escapedSubject = csvEscape(subject)
            csvContent += "\(escapedFileName),\(category),\(subfolder),\(csvEscape(folderPath)),\(ownership),\(escapedSubject),\(csvEscape(region)),\(confidence),\(method),\(escapedReasoning)\n"
        }
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "FileClassification_\(timestamp).csv"
        
        // Save to Downloads folder
        let fileManager = FileManager.default
        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let csvURL = downloadsURL.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
            csvExportPath = csvURL.path
            showExportSuccess = true
            addActivity("CSV exported to: \(fileName)", type: .success)
        } catch {
            showError(message: "Failed to export CSV: \(error.localizedDescription)")
        }
    }
    
    private func updateClassificationManager() {
        let llmService: LLMService
        
        switch selectedServiceType {
        case .ollama:
            llmService = OllamaLLMService()
        case .openai:
            if let apiKey = UserDefaults.standard.string(forKey: "openai_api_key"), !apiKey.isEmpty {
                llmService = OpenAILLMService(apiKey: apiKey)
            } else {
                // Fallback to Mock if no API key
                llmService = MockLLMService()
            }
        case .anthropic:
            if let apiKey = UserDefaults.standard.string(forKey: "anthropic_api_key"), !apiKey.isEmpty {
                llmService = AnthropicLLMService(apiKey: apiKey)
            } else {
                // Fallback to Mock if no API key
                llmService = MockLLMService()
            }
        case .fallback:
            // Use MockLLM that always fails to force fallback
            let mockLLM = MockLLMService()
            mockLLM.shouldFail = true
            llmService = mockLLM
        }
        
        let promptBuilder = ClassificationPromptBuilder()
        promptBuilder.userProfile = profileStore.profile
        promptBuilder.knownPeople = profileStore.knownPeople
        promptBuilder.classificationMode = classificationMode

        classificationManager = FileClassificationManager(
            llmService: llmService,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: promptBuilder
        )
        classificationManager?.useFallbackOnFailure = true
        classificationManager?.classificationMode = classificationMode
    }
    
    private func startClassification() {
        guard let manager = classificationManager else {
            showError(message: "Please select a classification service")
            return
        }
        
        isRunning = true
        progress = 0.0
        processedFiles = 0
        showResults = false
        results = nil
        activities.removeAll()
        classifications.removeAll()
        canDismiss = false
        
        addActivity("Starting AI classification...", type: .info)
        addActivity("Using service: \(selectedServiceType)", type: .info)
        addActivity("Style: \(classificationMode.displayName)", type: .info)
        if profileStore.profile.hasIdentity {
            addActivity("Profile: \(profileStore.profile.fullName)", type: .info)
            if let region = profileStore.profile.homeRegion, !region.isEmpty {
                addActivity("Default region: \(region)", type: .info)
            }
        } else {
            addActivity("No profile — set name in Settings for subject-aware paths", type: .warning)
        }

        Task {
            let sourceFolder = URL(fileURLWithPath: folderPath)
            let mover = AIClassifierMover(
                sourceFolder: sourceFolder,
                classificationManager: manager,
                profile: profileStore.profile,
                knownPeople: profileStore.knownPeople
            )
            
            do {
                let results = try await mover.runWithProgress(
                    progressCallback: { current, total, fileName, classification in
                        Task { @MainActor in
                            self.processedFiles = current
                            self.totalFiles = total
                            self.progress = total > 0 ? Double(current) / Double(total) : 0.0
                            self.currentFile = fileName
                            self.currentClassification = classification
                            
                            if let classification = classification {
                                self.addActivity("Classified: \(fileName) → \(classification)", type: .processing)
                            }
                        }
                    },
                    classificationCallback: { metadata, result, destination in
                        Task { @MainActor in
                            self.classifications.append((metadata, result, destination))
                        }
                    }
                )
                
                await MainActor.run {
                    self.isRunning = false
                    self.showResults = true
                    self.results = results
                    self.canDismiss = true
                    
                    self.addActivity("Classification completed successfully!", type: .success)
                    self.addActivity("Moved \(results.movedFiles) files", type: .success)
                    if results.skippedFiles > 0 {
                        self.addActivity("Skipped \(results.skippedFiles) files", type: .warning)
                    }
                    if results.errorFiles > 0 {
                        self.addActivity("\(results.errorFiles) files had errors", type: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.canDismiss = true
                    self.addActivity("Error: \(error.localizedDescription)", type: .error)
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopClassification() {
        isRunning = false
        addActivity("Classification stopped by user", type: .warning)
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

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

