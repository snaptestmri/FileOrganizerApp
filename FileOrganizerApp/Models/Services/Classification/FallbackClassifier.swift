//
//  FallbackClassifier.swift
//  File Classification System
//
//  Rule-based fallback classifier for when LLM classification fails.
//  Uses deterministic rules based on file extensions and filename patterns.
//

import Foundation

// MARK: - Fallback Classifier

class FallbackClassifier {

    // MARK: - Public Methods

    /// Classify a file using deterministic rules.
    /// Pass the classification mode to select the appropriate taxonomy.
    func classify(_ metadata: FileMetadata,
                  mode: ClassificationMode = .standard) -> ClassificationResult {
        switch mode {
        case .standard:
            return classifyStandard(metadata)
        case .personalDomain:
            return classifyPersonalDomain(metadata)
        }
    }

    // MARK: - Standard Mode

    /// Standard classification: file type → Media / Projects / Documents.
    func classifyStandard(_ metadata: FileMetadata) -> ClassificationResult {
        let category = determineCategoryFromExtension(metadata.fileExtension, fileName: metadata.fileName)
        let subfolder = determineSubfolder(
            category: category,
            fileName: metadata.fileName,
            fileExtension: metadata.fileExtension
        )
        let confidence = calculateConfidence(
            category: category,
            subfolder: subfolder,
            fileName: metadata.fileName,
            fileExtension: metadata.fileExtension
        )
        let reasoning = buildReasoning(
            category: category,
            subfolder: subfolder,
            fileExtension: metadata.fileExtension,
            fileName: metadata.fileName
        )
        return ClassificationResult(
            category: category,
            subfolder: subfolder,
            confidence: confidence,
            reasoning: reasoning,
            method: .fallback
        )
    }

    // MARK: - Personal Domain Mode
    //
    // Priority chain (matches the methodology description):
    //   1. Project directory signal  → Projects/Apps or Projects/Experiments
    //   2. Temporal name signal      → Media/Screenshots or Media/Photos
    //   3. Detected intent (pre-computed from filename + folder context)
    //   4. Extension as last resort  → Media or Projects for unambiguous types only

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

