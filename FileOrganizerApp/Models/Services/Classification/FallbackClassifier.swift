//
//  FallbackClassifier.swift
//  File Classification System
//
//  Rule-based fallback classifier for when LLM classification fails.
//  Uses filename intent, content preview keywords, extensions, and folder context.
//

import Foundation

// MARK: - Fallback Classifier

class FallbackClassifier {

    // MARK: - Public Methods

    /// Classify a file using deterministic life-domain rules.
    func classify(_ metadata: FileMetadata) -> ClassificationResult {
        classifyPersonalDomain(metadata)
    }

    // MARK: - Personal Domain
    //
    // Priority chain:
    //   1. Project directory signal  → Projects/Apps or Projects/Experiments
    //   2. Temporal name signal      → Media/Screenshots or Media/Photos
    //   3. Filename intent (pre-computed at extract time)
    //   4. Content preview intent    → same taxonomy keywords, lower confidence
    //   5. Extension                 → Media or Projects for unambiguous types only

    func classifyPersonalDomain(_ metadata: FileMetadata) -> ClassificationResult {
        var reasoning: [String] = []
        var confidence: Double = 0.70

        // --- Rule 1: Project directory ---
        if metadata.isDirectory && metadata.isProjectDirectory {
            reasoning.append("directory + project-root signals in siblings")
            let subfolder = metadata.fileName.lowercased().contains("test") ||
                            metadata.fileName.lowercased().contains("experiment") ||
                            metadata.fileName.lowercased().contains("sandbox") ? "Experiments" : "Apps"
            return ClassificationResult(
                category: "Projects",
                subfolder: subfolder,
                confidence: 0.95,
                reasoning: reasoning.joined(separator: "; "),
                method: .fallback
            )
        }

        // --- Rule 2: Temporal name ---
        if metadata.hasTemporalName {
            reasoning.append("temporal auto-naming prefix")
            let ext = metadata.fileExtension.lowercased()
            let subfolder: String
            if ClassificationConstants.videoExtensions.contains(ext) {
                subfolder = "Videos"
            } else if metadata.fileName.lowercased().hasPrefix("screenshot") ||
                      metadata.fileName.lowercased().hasPrefix("screen shot") {
                subfolder = "Screenshots"
            } else {
                subfolder = "Photos"
            }
            return ClassificationResult(
                category: "Media",
                subfolder: subfolder,
                confidence: 0.92,
                reasoning: reasoning.joined(separator: "; "),
                method: .fallback
            )
        }

        // --- Rule 3: Filename intent (computed during metadata extraction) ---
        if let intent = metadata.detectedIntent {
            reasoning.append("filename intent: \(intent)")
            if let (category, subfolder, conf) = intentToPersonalDomain(intent, fromPreview: false) {
                confidence = conf
                return ClassificationResult(
                    category: category,
                    subfolder: subfolder,
                    confidence: confidence,
                    reasoning: reasoning.joined(separator: "; "),
                    method: .fallback
                )
            }
        }

        // --- Rule 4: Preview intent (offline scan of extracted text) ---
        if metadata.detectedIntent == nil,
           let preview = metadata.contentPreview?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preview.isEmpty,
           let previewIntent = FileMetadata.detectIntent(
               in: preview,
               parentFolder: metadata.parentFolder,
               treatAsFilename: false
           ),
           let (category, subfolder, conf) = intentToPersonalDomain(previewIntent, fromPreview: true) {
            reasoning.append("preview intent: \(previewIntent)")
            return ClassificationResult(
                category: category,
                subfolder: subfolder,
                confidence: conf,
                reasoning: reasoning.joined(separator: "; "),
                method: .fallback
            )
        }

        // --- Rule 5: Extension for unambiguous types (Media, code) ---
        let ext = metadata.fileExtension.lowercased()
        if ClassificationConstants.imageExtensions.contains(ext) {
            return ClassificationResult(category: "Media", subfolder: "Photos", confidence: 0.85,
                reasoning: "image extension; no stronger intent signal", method: .fallback)
        }
        if ClassificationConstants.videoExtensions.contains(ext) {
            return ClassificationResult(category: "Media", subfolder: "Videos", confidence: 0.85,
                reasoning: "video extension; no stronger intent signal", method: .fallback)
        }
        if ClassificationConstants.audioExtensions.contains(ext) {
            return ClassificationResult(category: "Media", subfolder: "Audio", confidence: 0.85,
                reasoning: "audio extension; no stronger intent signal", method: .fallback)
        }
        if ClassificationConstants.isEditorPackage(metadata.fileName, fileExtension: ext) {
            return ClassificationResult(category: "Projects", subfolder: "Code", confidence: 0.90,
                reasoning: "editor plugin package → Projects/Code", method: .fallback)
        }
        if ClassificationConstants.codeExtensions.contains(ext) || ClassificationConstants.webExtensions.contains(ext) {
            return ClassificationResult(category: "Projects", subfolder: "Code", confidence: 0.85,
                reasoning: "code extension; no stronger intent signal", method: .fallback)
        }
        if ClassificationConstants.modelExtensions.contains(ext) {
            return ClassificationResult(category: "Projects", subfolder: "Code", confidence: 0.85,
                reasoning: "3D/model extension; no stronger intent signal", method: .fallback)
        }

        // --- Default: ambiguous document ---
        return ClassificationResult(
            category: "Personal",
            subfolder: "General",
            confidence: 0.45,
            reasoning: "no filename, preview, or extension signal; default personal",
            method: .fallback
        )
    }

