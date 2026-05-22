import Foundation

/// File mover that uses AI/LLM classification instead of keywords
class AIClassifierMover {
    let sourceFolder: URL
    let baseTargetFolder: URL
    let classificationManager: FileClassificationManager
    let profile: UserProfile
    let knownPeople: [KnownPerson]

    init(
        sourceFolder: URL,
        classificationManager: FileClassificationManager,
        profile: UserProfile = UserProfile(),
        knownPeople: [KnownPerson] = []
    ) {
        self.sourceFolder = sourceFolder
        self.baseTargetFolder = sourceFolder
        self.classificationManager = classificationManager
        var p = profile
        p.syncDerivedFields()
        self.profile = p
        self.knownPeople = knownPeople
    }
    
    
    /// Run AI classification and move files with progress tracking
    func runWithProgress(
        progressCallback: @escaping (Int, Int, String, String?) -> Void,
        classificationCallback: @escaping (FileMetadata, ClassificationResult, OrganizeDestination) -> Void
    ) async throws -> FileMoveResults {
        let startTime = Date()
        
        // Get all files recursively from source folder and subfolders
        let files = try getAllFilesRecursively(from: sourceFolder)
        
        let totalFiles = files.count
        var processedFiles = 0
        var movedFiles = 0
        var skippedFiles = 0
        var errorFiles = 0
        
        // Extract metadata for all files
        var fileMetadata: [(URL, FileMetadata)] = []
        for file in files {
            if let metadata = FileMetadata.extract(from: file, includePreview: true, maxPreviewLength: 500) {
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
                let destination = OrganizePlanner.plan(
                    metadata: metadata,
                    classification: classification,
                    profile: profile,
                    knownPeople: knownPeople
                )
                let currentFileName = fileURL.lastPathComponent
                let relativePath = destination.relativePath(profile: profile)

                processedFiles += 1
                progressCallback(processedFiles, totalFiles, currentFileName, relativePath)
                classificationCallback(metadata, classification, destination)

                // Move file based on classification + subject + location
                do {
                    let targetFolder = OrganizePlanner.targetFolderURL(
                        base: baseTargetFolder,
                        destination: destination,
                        profile: profile
                    )
                    
                    try FileManager.default.createDirectory(
                        at: targetFolder,
                        withIntermediateDirectories: true
                    )
                    
                    var destination = targetFolder.appendingPathComponent(currentFileName)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        let timestamp = ISO8601DateFormatter().string(from: Date())
                            .replacingOccurrences(of: ":", with: "-")
                            .replacingOccurrences(of: ".", with: "-")
                        
                        // Safely extract file extension and name
                        let fileExtension: String
                        let nameWithoutExtension: String
                        if let lastDotIndex = currentFileName.lastIndex(of: "."), lastDotIndex != currentFileName.startIndex {
                            fileExtension = String(currentFileName[currentFileName.index(after: lastDotIndex)...])
                            nameWithoutExtension = String(currentFileName[..<lastDotIndex])
                        } else {
                            fileExtension = ""
                            nameWithoutExtension = currentFileName
                        }
                        
                        if !fileExtension.isEmpty {
                            destination = targetFolder.appendingPathComponent("\(nameWithoutExtension)_\(timestamp).\(fileExtension)")
                        } else {
                            destination = targetFolder.appendingPathComponent("\(nameWithoutExtension)_\(timestamp)")
                        }
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
    
    /// Recursively get all files from a directory and its subdirectories
    private func getAllFilesRecursively(from folderURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var allFiles: [URL] = []
        
        func scanDirectory(_ url: URL) throws {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in contents {
                let resourceValues = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                
                if resourceValues?.isRegularFile == true {
                    allFiles.append(item)
                } else if resourceValues?.isDirectory == true {
                    // Recursively scan subdirectories
                    try scanDirectory(item)
                }
            }
        }
        
        try scanDirectory(folderURL)
        return allFiles
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