        // --- Rule 3: Intent-based routing ---
        if let intent = metadata.detectedIntent {
            reasoning.append("detected intent: \(intent)")
            if let (category, subfolder, conf) = intentToPersonalDomain(intent) {
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

        // --- Rule 4: Extension for unambiguous types (Media, code) ---
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

        // --- Default: ambiguous document ---
        return ClassificationResult(
            category: "Personal",
            subfolder: "General",
            confidence: 0.45,
            reasoning: "no intent or extension signal; default personal",
            method: .fallback
        )
    }

    /// Maps a pre-detected intent string to a personal domain category, subfolder, and confidence.
    private func intentToPersonalDomain(_ intent: String) -> (category: String, subfolder: String, confidence: Double)? {
        switch intent {
        // Career
        case "job_prep":          return ("Career", "Job Prep",           0.92)
        case "resume":            return ("Career", "Resumes",            0.95)
        case "cover_letter":      return ("Career", "Cover Letters",      0.95)
        case "performance_review":return ("Career", "Performance Reviews",0.93)
        case "offer_letter":      return ("Career", "Work",               0.90)
        case "payroll":           return ("Career", "Work",               0.88)
        case "certification":     return ("Career", "Certifications",     0.90)
        // Finance
        case "tax":               return ("Finance", "Taxes",             0.95)
        case "bank_statement":    return ("Finance", "Bank Statements",   0.92)
        case "invoice":           return ("Finance", "Bills",             0.90)
        case "receipt":           return ("Finance", "Receipts",          0.90)
        case "investment":        return ("Finance", "Investments",       0.92)
        // Legal
        case "immigration":       return ("Legal",   "Immigration",       0.95)
        case "probate":           return ("Legal",   "Probate",           0.95)
        case "court_case":        return ("Legal",   "Court Cases",       0.90)
        case "evidence":          return ("Legal",   "Evidence",          0.88)
        case "contract":          return ("Legal",   "Contracts",         0.85)
        // Personal
        case "health":            return ("Personal","Health",            0.92)
        case "insurance":         return ("Personal","Insurance",         0.92)
        case "identity":          return ("Personal","Identity",          0.95)
        case "rent":              return ("Personal","Rent",              0.90)
        case "travel":            return ("Personal","General",           0.82)
        // Learning (under Career)
        case "university":        return ("Career", "University",        0.90)
        case "course":            return ("Career", "PM Courses",        0.88)
        case "book":              return ("Career", "Books",             0.85)
        case "notes":             return ("Career", "Notes",             0.85)
        // Media (temporal handled earlier, but catch-all)
        case "screenshot_or_photo": return ("Media", "Screenshots",      0.90)
        case "video":             return ("Media",   "Videos",            0.90)
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
    
    private func determineSubfolder(category: String, fileName: String, fileExtension: String) -> String {
        let lowerFileName = fileName.lowercased()
        let ext = fileExtension.lowercased()
        
        switch category {
        case "Media":
            return determineMediaSubfolder(fileName: lowerFileName, fileExtension: ext)
            
        case "Projects":
            return determineProjectsSubfolder(fileName: lowerFileName, fileExtension: ext)
            
        case "Documents":
            return determineDocumentsSubfolder(fileName: lowerFileName, fileExtension: ext)
            
        default:
            return "General"
        }
    }
    
    private func determineMediaSubfolder(fileName: String, fileExtension: String) -> String {
        // Check for screenshots
        if fileName.contains("screenshot") || fileName.contains("screen shot") || 
           fileName.hasPrefix("screen ") || fileName.hasPrefix("screenshot") {
            return "Screenshots"
        }
        
        // Check extension type
        if ClassificationConstants.imageExtensions.contains(fileExtension) {
            return "Photos"
        } else if ClassificationConstants.videoExtensions.contains(fileExtension) {
            return "Videos"
        } else if ClassificationConstants.audioExtensions.contains(fileExtension) {
            return "Audio"
        }
        
        return "Photos" // Default for Media
    }
    
    private func determineProjectsSubfolder(fileName: String, fileExtension: String) -> String {
        // Check for design assets
        if fileName.contains("vector") || fileName.contains("logo") || 
           fileName.contains("icon") || fileName.contains("asset") {
            return "Assets"
        }
        
        // Check for design files
        if fileName.contains("design") || fileName.contains("mockup") {
            return "Design"
        }
        
        // Check extension type
        if ClassificationConstants.modelExtensions.contains(fileExtension) {
            return "3D"
        } else if ClassificationConstants.codeExtensions.contains(fileExtension) {
            return "Code"
        } else if ClassificationConstants.webExtensions.contains(fileExtension) {
            return "Web"
        }
        
        return "Code" // Default for Projects
    }
    
    private func determineDocumentsSubfolder(fileName: String, fileExtension: String) -> String {
        // Check for specific document types
        if fileName.contains("invoice") || fileName.contains("bill") {
            return "Invoices"
        }
        
        if fileName.contains("receipt") {
            return "Receipts"
        }
        
        if fileName.contains("report") || fileName.contains("analysis") {
            return "Reports"
        }
        
        if fileName.contains("financial") || fileName.contains("statement") || 
           fileName.contains("tax") || fileName.contains("expense") {
            return "Financial"
        }
        
        if fileName.contains("personal") || fileName.contains("private") {
            return "Personal"
        }
        
        // Check extension type
        if ClassificationConstants.presentationExtensions.contains(fileExtension) {
            return "Presentations"
        }
        
        return "General" // Default for Documents
    }
    
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
    
    private func calculateConfidence(category: String, subfolder: String, fileName: String, fileExtension: String) -> Double {
        let ext = fileExtension.lowercased()
        let lowerFileName = fileName.lowercased()
        
        // High confidence if extension directly maps to category and subfolder
        let hasStrongExtensionMatch = isStrongExtensionMatch(fileExtension: ext, category: category)
        let hasFilenameHint = hasRelevantFilenamePattern(fileName: lowerFileName, subfolder: subfolder)
        
        if hasStrongExtensionMatch && hasFilenameHint {
            return 0.92 // Very high confidence
        } else if hasStrongExtensionMatch {
            return 0.85 // High confidence based on extension alone
        } else if hasFilenameHint {
            return 0.75 // Moderate confidence based on filename
        } else {
            return 0.65 // Lower confidence, generic classification
        }
    }
    
    private func isStrongExtensionMatch(fileExtension: String, category: String) -> Bool {
        switch category {
        case "Media":
            return ClassificationConstants.imageExtensions.contains(fileExtension) ||
                   ClassificationConstants.videoExtensions.contains(fileExtension) ||
                   ClassificationConstants.audioExtensions.contains(fileExtension)
        case "Projects":
            return ClassificationConstants.modelExtensions.contains(fileExtension) ||
                   ClassificationConstants.codeExtensions.contains(fileExtension)
        case "Documents":
            return ClassificationConstants.presentationExtensions.contains(fileExtension) ||
                   ClassificationConstants.spreadsheetExtensions.contains(fileExtension) ||
                   ClassificationConstants.documentExtensions.contains(fileExtension) ||
                   ClassificationConstants.archiveExtensions.contains(fileExtension) ||
                   ClassificationConstants.installerExtensions.contains(fileExtension)
        default:
            return false
        }
    }
    
    private func hasRelevantFilenamePattern(fileName: String, subfolder: String) -> Bool {
        let patterns: [String: [String]] = [
            "Screenshots": ["screenshot", "screen shot", "screen "],
            "Invoices": ["invoice", "bill"],
            "Receipts": ["receipt"],
            "Reports": ["report", "analysis"],
            "Financial": ["financial", "statement", "tax", "expense"],
            "Assets": ["vector", "logo", "icon", "asset"],
            "Design": ["design", "mockup"],
            "3D": ["model", "3d"],
            "Presentations": ["presentation", "slides", "deck"]
        ]
        
        guard let keywords = patterns[subfolder] else {
            return false
        }
        
        return keywords.contains { fileName.contains($0) }
    }
    
    private func buildReasoning(category: String, subfolder: String, fileExtension: String, fileName: String) -> String {
        var reasoning = "Fallback classification: "
        
        reasoning += "extension=.\(fileExtension) → \(category)"
        
        if hasRelevantFilenamePattern(fileName: fileName.lowercased(), subfolder: subfolder) {
            reasoning += " + filename pattern → \(subfolder)"
        } else {
            reasoning += " → default subfolder \(subfolder)"
        }
        
        return reasoning
    }
}