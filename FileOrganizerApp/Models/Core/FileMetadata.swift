import Foundation
import UniformTypeIdentifiers
import CoreServices

/// Metadata structure for LLM classification - contains NO file content, only metadata
struct FileMetadata: Codable {
    // Basic file information
    let fileName: String
    let fileExtension: String
    let fileNameWithoutExtension: String
    let fullPath: String?  // Optional - can be omitted for privacy
    let parentFolder: String?  // Optional - parent folder name only
    
    // File system metadata
    let fileSize: Int64  // in bytes
    let fileSizeFormatted: String  // e.g., "2.5 MB"
    let creationDate: Date?
    let modificationDate: Date?
    let fileType: String?  // UTI (Uniform Type Identifier)
    let mimeType: String?
    
    // File characteristics (without reading content)
    let isDirectory: Bool
    let isHidden: Bool
    let isPackage: Bool  // e.g., .app bundles
    
    // Optional: Content hints (for text files, first N characters only)
    let contentPreview: String?  // First 200-500 chars for text files only (optional)
    let hasTextContent: Bool  // Can we extract text preview?
    
    // Context information
    let siblingFiles: [String]?  // Names of files in same folder (for context)
    let folderDepth: Int  // How deep in folder hierarchy
    
    // Classification hints
    let commonPatterns: [String]  // Detected patterns in filename (dates, numbers, etc.)
    
    // Document metadata (extracted from file metadata, not content)
    let author: String?  // Author/creator of the file
    let keywords: [String]?  // Keywords/tags associated with the file
    let whereFrom: String?  // Origin/source URL (where file was downloaded from)
    
    /// Extract metadata from a file URL without reading file content
    static func extract(from url: URL, includePreview: Bool = false, maxPreviewLength: Int = 300) -> FileMetadata? {
        let fileManager = FileManager.default
        
        // Get resource values
        let resourceKeys: [URLResourceKey] = [
            .nameKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .typeIdentifierKey,
            .isDirectoryKey,
            .isHiddenKey,
            .isPackageKey
        ]
        
        guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
            return nil
        }
        
        let fileName = url.lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        
        // Get file size
        let fileSize = resourceValues.fileSize ?? 0
        let fileSizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        
        // Get parent folder name (not full path)
        let parentFolder = url.deletingLastPathComponent().lastPathComponent
        
        // Get sibling files (just names, for context)
        let siblingFiles = try? fileManager.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .map { $0.lastPathComponent }
        
        // Calculate folder depth
        let pathComponents = url.pathComponents
        let homePath = fileManager.homeDirectoryForCurrentUser.pathComponents.count
        let folderDepth = max(0, pathComponents.count - homePath - 1)
        
        // Detect patterns in filename
        let patterns = detectPatterns(in: fileName)
        
        // Optional: Get content preview for text files only
        var contentPreview: String? = nil
        var hasTextContent = false
        
        if includePreview && !resourceValues.isDirectory! {
            // Only try preview for text-based files
            if let typeIdentifier = resourceValues.typeIdentifier,
               typeIdentifier.contains("text") || 
               typeIdentifier.contains("plain") ||
               fileExtension.lowercased() == "txt" ||
               fileExtension.lowercased() == "md" ||
               fileExtension.lowercased() == "json" {
                
                if let data = try? Data(contentsOf: url),
                   let text = String(data: data, encoding: .utf8) {
                    hasTextContent = true
                    let preview = String(text.prefix(maxPreviewLength))
                    contentPreview = preview.isEmpty ? nil : preview
                }
            }
        }
        
        // Get MIME type from UTI
        var mimeType: String? = nil
        if let typeIdentifier = resourceValues.typeIdentifier {
            mimeType = UTType(typeIdentifier)?.preferredMIMEType
        }
        
        // Extract author, keywords, and where from using Spotlight metadata
        let (author, keywords, whereFrom) = extractDocumentMetadata(from: url)
        
