//
//  ClassificationPromptBuilder.swift
//  File Classification System
//
//  Builds optimized prompts for LLM-based file classification
//  with A/B testing support for prompt variations.
//

import Foundation

// MARK: - Classification Prompt Builder

class ClassificationPromptBuilder {
    
    // MARK: - Properties
    
    var useExamples: Bool = true
    var promptVariant: PromptVariant = .standard
    
    // MARK: - Public Methods
    
    /// Build classification prompt for LLM
    func buildPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        switch promptVariant {
        case .standard:
            return buildStandardPrompt(metadata: metadata, preCategory: preCategory)
        case .concise:
            return buildConcisePrompt(metadata: metadata, preCategory: preCategory)
        case .detailed:
            return buildDetailedPrompt(metadata: metadata, preCategory: preCategory)
        case .chainOfThought:
            return buildChainOfThoughtPrompt(metadata: metadata, preCategory: preCategory)
        }
    }
    
    // MARK: - Standard Prompt (Default)
    
    private func buildStandardPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        var prompt = ""
        
        // System context with strict JSON formatting requirements
        prompt += """
        You are a file classification system. Analyze the file and return a classification.
        
        CRITICAL: Your response MUST be ONLY a JSON object. No markdown, no code blocks, no explanation before or after.
        
        BAD: ```json
        {"category": "Media"}
        ```
        
        GOOD: {"category": "Media", "subfolder": "Photos", "confidence": 0.95, "reasoning": "webp extension indicates image file"}
        
        """
        
        // Classification rules
        prompt += buildClassificationRules()
        
        // Valid subfolders
        let validSubfolders = ClassificationConstants.getValidSubfolders(for: preCategory)
        prompt += """
        VALID SUBFOLDERS:
        \(formatValidSubfolders(validSubfolders))
        
        """
        
        // Few-shot examples (if enabled)
        if useExamples {
            prompt += buildExamples()
        }
        
        // File information section
        prompt += buildFileInformation(metadata: metadata, preCategory: preCategory)
        
        // Output format specification
        prompt += buildOutputFormat(preCategory: preCategory, fileExtension: metadata.fileExtension)
        
        return prompt
    }
    
    // MARK: - Concise Prompt Variant
    
    private func buildConcisePrompt(metadata: FileMetadata, preCategory: String?) -> String {
        var prompt = """
        Classify this file. Return ONLY valid JSON.
        
        Extension → Category:
        Images (.webp, .jpg, .png) → Media
        Videos (.mp4, .mov) → Media
        Audio (.mp3, .wav) → Media
        3D (.stl, .obj) → Projects
        Code (.swift, .js, .py) → Projects
        Docs (.pdf, .doc) → Documents
        Archives (.zip, .rar) → Archive
        
        """
        
        if let preCategory = preCategory {
            let subfolders = ClassificationConstants.validSubfolders[preCategory] ?? ["General"]
            prompt += "\nCategory: \(preCategory). Choose subfolder from: \(subfolders.joined(separator: ", "))\n"
        }
        
        prompt += """
        
        File: \(metadata.fileName)
        Extension: .\(metadata.fileExtension)
        
        Return: {"category": "X", "subfolder": "Y", "confidence": 0.X, "reasoning": "brief"}
        """
        
        return prompt
    }
    
    // MARK: - Detailed Prompt Variant
    
    private func buildDetailedPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        var prompt = buildStandardPrompt(metadata: metadata, preCategory: preCategory)
        
        // Add extra context and analysis guidance
        prompt += """
        
        ADDITIONAL ANALYSIS GUIDELINES:
        
        1. Context Clues:
           • Consider filename patterns (e.g., "invoice_2024" suggests Documents/Invoices)
           • Check for version numbers or dates in filename
           • Look for industry-specific terminology
        
        2. Disambiguation Strategy:
           • If ambiguous, prefer more specific subfolders
           • For archives, check filename for content hints (e.g., "assets.zip" → Projects)
           • For PDFs, prioritize filename keywords over generic classification
        
        3. Confidence Assessment:
           • High (0.9+): Clear extension + matching filename pattern
           • Medium (0.7-0.9): Clear extension, generic filename
           • Low (0.5-0.7): Ambiguous extension or conflicting signals
        
        """
        
        return prompt
    }
    
    // MARK: - Chain of Thought Prompt Variant
    
    private func buildChainOfThoughtPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        var prompt = """
        You are a file classification system. Think step-by-step to classify this file.
        
        PROCESS:
        1. Analyze the file extension
        2. Check filename for keywords and patterns
        3. Determine category based on extension rules
        4. Select most appropriate subfolder
        5. Assess confidence based on signal strength
        
        """
        
        prompt += buildClassificationRules()
        
        let validSubfolders = ClassificationConstants.getValidSubfolders(for: preCategory)
        prompt += """
        
        VALID SUBFOLDERS:
        \(formatValidSubfolders(validSubfolders))
        
        """
        
        prompt += buildFileInformation(metadata: metadata, preCategory: preCategory)
        
        prompt += """
        
        Think through the classification step-by-step, then provide your final answer in JSON format:
        
        {"category": "X", "subfolder": "Y", "confidence": 0.X, "reasoning": "Step 1: extension is .X which indicates... Step 2: filename contains... Therefore: Category/Subfolder"}
        
        Remember: Return ONLY the JSON object in your final response.
        """
        
        return prompt
    }
    
    // MARK: - Shared Prompt Components
    
    private func buildClassificationRules() -> String {
        return """
        CLASSIFICATION RULES (in priority order):
        
        1. EXTENSION DETERMINES CATEGORY (highest priority):
           • Images (.webp, .jpg, .jpeg, .png, .gif, .svg, .heic, .bmp) → Media
           • Videos (.mp4, .mov, .avi, .mkv, .webm, .flv) → Media
           • Audio (.mp3, .wav, .aac, .flac, .m4a, .ogg) → Media
           • 3D Models (.stl, .obj, .fbx, .blend, .3ds, .dae) → Projects
           • Code (.swift, .js, .py, .java, .cpp, .c, .sh, .bat, .html, .css, .go, .rs) → Projects
           • Presentations (.ppt, .pptx, .key, .odp) → Documents
           • Spreadsheets (.xlsx, .xls, .csv, .numbers, .ods) → Documents
           • Documents (.pdf, .doc, .docx, .txt, .md, .rtf, .pages) → Documents
           • Archives (.zip, .rar, .7z, .tar, .gz, .bz2) → Archive
           • Installers (.dmg, .pkg, .exe, .msi, .app, .deb, .rpm) → Archive
        
        2. FILENAME PATTERNS (for subfolder selection):
           • "invoice", "bill" → Documents/Invoices
           • "receipt" → Documents/Receipts
           • "report", "analysis" → Documents/Reports
           • "screenshot", "screen" → Media/Screenshots
           • "vector", "logo", "icon", "design" → Projects/Assets or Projects/Design
           • "backup", "archive" → Archive/Backups
           • "presentation", "slides" → Documents/Presentations
        
        3. SUBFOLDER SELECTION:
           Choose ONE word from the valid subfolders below.
           Be specific but not overly granular.
           NEVER use the filename itself as a subfolder.
           NEVER create nested paths (e.g., "Photos/Vacation" is invalid).
        
        """
    }
    
    private func buildExamples() -> String {
        return """
        EXAMPLES:
        
        Input: vacation.webp
        Output: {"category": "Media", "subfolder": "Photos", "confidence": 0.95, "reasoning": "extension=webp → Media/Photos per rule #1"}
        
        Input: invoice_2024.pdf
        Output: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.92, "reasoning": "extension=pdf + filename contains 'invoice' → Documents/Invoices"}
        
        Input: model.stl
        Output: {"category": "Projects", "subfolder": "3D", "confidence": 0.95, "reasoning": "extension=stl → Projects/3D per rule #1"}
        
        Input: logo_vectors.zip
        Output: {"category": "Projects", "subfolder": "Assets", "confidence": 0.88, "reasoning": "extension=zip but filename contains 'vector' → Projects/Assets per rule #2"}
        
        Input: presentation.pptx
        Output: {"category": "Documents", "subfolder": "Presentations", "confidence": 0.95, "reasoning": "extension=pptx → Documents/Presentations per rule #1"}
        
        Input: script.sh
        Output: {"category": "Projects", "subfolder": "Code", "confidence": 0.95, "reasoning": "extension=sh → Projects/Code per rule #1"}
        
        """
    }
    
    private func buildFileInformation(metadata: FileMetadata, preCategory: String?) -> String {
        var info = """
        FILE TO CLASSIFY:
        """
        
        // Category constraint if pre-determined
        if let preCategory = preCategory {
            info += """
            
            ⚠️  CONSTRAINT: Category is FIXED as '\(preCategory)' (based on .\(metadata.fileExtension) extension)
            Your task: Choose the best subfolder from the valid \(preCategory) subfolders listed above.
            
            """
        }
        
        info += """
        
        • Filename: \(metadata.fileName)
        • Extension: .\(metadata.fileExtension)
        • Size: \(metadata.fileSizeFormatted)
        """
        
        // Add contextual hints
        info += buildContextualHints(metadata: metadata, preCategory: preCategory)
        
        return info
    }
    
    private func buildOutputFormat(preCategory: String?, fileExtension: String) -> String {
        return """
        
        OUTPUT FORMAT:
        Return ONLY this JSON structure (no markdown, no extra text):
        
        {
            "category": "\(preCategory ?? "category_name")",
            "subfolder": "single_word_from_valid_list",
            "confidence": 0.XX,
            "reasoning": "extension=.\(fileExtension) + [filename_pattern] → Category/Subfolder per rule #N"
        }
        
        CONFIDENCE CALIBRATION:
        • 0.95-1.00: Extension directly determines both category and subfolder
        • 0.85-0.94: Extension determines category, filename strongly suggests subfolder
        • 0.70-0.84: Extension determines category, subfolder chosen by keyword match
        • 0.50-0.69: Ambiguous case, subfolder is best guess
        
        VALIDATION CHECKLIST:
        ✓ Category is one of: Media, Projects, Documents, Archive
        ✓ Subfolder is from the valid list (no custom names)
        ✓ Subfolder is ONE word (no slashes, no spaces)
        ✓ Confidence is between 0.0 and 1.0
        ✓ Response is ONLY JSON (no markdown blocks)
        
        Now classify the file:
        """
    }
    
    private func buildContextualHints(metadata: FileMetadata, preCategory: String?) -> String {
        var hints = ""
        let fileName = metadata.fileName.lowercased()
        
        // Only add hints if they're relevant for subfolder determination
        if preCategory != nil {
            // Specific filename patterns
            if fileName.contains("invoice") || fileName.contains("bill") {
                hints += "\n• Hint: Filename suggests 'Invoices' subfolder"
            } else if fileName.contains("receipt") {
                hints += "\n• Hint: Filename suggests 'Receipts' subfolder"
            } else if fileName.contains("report") || fileName.contains("analysis") {
                hints += "\n• Hint: Filename suggests 'Reports' subfolder"
            } else if fileName.contains("screenshot") || fileName.contains("screen") {
                hints += "\n• Hint: Filename suggests 'Screenshots' subfolder"
            } else if fileName.contains("vector") || fileName.contains("logo") || fileName.contains("icon") {
                hints += "\n• Hint: Filename suggests 'Assets' or 'Design' subfolder"
            } else if fileName.contains("backup") {
                hints += "\n• Hint: Filename suggests 'Backups' subfolder"
            } else if fileName.contains("presentation") || fileName.contains("slides") {
                hints += "\n• Hint: Filename suggests 'Presentations' subfolder"
            }
        }
        
        // Add keywords if available (limited to top 3 most relevant)
        if let keywords = metadata.keywords, !keywords.isEmpty {
            let topKeywords = keywords.prefix(3).joined(separator: ", ")
            hints += "\n• Keywords: \(topKeywords)"
        }
        
        // Add creation/modification date if recent
        if let modDate = metadata.modificationDate {
            let daysSinceModification = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
            if daysSinceModification < 7 {
                hints += "\n• Modified: \(daysSinceModification) days ago (recent file)"
            }
        }
        
        return hints
    }
    
    private func formatValidSubfolders(_ subfolders: [String: [String]]) -> String {
        return subfolders.map { category, folders in
            "• \(category): \(folders.joined(separator: ", "))"
        }.joined(separator: "\n")
    }
}

// MARK: - Prompt Variant

enum PromptVariant: String, CaseIterable {
    case standard = "standard"
    case concise = "concise"
    case detailed = "detailed"
    case chainOfThought = "chain_of_thought"
    
    var description: String {
        switch self {
        case .standard:
            return "Standard prompt with balanced detail"
        case .concise:
            return "Minimal prompt for faster responses"
        case .detailed:
            return "Comprehensive prompt with extra guidance"
        case .chainOfThought:
            return "Encourages step-by-step reasoning"
        }
    }
}