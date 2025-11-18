import Foundation

/// File mover that uses AI/LLM classification instead of keywords
class AIClassifierMover {
    let sourceFolder: URL
    let baseTargetFolder: URL
    let classificationManager: FileClassificationManager
    
    init(sourceFolder: URL, classificationManager: FileClassificationManager) {
        self.sourceFolder = sourceFolder
        self.baseTargetFolder = sourceFolder
        self.classificationManager = classificationManager
    }
    
    
    /// Run AI classification and move files with progress tracking
    func runWithProgress(
        progressCallback: @escaping (Int, Int, String, String?) -> Void,
        classificationCallback: @escaping (FileMetadata, ClassificationResult) -> Void
    ) async throws -> FileMoveResults {
        let startTime = Date()
        
        // Get all files
        let contents = try FileManager.default.contentsOfDirectory(
            at: sourceFolder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        let files = contents.filter { url in
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return resourceValues?.isRegularFile == true
        }
        
        let totalFiles = files.count
        var processedFiles = 0
        var movedFiles = 0
        var skippedFiles = 0
        var errorFiles = 0
        
        // Extract metadata for all files
        var fileMetadata: [(URL, FileMetadata)] = []
        for file in files {
            if let metadata = FileMetadata.extract(from: file, includePreview: false) {
                fileMetadata.append((file, metadata))
            }
        }
        
        // Classify files in batches
        let batchSize = 10
        for batchStart in stride(from: 0, to: fileMetadata.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, fileMetadata.count)
            let batch = Array(fileMetadata[batchStart..<batchEnd])
            
            let metadataBatch = batch.map { $0.1 }
            
            // Classify batch using FileClassificationManager (doesn't throw)
            let classifications = await classificationManager.classifyFiles(metadataBatch)
            
            // Process each file in the batch
            for (index, (fileURL, metadata)) in batch.enumerated() {
                guard index < classifications.count else {
                    skippedFiles += 1
                    processedFiles += 1
                    let currentFileName = fileURL.lastPathComponent
                    progressCallback(processedFiles, totalFiles, currentFileName, nil)
                    continue
                }
                
                let classification = classifications[index]
                let currentFileName = fileURL.lastPathComponent
                
                processedFiles += 1
                progressCallback(processedFiles, totalFiles, currentFileName, "\(classification.category)/\(classification.subfolder)")
                classificationCallback(metadata, classification)
                
                // Move file based on classification
                do {
                    let targetFolder = baseTargetFolder
                        .appendingPathComponent(classification.category)
                        .appendingPathComponent(classification.subfolder)
                    
                    try FileManager.default.createDirectory(
                        at: targetFolder,
                        withIntermediateDirectories: true
                    )
                    
                    var destination = targetFolder.appendingPathComponent(currentFileName)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        let timestamp = ISO8601DateFormatter().string(from: Date())
                            .replacingOccurrences(of: ":", with: "-")
                            .replacingOccurrences(of: ".", with: "-")
                        let nameWithoutExtension = currentFileName.replacingOccurrences(of: ".\(currentFileName.components(separatedBy: ".").last ?? "")", with: "")
                        let fileExtension = currentFileName.components(separatedBy: ".").last ?? ""
                        destination = targetFolder.appendingPathComponent("\(nameWithoutExtension)_\(timestamp).\(fileExtension)")
                    }
                    
                    try FileManager.default.moveItem(at: fileURL, to: destination)
                    movedFiles += 1
                } catch {
                    errorFiles += 1
                    print("Error moving file \(currentFileName): \(error.localizedDescription)")
                }
            }
        }
        
        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        let timeTaken = formatTimeInterval(timeInterval)
        
        return FileMoveResults(
            processedFiles: processedFiles,
            movedFiles: movedFiles,
            skippedFiles: skippedFiles,
            errorFiles: errorFiles,
            timeTaken: timeTaken
        )
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 1 {
            return String(format: "%.0f ms", interval * 1000)
        } else if interval < 60 {
            return String(format: "%.1f seconds", interval)
        } else {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}

