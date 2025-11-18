import SwiftUI
import AppKit

struct AIClassificationView: View {
    let folderPath: String
    @Environment(\.dismiss) private var dismiss
    @State private var classificationManager: FileClassificationManager?
    @State private var selectedServiceType: ServiceType = .ollama
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
    @State private var classifications: [(FileMetadata, ClassificationResult)] = []
    
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
                            title: "OpenAI (Cloud AI)",
                            description: "Requires internet and API key. More powerful.",
                            isSelected: selectedServiceType == .openai,
                            isAvailable: checkOpenAIAvailable()
                        ) {
                            selectedServiceType = .openai
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
        .onAppear {
            // Initialize with best available service
            if checkOllamaAvailable() {
                selectedServiceType = .ollama
            } else if checkOpenAIAvailable() {
                selectedServiceType = .openai
            } else {
                selectedServiceType = .fallback
            }
            updateClassificationManager()
        }
    }
    
    enum ServiceType {
        case ollama
        case openai
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
        case .fallback:
            // Use MockLLM that always fails to force fallback
            let mockLLM = MockLLMService()
            mockLLM.shouldFail = true
            llmService = mockLLM
        }
        
        classificationManager = FileClassificationManager(
            llmService: llmService,
            telemetryService: TelemetryService.shared,
            fallbackClassifier: FallbackClassifier(),
            promptBuilder: ClassificationPromptBuilder()
        )
        classificationManager?.useFallbackOnFailure = true
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
        
        Task {
            let sourceFolder = URL(fileURLWithPath: folderPath)
            let mover = AIClassifierMover(
                sourceFolder: sourceFolder,
                classificationManager: manager
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
                    classificationCallback: { metadata, result in
                        Task { @MainActor in
                            self.classifications.append((metadata, result))
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
}