        return FileMetadata(
            fileName: fileName,
            fileExtension: fileExtension,
            fileNameWithoutExtension: fileNameWithoutExtension,
            fullPath: nil,  // Omit for privacy
            parentFolder: parentFolder,
            fileSize: Int64(fileSize),
            fileSizeFormatted: fileSizeFormatted,
            creationDate: resourceValues.creationDate,
            modificationDate: resourceValues.contentModificationDate,
            fileType: resourceValues.typeIdentifier,
            mimeType: mimeType,
            isDirectory: resourceValues.isDirectory ?? false,
            isHidden: resourceValues.isHidden ?? false,
            isPackage: resourceValues.isPackage ?? false,
            contentPreview: contentPreview,
            hasTextContent: hasTextContent,
            siblingFiles: siblingFiles,
            folderDepth: folderDepth,
            commonPatterns: patterns,
            author: author,
            keywords: keywords,
            whereFrom: whereFrom
        )
    }
    
    /// Extract document metadata (author, keywords, where from) using Spotlight
    private static func extractDocumentMetadata(from url: URL) -> (author: String?, keywords: [String]?, whereFrom: String?) {
        var author: String? = nil
        var keywords: [String]? = nil
        var whereFrom: String? = nil
        
        // Use MDItem (Spotlight) to get metadata
        if let mdItem = MDItemCreateWithURL(nil, url as CFURL) {
            // Get author - try multiple attribute names
            if let authorValue = MDItemCopyAttribute(mdItem, "kMDItemAuthors" as CFString) as? [String], !authorValue.isEmpty {
                author = authorValue.first
            } else if let authorValue = MDItemCopyAttribute(mdItem, "kMDItemAuthor" as CFString) as? String, !authorValue.isEmpty {
                author = authorValue
            } else if let creatorValue = MDItemCopyAttribute(mdItem, "kMDItemCreator" as CFString) as? String, !creatorValue.isEmpty {
                author = creatorValue
            }
            
            // Get keywords - try multiple attribute names
            if let keywordsValue = MDItemCopyAttribute(mdItem, "kMDItemKeywords" as CFString) as? [String], !keywordsValue.isEmpty {
                keywords = keywordsValue
            } else if let keywordsValue = MDItemCopyAttribute(mdItem, "kMDItemUserTags" as CFString) as? [String], !keywordsValue.isEmpty {
                keywords = keywordsValue
            }
            
            // Get "where from" (origin URL)
            if let whereFroms = MDItemCopyAttribute(mdItem, "kMDItemWhereFroms" as CFString) as? [String], !whereFroms.isEmpty {
                whereFrom = whereFroms.first
            }
        }
        
        // Fallback: Try extended attributes for "where from" if Spotlight doesn't have it
        if whereFrom == nil {
            whereFrom = getWhereFromFromExtendedAttributes(url: url)
        }
        
        return (author, keywords, whereFrom)
    }
    
    /// Get "where from" from extended attributes (com.apple.metadata:kMDItemWhereFroms)
    private static func getWhereFromFromExtendedAttributes(url: URL) -> String? {
        // Try to get from extended attributes using xattr
        // This is a fallback if MDItem doesn't have the information
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-p", "com.apple.metadata:kMDItemWhereFroms", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !string.isEmpty {
                    // Parse plist format if needed
                    return string
                }
            }
        } catch {
            // Silently fail - this is a fallback method
        }
        
        return nil
    }
    
    /// Detect common patterns in filename (dates, numbers, etc.)
    private static func detectPatterns(in filename: String) -> [String] {
        var patterns: [String] = []
        
        // Date patterns (YYYY-MM-DD, MM-DD-YYYY, etc.)
        let datePatterns = [
            "\\d{4}-\\d{2}-\\d{2}",  // YYYY-MM-DD
            "\\d{2}-\\d{2}-\\d{4}",  // MM-DD-YYYY
            "\\d{4}_\\d{2}_\\d{2}",  // YYYY_MM_DD
        ]
        
        for pattern in datePatterns {
            if filename.range(of: pattern, options: .regularExpression) != nil {
                patterns.append("contains_date")
                break
            }
        }
        
        // Version numbers (v1, v2.0, etc.)
        if filename.range(of: "v\\d+(\\.\\d+)?", options: .regularExpression) != nil {
            patterns.append("contains_version")
        }
        
        // Numbers/IDs
        if filename.range(of: "\\d{3,}", options: .regularExpression) != nil {
            patterns.append("contains_numbers")
        }
        
        // Common separators
        if filename.contains("_") { patterns.append("uses_underscores") }
        if filename.contains("-") { patterns.append("uses_hyphens") }
        if filename.contains(" ") { patterns.append("uses_spaces") }
        
        return patterns
    }
    
    /// Convert to JSON for LLM API
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Create a human-readable description for LLM prompt
    func toDescription() -> String {
        var description = "File: \(fileName)\n"
        description += "Type: \(fileExtension.isEmpty ? "no extension" : fileExtension)\n"
        description += "Size: \(fileSizeFormatted)\n"
        
        if let modDate = modificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            description += "Modified: \(formatter.string(from: modDate))\n"
        }
        
        if let parent = parentFolder {
            description += "Location: .../\(parent)/\n"
        }
        
        if !commonPatterns.isEmpty {
            description += "Patterns: \(commonPatterns.joined(separator: ", "))\n"
        }
        
        if let siblings = siblingFiles, !siblings.isEmpty {
            description += "Siblings: \(siblings.prefix(5).joined(separator: ", "))\(siblings.count > 5 ? "..." : "")\n"
        }
        
        if let preview = contentPreview, !preview.isEmpty {
            description += "\nContent preview (first \(preview.count) chars):\n\(preview)\n"
        }
        
        if let author = author, !author.isEmpty {
            description += "Author: \(author)\n"
        }
        
        if let keywords = keywords, !keywords.isEmpty {
            description += "Keywords: \(keywords.joined(separator: ", "))\n"
        }
        
        if let whereFrom = whereFrom, !whereFrom.isEmpty {
            description += "Source: \(whereFrom)\n"
        }
        
        return description
    }
}

/// Batch metadata for processing multiple files
struct FileMetadataBatch: Codable {
    let files: [FileMetadata]
    let totalCount: Int
    let context: BatchContext?
    
    struct BatchContext: Codable {
        let sourceFolder: String?  // Just folder name, not full path
        let totalSize: Int64
        let fileTypes: [String: Int]  // Count by extension
    }
}

