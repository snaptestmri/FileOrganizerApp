import Foundation
import AppKit

struct FileMover {
    let sourceFolder: URL
    let baseTargetFolder: URL

    init(sourceFolder: URL) {
        self.sourceFolder = sourceFolder
        self.baseTargetFolder = sourceFolder
    }

    func run(with keywords: [KeywordEntry]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil) else { return }

        for item in contents {
            let lowerName = item.lastPathComponent.lowercased()
            var matchedKeyword: KeywordEntry? = nil

            for keyword in keywords {
                if lowerName.contains(keyword.keyword.lowercased()) {
                    matchedKeyword = keyword
                    break
                }
            }

            guard let keyword = matchedKeyword else { continue }

            let targetFolder = baseTargetFolder.appendingPathComponent(keyword.category).appendingPathComponent(keyword.subfolder)
            try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

            var destination = targetFolder.appendingPathComponent(item.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                destination = targetFolder.appendingPathComponent("\(timestamp)_\(item.lastPathComponent)")
            }

            try? FileManager.default.moveItem(at: item, to: destination)
        }
    }
    
    func runWithProgress(with keywords: [KeywordEntry], progressCallback: @escaping (Int, Int, String) -> Void) throws -> FileMoveResults {
        let startTime = Date()
        
        // Get all files recursively from source folder and subfolders
        let files = try getAllFilesRecursively(from: sourceFolder)
        
        // Only count files with a matching keyword as 'to process'
        let filesToProcess = files.filter { file in
            let lowerName = file.lastPathComponent.lowercased()
            return keywords.contains { keyword in lowerName.contains(keyword.keyword.lowercased()) }
        }
        let totalFiles = filesToProcess.count
        var processedFiles = 0
        var movedFiles = 0
        var skippedFiles = 0
        var errorFiles = 0
        
        for file in files {
            let currentFileName = file.lastPathComponent
            let lowerName = currentFileName.lowercased()
            guard let matchedKeyword = keywords.first(where: { lowerName.contains($0.keyword.lowercased()) }) else {
                skippedFiles += 1
                continue
            }
            processedFiles += 1
            progressCallback(processedFiles, totalFiles, currentFileName)
            do {
                // Create target folder structure
                let targetFolder = baseTargetFolder
                    .appendingPathComponent(matchedKeyword.category)
                    .appendingPathComponent(matchedKeyword.subfolder)
                try FileManager.default.createDirectory(
                    at: targetFolder, 
                    withIntermediateDirectories: true
                )
                // Handle file name conflicts
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
                // Move the file
                try FileManager.default.moveItem(at: file, to: destination)
                movedFiles += 1
            } catch {
                errorFiles += 1
                print("Error processing file \(currentFileName): \(error.localizedDescription)")
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

    static func chooseSourceFolder() -> URL? {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        return dialog.runModal() == .OK ? dialog.url : nil
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