    /// Maps an intent string to category, subfolder, and confidence.
    /// Preview-derived intents use slightly lower confidence than filename signals.
    private func intentToPersonalDomain(
        _ intent: String,
        fromPreview: Bool
    ) -> (category: String, subfolder: String, confidence: Double)? {
        let previewConfidenceDelta = 0.08
        func adjusted(_ base: Double) -> Double {
            fromPreview ? max(base - previewConfidenceDelta, 0.58) : base
        }

        switch intent {
        // Career
        case "job_prep":          return ("Career", "Job Prep",            adjusted(0.92))
        case "resume":            return ("Career", "Resumes",             adjusted(0.95))
        case "cover_letter":      return ("Career", "Cover Letters",       adjusted(0.95))
        case "performance_review":return ("Career", "Performance Reviews", adjusted(0.93))
        case "offer_letter":      return ("Career", "Work",                adjusted(0.90))
        case "payroll":           return ("Career", "Work",                adjusted(0.88))
        case "certification":     return ("Career", "Certifications",      adjusted(0.90))
        // Finance
        case "tax":               return ("Finance", "Taxes",              adjusted(0.95))
        case "bank_statement":    return ("Finance", "Bank Statements",    adjusted(0.92))
        case "invoice":           return ("Finance", "Bills",              adjusted(0.90))
        case "receipt":           return ("Finance", "Receipts",           adjusted(0.90))
        case "investment":        return ("Finance", "Investments",        adjusted(0.92))
        // Legal
        case "immigration":       return ("Legal",   "Immigration",        adjusted(0.95))
        case "probate":           return ("Legal",   "Probate",            adjusted(0.95))
        case "court_case":        return ("Legal",   "Court Cases",        adjusted(0.90))
        case "evidence":          return ("Legal",   "Evidence",           adjusted(0.88))
        case "contract":          return ("Legal",   "Contracts",          adjusted(0.85))
        // Personal
        case "health":            return ("Personal","Health",             adjusted(0.92))
        case "insurance":         return ("Personal","Insurance",          adjusted(0.92))
        case "identity":          return ("Personal","Identity",           adjusted(0.95))
        case "rent":              return ("Personal","Rent",               adjusted(0.90))
        case "travel":            return ("Personal","General",            adjusted(0.82))
        // Learning (under Career)
        case "university":        return ("Career", "University",         adjusted(0.90))
        case "course":            return ("Career", "PM Courses",         adjusted(0.88))
        case "book":              return ("Career", "Books",              adjusted(0.85))
        case "notes":             return ("Career", "Notes",              adjusted(0.85))
        // Media (temporal handled earlier, but catch-all)
        case "screenshot_or_photo": return ("Media", "Screenshots",       adjusted(0.90))
        case "video":             return ("Media",   "Videos",             adjusted(0.90))
        default:                  return nil
        }
    }
    
    /// Determine category from file extension only
    /// For archives/installers, also needs fileName to classify by content
    func determineCategoryFromExtension(_ fileExtension: String, fileName: String? = nil) -> String {
        let ext = fileExtension.lowercased()
        
        // Image extensions
        if ClassificationConstants.imageExtensions.contains(ext) {
            return "Media"
        }
        
        // Video extensions
        if ClassificationConstants.videoExtensions.contains(ext) {
            return "Media"
        }
        
        // Audio extensions
        if ClassificationConstants.audioExtensions.contains(ext) {
            return "Media"
        }
        
        // 3D model extensions
        if ClassificationConstants.modelExtensions.contains(ext) {
            return "Projects"
        }
        
        // Editor plugin packages (zip archives, not app repos)
        if ClassificationConstants.isEditorPackage(fileName ?? "", fileExtension: ext) {
            return "Projects"
        }

        // Code extensions
        if ClassificationConstants.codeExtensions.contains(ext) {
            return "Projects"
        }

        // Web extensions
        if ClassificationConstants.webExtensions.contains(ext) {
            return "Projects"
        }
        
        // Presentation extensions
        if ClassificationConstants.presentationExtensions.contains(ext) {
            return "Documents"
        }
        
        // Spreadsheet extensions
        if ClassificationConstants.spreadsheetExtensions.contains(ext) {
            return "Documents"
        }
        
        // Document extensions
        if ClassificationConstants.documentExtensions.contains(ext) {
            return "Documents"
        }
        
        // Archive and installer extensions - classify by filename/content
        if ClassificationConstants.archiveExtensions.contains(ext) || ClassificationConstants.installerExtensions.contains(ext) {
            return classifyArchiveByContent(fileName: fileName ?? "unknown", fileExtension: ext)
        }
        
        // Default to Documents for unknown extensions
        return "Documents"
    }
    
    // MARK: - Private Methods

    /// Classify archive/installer files by filename content hints
    private func classifyArchiveByContent(fileName: String, fileExtension: String) -> String {
        let lowerFileName = fileName.lowercased()

        if ClassificationConstants.isEditorPackage(fileName, fileExtension: fileExtension) {
            return "Projects"
        }

        // Check for design/assets content
        if lowerFileName.contains("vector") || lowerFileName.contains("logo") || 
           lowerFileName.contains("icon") || lowerFileName.contains("asset") ||
           lowerFileName.contains("design") || lowerFileName.contains("graphic") {
            return "Projects"
        }
        
        // Check for code/project content
        if lowerFileName.contains("code") || lowerFileName.contains("source") ||
           lowerFileName.contains("project") || lowerFileName.contains("dev") ||
           lowerFileName.contains("sdk") || lowerFileName.contains("framework") {
            return "Projects"
        }
        
        // Check for installer/application
        if ClassificationConstants.installerExtensions.contains(fileExtension) ||
           lowerFileName.contains("install") || lowerFileName.contains("setup") ||
           lowerFileName.contains("app") || lowerFileName.contains("bundle") {
            // Installers go to Documents/General
            return "Documents"
        }
        
        // Default: archives go to Documents/General
        return "Documents"
    }
}