import Foundation
import UniformTypeIdentifiers
import CoreServices
#if canImport(PDFKit)
import PDFKit
#endif

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

    // Personal domain mode signals
    /// True when this is a directory whose sibling contents match known project-root
    /// files (Package.swift, package.json, Dockerfile, etc.).
    /// A directory that is a project should be classified as Projects/Apps or
    /// Projects/Experiments, not as Documents, regardless of its name.
    let isProjectDirectory: Bool

    /// True when the filename begins with a temporal auto-naming prefix such as
    /// "Screenshot 2024-...", "IMG_", or "PXL_". These files are archival by
    /// nature and should land in a Screenshots/Photos subfolder rather than being
    /// treated as primary documents.
    let hasTemporalName: Bool

    /// The detected life-domain intent of the file, inferred from filename keywords
    /// before the LLM is consulted. Nil means intent is ambiguous and the LLM
    /// or fallback classifier should decide.
    ///
    /// Examples:
    ///   "GeicoVehiclePolicy.pdf" → intent = "insurance" → Personal/Insurance
    ///   "2021_Avaya_Year_End_Performance.pdf" → intent = "performance_review" → Career/Performance Reviews
    ///   "Taxes2025.pdf" → intent = "tax" → Finance/Taxes
    let detectedIntent: String?
    
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

        // Personal domain signals
        let isDir = resourceValues.isDirectory ?? false
        let isProjectDir = isDir ? detectProjectDirectory(siblings: siblingFiles ?? [], directoryName: fileName) : false
        let hasTemporalName = ClassificationConstants.hasTemporalPrefix(fileName)
        let detectedIntent = detectIntent(from: fileName, parentFolder: url.deletingLastPathComponent().lastPathComponent)
        
        // Optional: Get content preview for text files and documents
        var contentPreview: String? = nil
        var hasTextContent = false

        if includePreview, let isDirectory = resourceValues.isDirectory, !isDirectory {
            let preview = extractContentPreview(
                from: url,
                extension: fileExtension,
                typeIdentifier: resourceValues.typeIdentifier,
                maxLength: maxPreviewLength
            )
            contentPreview = preview.text
            hasTextContent = preview.hasText
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
            isProjectDirectory: isProjectDir,
            hasTemporalName: hasTemporalName,
            detectedIntent: detectedIntent,
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
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe  // Suppress error messages to stderr
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Only process output if command succeeded (status 0)
            // Non-zero status means attribute doesn't exist, which is normal
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !string.isEmpty {
                    // Parse plist format if needed
                    return string
                }
            }
            // If terminationStatus != 0, attribute doesn't exist - this is normal, not an error
        } catch {
            // Silently fail - this is a fallback method
        }
        
        return nil
    }
    
    // MARK: - Personal Domain Signal Detection

    /// Returns true when the sibling file list contains at least one file that
    /// unambiguously marks a directory as a software project root.
    private static func detectProjectDirectory(siblings: [String], directoryName: String) -> Bool {
        let lowerName = directoryName.lowercased()
        let nonProjectBundleSuffixes = [".sublime-package", ".plugin", ".bundle", ".app", ".appex"]
        if nonProjectBundleSuffixes.contains(where: { lowerName.hasSuffix($0) }) {
            return false
        }

        // Exact-name matches from the known signals list
        let exactSignals = ClassificationConstants.projectRootSignals
        for sibling in siblings {
            if exactSignals.contains(sibling) { return true }
            // Pattern matches for Xcode project/workspace bundles
            if sibling.hasSuffix(".xcodeproj") || sibling.hasSuffix(".xcworkspace") { return true }
        }
        return false
    }

    /// Infers a specific life-domain intent from the filename and parent folder name
    /// using keyword rules. Returns nil when intent is genuinely ambiguous.
    ///
    /// This encodes the "intent over name" principle: we look at what the file *is*,
    /// not what it happens to be called. The rules are ordered from most specific to
    /// most general to avoid false positives.
    private static func detectIntent(from fileName: String, parentFolder: String) -> String? {
        let name  = fileName.lowercased()
        let folder = parentFolder.lowercased()

        // --- Career (job prep before resume — guides are not CVs) ---
        if ClassificationConstants.matchesJobPrepFilename(fileName) { return "job_prep" }
        if ClassificationConstants.matchesActualResumeFilename(fileName) { return "resume" }
        if matchesAny(name, ["cover letter", "coverletter"]) { return "cover_letter" }
        if matchesAny(name, ["performance", "year end", "yearend", "appraisal", "evaluation"]) { return "performance_review" }
        if matchesAny(name, ["offer letter", "employment letter", "employment agreement"]) { return "offer_letter" }
        if matchesAny(name, ["reference letter", "work ref", "letter of recommendation"]) { return "offer_letter" }
        if matchesAny(name, ["flight", "itinerary", "boarding pass", "airline"]) { return "travel" }
        if matchesAny(name, ["payconex", "payment receipt", "pay receipt"]) { return "receipt" }
        if matchesAny(name, ["w2", "w-2", "paystub", "pay stub", "payslip"]) { return "payroll" }
        if matchesAny(name, ["exam_completion", "certificate", "certification", "badge", "credential"]) { return "certification" }

        // --- Finance ---
        if ClassificationConstants.matchesTaxFilename(fileName) { return "tax" }
        if ClassificationConstants.matchesBankStatementFilename(fileName) { return "bank_statement" }
        if matchesAny(name, ["invoice", "amount due", "bill to"]) { return "invoice" }
        if matchesAny(name, ["receipt", "order confirmation", "purchase"]) { return "receipt" }
        if matchesAny(name, [
            "portfolio", "401k", "ira", "roth", "gainloss", "gain loss", "tradesdownload",
            "brokerage statement", "consolidated form"
        ]) { return "investment" }
        if matchesAny(name, ["remitly", "wire transfer", "transfer activity"]) { return "bank_statement" }

        // --- Legal ---
        if matchesAny(name, ["visa", "i-94", "i94", "passport", "ead", "work permit", "h1b", "h-1b", "green card"]) { return "immigration" }
        if matchesAny(name, ["probate", "estate", "distribution", "administrator", "petition"]) { return "probate" }
        if matchesAny(name, ["grievance", "court", "case#", "legal notice", "subpoena", "deposition"]) { return "court_case" }
        if matchesAny(name, ["affidavit", "declaration", "evidence of funds"]) { return "evidence" }
        if matchesAny(name, ["nda", "non-disclosure", "agreement", "contract", "lease", "rental agreement"]) { return "contract" }

        // --- Personal / Health ---
        if matchesAny(name, ["health", "medical", "doctor", "appointment", "lab result", "diagnosis", "rx", "prescription", "healthsummary", "peryourhealth", "medications", "1095-b", "form 1095"]) { return "health" }
        if matchesAny(name, ["insurance", "policy", "geico", "aetna", "anthem", "cigna", "uhc"]) { return "insurance" }
        if ClassificationConstants.matchesIdentityFilename(fileName) { return "identity" }
        if matchesAny(name, ["rent", "lease", "apartment", "landlord", "renter"]) { return "rent" }

        // --- Career / learning (courses & university under Career) ---
        if matchesAny(name, ["transcript", "scholarship", "admission", "acceptance", "degree", "gpa", "university"]) { return "university" }
        if matchesAny(name, [
            "course", "lecture", "slides", "syllabus", "pm school", "productschool",
            "cohort", "prompt engineering", "prd template", "lab_"
        ]) { return "course" }
        if matchesAny(name, ["textbook", "ebook", "e-book", "reading list"]) { return "book" }
        if matchesAny(name, ["class notes", "lecture notes", "study notes", "study guide"]) { return "notes" }

        // --- Temporal / Media (checked last — these are structural, not semantic) ---
        if ClassificationConstants.hasTemporalPrefix(fileName) {
            let ext = (fileName as NSString).pathExtension.lowercased()
            if ClassificationConstants.videoExtensions.contains(ext) { return "video" }
            return "screenshot_or_photo"
        }

        // --- Folder context as fallback ---
        if matchesAny(folder, ["taxes", "tax"]) { return "tax" }
        if matchesAny(folder, ["probate", "estate"]) { return "probate" }
        if matchesAny(folder, ["visa", "immigration"]) { return "immigration" }
        if matchesAny(folder, ["health", "medical", "meddocuments"]) { return "health" }
        if matchesAny(folder, ["resumes", "resume"]) { return "resume" }
        if matchesAny(folder, ["interview", "job prep", "job-prep", "jobprep", "career prep", "career"]) {
            return "job_prep"
        }

        return nil
    }

    /// Convenience: returns true if the target string contains any of the given keywords.
    private static func matchesAny(_ target: String, _ keywords: [String]) -> Bool {
        keywords.contains { target.contains($0) }
    }

    // MARK: - Filename Pattern Detection

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
    
    // MARK: - Content Preview Extraction

    private struct ContentPreviewResult {
        let text: String?
        let hasText: Bool
    }

    /// Extract a short text preview to help the LLM classify by content, not just filename.
    private static func extractContentPreview(
        from url: URL,
        extension fileExtension: String,
        typeIdentifier: String?,
        maxLength: Int
    ) -> ContentPreviewResult {
        let ext = fileExtension.lowercased()
        let uti = typeIdentifier?.lowercased() ?? ""

        if ClassificationConstants.textPreviewExtensions.contains(ext)
            || uti.contains("text")
            || uti.contains("plain")
            || uti.contains("sourcecode") {
            if let text = readTextPreview(from: url, maxLength: maxLength) {
                return ContentPreviewResult(text: text, hasText: true)
            }
        }

        if ext == "pdf" || uti.contains("pdf") {
            // Spotlight first — avoids CoreGraphics/PDFKit errors on scanned or damaged PDFs
            if let spotlightText = extractTextFromSpotlight(url: url, maxLength: maxLength) {
                return ContentPreviewResult(text: spotlightText, hasText: true)
            }
            if let pdfText = extractTextFromPDF(url: url, maxLength: maxLength) {
                return ContentPreviewResult(text: pdfText, hasText: true)
            }
        }

        if ext == "docx" || ext == "doc" || uti.contains("wordprocessing") {
            if let docText = extractTextFromWordDocument(url: url, maxLength: maxLength) {
                return ContentPreviewResult(text: docText, hasText: true)
            }
        }

        return ContentPreviewResult(text: nil, hasText: false)
    }

    private static func readTextPreview(from url: URL, maxLength: Int) -> String? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        let encodings: [String.Encoding] = [.utf8, .utf16, .macOSRoman, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(maxLength))
                }
            }
        }
        return nil
    }

    /// Spotlight text index — helps image-only or scanned PDFs where PDFKit returns no text.
    private static func extractTextFromSpotlight(url: URL, maxLength: Int) -> String? {
        guard let mdItem = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        if let text = MDItemCopyAttribute(mdItem, kMDItemTextContent as CFString) as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(maxLength))
            }
        }
        return nil
    }

    /// Extract text from PDF file (fallback when Spotlight has no index yet).
    private static func extractTextFromPDF(url: URL, maxLength: Int) -> String? {
        #if canImport(PDFKit)
        var result: String?
        autoreleasepool {
            guard let pdfDocument = PDFDocument(url: url), pdfDocument.pageCount > 0 else {
                return
            }
            var extractedText = ""
            let pageCount = min(pdfDocument.pageCount, 3)
            for pageIndex in 0..<pageCount {
                guard let page = pdfDocument.page(at: pageIndex), let pageText = page.string else { continue }
                extractedText += pageText + " "
                if extractedText.count >= maxLength { break }
            }
            if !extractedText.isEmpty {
                result = String(extractedText.prefix(maxLength))
            }
        }
        return result
        #else
        return nil
        #endif
    }
    
    /// Extract text from Word document (.docx)
    private static func extractTextFromWordDocument(url: URL, maxLength: Int) -> String? {
        // Word documents (.docx) are ZIP archives containing XML
        // Extract text from word/document.xml
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        // Create temp directory
        guard (try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        
        defer {
            // Clean up temp directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Unzip the .docx file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", url.path, "-d", tempDir.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            // Read word/document.xml
            let documentXML = tempDir.appendingPathComponent("word/document.xml")
            guard fileManager.fileExists(atPath: documentXML.path),
                  let xmlData = try? Data(contentsOf: documentXML),
                  let xmlString = String(data: xmlData, encoding: .utf8) else {
                return nil
            }
            
            // Extract text from XML (simple regex-based extraction)
            // Look for <w:t> tags which contain text in .docx
            var extractedText = ""
            let pattern = "<w:t[^>]*>([^<]+)</w:t>"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
                let matches = regex.matches(in: xmlString, options: [], range: range)
                
                for match in matches {
                    if match.numberOfRanges > 1,
                       let textRange = Range(match.range(at: 1), in: xmlString) {
                        let text = String(xmlString[textRange])
                        extractedText += text + " "
                        
                        if extractedText.count >= maxLength {
                            break
                        }
                    }
                }
            }
            
            // Also try to decode XML entities
            extractedText = extractedText
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
            
            return extractedText.isEmpty ? nil : String(extractedText.prefix(maxLength))
            
        } catch {
            return nil
        }
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
            description += "Filename structure hints (NOT subfolder names): \(commonPatterns.joined(separator: ", "))\n"
        }

        if ClassificationConstants.isEditorPackage(fileName, fileExtension: fileExtension) {
            description += "⚠️ Editor plugin package — use Projects/Code, not Projects/Apps.\n"
        }
        
        if let siblings = siblingFiles, !siblings.isEmpty {
            description += "Siblings: \(siblings.prefix(5).joined(separator: ", "))\(siblings.count > 5 ? "..." : "")\n"
        }
        
        if isProjectDirectory {
            description += "⚠️ Project directory: sibling files indicate a software project root.\n"
        }

        if hasTemporalName {
            description += "⚠️ Temporal name: filename begins with an auto-naming prefix (screenshot/photo export).\n"
        }

        if let intent = detectedIntent {
            description += "Detected intent: \(intent)"
            switch intent {
            case "job_prep":
                description += " → Career/Job Prep (prep material or guide, NOT Resumes)\n"
            case "resume":
                description += " → Career/Resumes (actual CV document)\n"
            default:
                description += "\n"
            }
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

