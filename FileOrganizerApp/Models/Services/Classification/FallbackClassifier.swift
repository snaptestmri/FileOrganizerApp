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
    
    /// Classify a file using deterministic rules
    func classify(_ metadata: FileMetadata) -> ClassificationResult {
        // Determine category from extension
        let category = determineCategoryFromExtension(metadata.fileExtension)
        
        // Determine subfolder based on category and filename
        let subfolder = determineSubfolder(
            category: category,
            fileName: metadata.fileName,
            fileExtension: metadata.fileExtension
        )
        
        // Calculate confidence based on how certain we are
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
            reasoning: reasoning ?? "Fallback classification",
            method: .fallback
        )
    }
    
    /// Determine category from file extension only
    func determineCategoryFromExtension(_ fileExtension: String) -> String {
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
        
        // Code extensions
        if ClassificationConstants.codeExtensions.contains(ext) {
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
        
        // Archive extensions
        if ClassificationConstants.archiveExtensions.contains(ext) {
            return "Archive"
        }
        
        // Installer extensions
        if ClassificationConstants.installerExtensions.contains(ext) {
            return "Archive"
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
            
        case "Archive":
            return determineArchiveSubfolder(fileName: lowerFileName, fileExtension: ext)
            
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
    
    private func determineArchiveSubfolder(fileName: String, fileExtension: String) -> String {
        // Check for backups
        if fileName.contains("backup") || fileName.contains("bak") || 
           fileName.contains("old") || fileName.contains("archive") {
            return "Backups"
        }
        
        // Check extension type
        if ClassificationConstants.installerExtensions.contains(fileExtension) {
            return "Installers"
        }
        
        return "Compressed" // Default for Archive
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
                   ClassificationConstants.documentExtensions.contains(fileExtension)
        case "Archive":
            return ClassificationConstants.archiveExtensions.contains(fileExtension) ||
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
            "Backups": ["backup", "bak", "old", "archive"],
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