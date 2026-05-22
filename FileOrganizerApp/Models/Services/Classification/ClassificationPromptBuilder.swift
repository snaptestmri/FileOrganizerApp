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
    /// Set to .personalDomain to activate the life-domain taxonomy instead of
    /// the standard Media / Projects / Documents taxonomy.
    var classificationMode: ClassificationMode = .standard
    /// Primary user context for personal-domain prompts (optional).
    var userProfile: UserProfile?
    var knownPeople: [KnownPerson] = []

    // MARK: - Public Methods

    /// Build classification prompt for LLM.
    /// When classificationMode is .personalDomain the personal domain prompt is
    /// used regardless of promptVariant — the two axes are independent.
    func buildPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        if classificationMode == .personalDomain {
            return buildPersonalDomainPrompt(metadata: metadata)
        }
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

    // MARK: - Personal Domain Prompt

    private func buildPersonalDomainPrompt(metadata: FileMetadata) -> String {
        let validSubfolders = ClassificationConstants.personalDomainSubfolders
        let profileSection = formatUserProfileSection()

        let prompt = """
        You are a personal file organiser. Your job is to classify a file into the
        correct life-domain category and subfolder for a personal home folder.

        CRITICAL: Return ONLY a JSON object. No markdown, no code blocks, no explanation.

        \(profileSection)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        TAXONOMY  (you MUST use exactly these names)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        \(formatPersonalSubfolders(validSubfolders))

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        CLASSIFICATION PRINCIPLES  (in priority order)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        1. INTENT OVER NAME
           Ask: what is this file *for*, not what is it called?
           "GeicoVehiclePolicy.pdf" → Personal/Insurance  (not Documents/General)
           "2021_Avaya_Year_End_Performance.pdf" → Career/Performance Reviews
           The file format (.pdf, .docx) does NOT determine the category.

        2. LIFE DOMAIN ROUTING  (use content or filename keywords, whichever is clearer)
           • Career — all job and learning material (there is NO separate Education category):
             - Resumes: actual CV only (not guides about resumes)
             - Job Prep: interview prep, homework, career/PM guides and ladders
             - Work: offer letters, reference letters, employment documents
             - PM Courses: cohort slides, prompt-engineering labs, product-school coursework
             - University: transcripts, admissions, scholarships, degrees
             - Books: ebooks, textbooks, "how to become a PM" reading
             - Notes: lecture notes, study guides
           • Finance:   bank statement, tax (1099/W-2/1040/K-1), invoice, bill, investment, receipt, Remitly
           • Legal:     visa, I-94, passport, probate, estate, court, contract, lease, evidence of funds
           • Personal:  health/medical, insurance policy, government ID, driving licence, rent/apartment
           • Media:     photos (IMG_, PXL_), videos, audio, screenshots, app UI mockups
           • Projects:  directory with Package.swift / package.json / Dockerfile / Makefile etc.

        3. TEMPORAL NAME SIGNAL
           ONLY when the filename STARTS WITH "Screenshot", "Screen Shot", "IMG_", or "PXL_"
           (or hasTemporalName is true in metadata).
           ISO timestamps in names (e.g. file_2026-01-10T05-24-02Z.docx) are NOT screenshots.
           → Media/Screenshots or Media/Photos only for real screenshot/photo exports.

        4. PROJECT DIRECTORY SIGNAL
           ONLY when isProjectDirectory is true in metadata (sibling has Package.swift, package.json, etc.).
           A lone .zip, .dmg, or .jar in Downloads is NOT a project — use Finance/Legal/Personal intent instead.
           .sublime-package / .vsix → Projects/Code, NOT Projects/Apps.

        4b. CODE / STYLESHEET FILES
           .css, .scss, .js, .html, .swift, .py, etc. are source code → Projects/Code.
           Never use Media or invent subfolders like "CSS" — only taxonomy names listed above.
           "Filename structure hints" in metadata are NOT valid subfolder names.

        5. DETECTED INTENT (pre-computed hint — trust it unless content contradicts)
           If detectedIntent is provided, use it as the primary routing signal.
           job_prep → Career/Job Prep | resume → Career/Resumes | course → Career/PM Courses
           | university → Career/University | book → Career/Books
           Do not override job_prep with Resumes just because content mentions the word "resume".
           Never use category "Education" — use Career with the subfolders above.

        6. CONTENT OVER FILENAME
           When a content preview is available, it can refine ambiguous filenames.
           A file named "document.pdf" with tax-form content → Finance/Taxes.
           A file named "report.pdf" with performance-review content → Career/Performance Reviews.
           Exception: interview/homework/career-guide/PM-ladder filenames stay Career/Job Prep even if preview mentions "resume".

        7. WHEN IN DOUBT
           Use Personal/General rather than inventing a new subfolder.
           NEVER create subfolder names not in the taxonomy above.

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        EXAMPLES
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "GeicoVehiclePolicy.pdf" → {"category":"Personal","subfolder":"Insurance","confidence":0.95,"reasoning":"insurance keyword in filename → Personal/Insurance"}
        "2021_Avaya_Year_End_Performance_Plan.pdf" → {"category":"Career","subfolder":"Performance Reviews","confidence":0.93,"reasoning":"year end + performance keywords → Career/Performance Reviews"}
        "Screenshot 2025-03-11 at 10.40.18 PM.png" → {"category":"Media","subfolder":"Screenshots","confidence":0.97,"reasoning":"temporal prefix 'Screenshot' → Media/Screenshots"}
        "IMG_2344.HEIC" → {"category":"Media","subfolder":"Photos","confidence":0.96,"reasoning":"temporal prefix 'IMG_' → Media/Photos"}
        "Taxes2025.pdf" → {"category":"Finance","subfolder":"Taxes","confidence":0.95,"reasoning":"'taxes' keyword → Finance/Taxes"}
        "MS_2025_1099-CONS_MSSB_LLC.pdf" → {"category":"Finance","subfolder":"Taxes","confidence":0.94,"reasoning":"1099 form → Finance/Taxes"}
        "MrinalThigale-Resume.docx" → {"category":"Career","subfolder":"Resumes","confidence":0.97,"reasoning":"filename is an actual CV → Career/Resumes"}
        "The Ultimate Guide_ Interview Homework - by Aakash Gupta.pdf" → {"category":"Career","subfolder":"Job Prep","confidence":0.92,"reasoning":"interview + homework → Career/Job Prep"}
        "The PM Career Ladder_ Your Unofficial Guide.pdf" → {"category":"Career","subfolder":"Job Prep","confidence":0.93,"reasoning":"PM + career guide/ladder → Career/Job Prep (not Resumes)"}
        "Aadhaar-Mrinal.pdf" → {"category":"Personal","subfolder":"Identity","confidence":0.95,"reasoning":"aadhaar in filename → Personal/Identity"}
        "Avaya Reference Letter 2016-2023.docx" → {"category":"Career","subfolder":"Work","confidence":0.90,"reasoning":"reference letter → Career/Work (NOT Identity)"}
        "eStmt_2024-06-05.pdf" → {"category":"Finance","subfolder":"Bank Statements","confidence":0.92,"reasoning":"eStmt prefix → Finance/Bank Statements (not Taxes)"}
        "Pay Date 2024-07-19.pdf" → {"category":"Finance","subfolder":"Bank Statements","confidence":0.92,"reasoning":"pay date in filename → Finance/Bank Statements"}
        "lucy.css" → {"category":"Projects","subfolder":"Code","confidence":0.90,"reasoning":"stylesheet → Projects/Code (never Media/CSS)"}
        "deep-research-report.md" → {"category":"Personal","subfolder":"General","confidence":0.55,"reasoning":"no clear life-domain signal; default Personal/General"}
        "StoryForge/ (isProjectDirectory=true)" → {"category":"Projects","subfolder":"Apps","confidence":0.95,"reasoning":"isProjectDirectory=true → Projects/Apps"}
        "GitHubDesktop-arm64.zip" → {"category":"Projects","subfolder":"Scaffold","confidence":0.75,"reasoning":"installer archive, no project siblings → Projects/Scaffold"}
        "Intro to Prompt Engineering_2026-01-10.docx" → {"category":"Career","subfolder":"PM Courses","confidence":0.90,"reasoning":"cohort/coursework → Career/PM Courses"}
        "How to Become a Product Manager Without Experience.pdf" → {"category":"Career","subfolder":"Books","confidence":0.88,"reasoning":"career learning book → Career/Books"}

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        FILE TO CLASSIFY
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        \(metadata.toDescription())

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        OUTPUT FORMAT
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Return ONLY this JSON (no markdown, no extra text):
        {"category": "X", "subfolder": "Y", "confidence": 0.XX, "reasoning": "signal used → Category/Subfolder"}

        CONFIDENCE GUIDE:
        0.90–1.00 → intent signal AND content/filename agree
        0.80–0.89 → clear intent signal, filename is generic
        0.70–0.79 → content contradicts filename; trusted content
        0.50–0.69 → ambiguous; best guess applied
        < 0.50    → very uncertain; Personal/General used

        VALIDATION (must pass ALL):
        ✓ category is one of: Career, Finance, Legal, Personal, Media, Projects
        ✓ subfolder is exactly one of the names in the taxonomy above for that category
        ✓ subfolder contains no slashes or path separators
        ✓ confidence is 0.0–1.0
        ✓ response is ONLY the JSON object

        Now classify:
        """

        return prompt
    }

    private func formatUserProfileSection() -> String {
        guard var profile = userProfile, profile.hasIdentity else {
            return ""
        }
        profile.syncDerivedFields()
        var lines = [
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "PRIMARY USER (documents about this person = normal personal/career/finance paths)",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            ""
        ]
        lines.append("Name: \(profile.fullName)")
        if !profile.nameAliases.isEmpty {
            lines.append("Aliases: \(profile.nameAliases.joined(separator: ", "))")
        }
        if let region = profile.homeRegion, !region.isEmpty {
            lines.append("Default region: \(region) (do NOT add region to mental path unless file is for another jurisdiction)")
        }
        if !knownPeople.isEmpty {
            lines.append("Known other people (file is about them, not the primary user):")
            for person in knownPeople {
                lines.append("  • \(person.displayName) — tokens: \(person.matchTokens.joined(separator: ", "))")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func formatPersonalSubfolders(_ subfolders: [String: [String]]) -> String {
        let order = ["Career", "Finance", "Legal", "Personal", "Media", "Projects"]
        return order.compactMap { category -> String? in
            guard let folders = subfolders[category] else { return nil }
            return "  \(category): \(folders.joined(separator: ", "))"
        }.joined(separator: "\n")
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
        
        // Valid subfolders (show FIRST so LLM knows what's valid)
        let validSubfolders = ClassificationConstants.getValidSubfolders(for: preCategory)
        prompt += """
        ⚠️ VALID SUBFOLDERS (YOU CAN ONLY USE THESE - NO OTHER NAMES ALLOWED):
        \(formatValidSubfolders(validSubfolders))
        
        REMEMBER: You MUST choose a subfolder from the list above. If content suggests a document type not in the list, use "General" for Documents category.
        
        """
        
        // Classification rules
        prompt += buildClassificationRules()
        
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
        Archives (.zip, .rar) → Classify by content (Projects/Assets if design-related, Documents/General otherwise)
        
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
        
        1. CONTENT ANALYSIS FRAMEWORK (when content preview available):
           Step 1: Scan for document headers/titles
           Step 2: Identify key sections (e.g., "Invoice Details", "Summary", "Conclusion")
           Step 3: Extract keywords (see classification rules for keyword lists)
           Step 4: Look for structured data (tables, forms, lists)
           Step 5: Identify document purpose from content
           Step 6: Compare content purpose with filename/extension
           Step 7: Make final classification decision based on content (with confidence adjustment)
        
        2. Context Clues:
           • Consider filename patterns (e.g., "invoice_2024" suggests Documents/Invoices)
           • Check for version numbers or dates in filename
           • Look for industry-specific terminology
           • Use parent folder context (e.g., files in "Taxes" folder likely financial)
           • Consider sibling files (e.g., multiple invoices in same folder)
        
        3. Disambiguation Strategy:
           • If content available: Trust content over filename/extension
           • If ambiguous, prefer more specific subfolders
           • For archives, check filename for content hints (e.g., "assets.zip" → Projects/Assets, "code.zip" → Projects/Code, otherwise → Documents/General)
           • For PDFs without content preview, prioritize filename keywords over generic classification
        
        4. Confidence Assessment:
           • High (0.9+): Content clearly indicates purpose AND filename/extension agrees
           • Medium (0.7-0.9): Content indicates purpose but filename is generic, OR clear extension + matching filename (no content)
           • Low (0.5-0.7): Ambiguous content, conflicting signals, or unclear purpose
        
        5. Conflict Resolution:
           • Content vs Filename conflict → Trust CONTENT, lower confidence
           • Content vs Extension conflict → Trust CONTENT (extension may be generic like .pdf)
           • Filename vs Extension conflict → Trust EXTENSION (extension is more reliable)
        
        """
        
        return prompt
    }
    
    // MARK: - Chain of Thought Prompt Variant
    
    private func buildChainOfThoughtPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        var prompt = """
        You are a file classification system. Think step-by-step to classify this file.
        
        CLASSIFICATION PROCESS (follow these steps in order):
        
        STEP 1: Check if content preview is available
        • If YES → Proceed to Step 2 (Content Analysis)
        • If NO → Skip to Step 4 (Extension Analysis)
        
        STEP 2: Content Analysis (if content preview available)
        • Read the content preview carefully
        • Identify document type from headers, structure, keywords
        • Extract key terms (invoice, report, receipt, statement, etc.)
        • Determine document purpose from content
        • Note: Content takes priority over filename/extension
        
        STEP 3: Compare Content with Filename/Extension
        • Do they agree? → High confidence (0.9+)
        • Does content indicate purpose but filename is generic? → Medium-high confidence (0.8-0.9)
        • Do they conflict? → Trust content, lower confidence (0.7-0.8)
        
        STEP 4: Extension Analysis (if no content or to verify)
        • Check file extension (.pdf, .docx, .jpg, etc.)
        • Determine category from extension rules
        • Extension is reliable indicator of file type
        
        STEP 5: Filename Pattern Analysis
        • Check filename for keywords (invoice, receipt, report, etc.)
        • Look for patterns (dates, version numbers)
        • Use as supporting evidence, not primary indicator
        
        STEP 6: Context Analysis
        • Consider parent folder name
        • Consider sibling files
        • Use as additional hints
        
        STEP 7: Final Decision
        • If content available: Use content-based classification
        • If no content: Use extension + filename patterns
        • Select most appropriate subfolder from valid list
        • Set confidence based on signal strength and agreement
        
        """
        
        prompt += buildClassificationRules()
        
        let validSubfolders = ClassificationConstants.getValidSubfolders(for: preCategory)
        prompt += """
        
        VALID SUBFOLDERS:
        \(formatValidSubfolders(validSubfolders))
        
        """
        
        prompt += buildFileInformation(metadata: metadata, preCategory: preCategory)
        
        prompt += """
        
        Think through the classification step-by-step following the process above, then provide your final answer in JSON format:
        
        {"category": "X", "subfolder": "Y", "confidence": 0.X, "reasoning": "Step 1: [content check] Step 2: [content analysis if available] Step 3: [comparison] Step 4: [extension] Step 5: [filename] Step 6: [context] Step 7: [final decision] → Category/Subfolder"}
        
        Remember: Return ONLY the JSON object in your final response.
        """
        
        return prompt
    }
    
    // MARK: - Shared Prompt Components
    
    private func buildClassificationRules() -> String {
        return """
        CLASSIFICATION RULES (in priority order):
        
        ⚠️ CRITICAL: If content preview is provided, ANALYZE THE CONTENT FIRST to understand the file's actual purpose. Extension and filename are secondary clues.
        
        1. CONTENT ANALYSIS (highest priority when content preview is available):
           
           STEP-BY-STEP CONTENT ANALYSIS:
           a) Document Type Detection:
              • Look for document headers/titles (e.g., "Invoice", "Report", "Contract", "Statement")
              • Identify document structure (form fields, tables, sections)
              • Check for document-specific terminology
           
           b) Keyword Extraction:
              • INVOICES/BILLS: "invoice", "invoice number", "bill", "payment due", "amount due", "total", "balance", "pay to", "billing address", "item", "quantity", "price", "subtotal", "tax", "$" (dollar amounts)
              • RECEIPTS: "receipt", "transaction", "purchase", "merchant", "thank you for your purchase", "payment received", "order number"
              • FINANCIAL STATEMENTS: "statement", "account statement", "balance", "transactions", "deposits", "withdrawals", "account number"
              • REPORTS: "report", "analysis", "summary", "findings", "conclusion", "recommendations", "executive summary", "data analysis"
              • GRIEVANCES/COMPLAINTS: "grievance", "grievant", "complaint", "dispute", "violation", "bargaining unit", "union", "employee contract", "labor", "workplace", "disciplinary", "appeal"
              • LEGAL/CONTRACTS: "agreement", "contract", "terms", "party", "signature", "effective date", "whereas", "hereby", "legal", "attorney", "lawyer"
              • EMPLOYMENT DOCUMENTS: "employment", "job description", "performance review", "evaluation", "resume", "cv", "application", "offer letter"
              • PRESENTATIONS: "slide", "presentation", "agenda", "overview", "summary", "powerpoint", "keynote"
              • PERSONAL DOCUMENTS: "personal", "private", "confidential", "medical", "health", "insurance"
           
           c) Contextual Clues:
              • Dates: Invoice dates, due dates, statement periods
              • Numbers: Dollar amounts, invoice numbers, account numbers
              • Entities: Company names, person names, addresses
              • Purpose indicators: "Please pay", "Summary of", "This report", "Meeting notes"
           
           d) Content vs Filename/Extension:
              • If content clearly indicates purpose (e.g., invoice content) but filename is generic ("document.pdf"):
                → Classify based on CONTENT (e.g., Documents/Invoices)
              • If content and filename both suggest same purpose → High confidence (0.9+)
              • If content and filename conflict → Trust CONTENT, lower confidence (0.7-0.8)
           
           e) Mapping Content to Valid Subfolders (CHECK THE VALID SUBFOLDERS LIST ABOVE):
              
              DISTINGUISHING SIMILAR DOCUMENTS:
              
              • INVOICE vs GRIEVANCE:
                - Invoice: Contains "invoice number", "amount due", "payment", "$", "bill to", "itemized charges"
                - Grievance: Contains "grievance", "grievant", "complaint", "bargaining unit", "union", "violation", "appeal"
                - If you see "grievant" or "grievance" → Documents/General (NOT Invoices!)
              
              • INVOICE vs RECEIPT:
                - Invoice: "payment due", "amount due", "please pay", "bill to"
                - Receipt: "payment received", "thank you", "transaction complete", "order number"
              
              • FINANCIAL STATEMENT vs INVOICE:
                - Statement: "account statement", "period", "transactions", "balance forward"
                - Invoice: "invoice", "bill", "amount due", "pay by"
              
              • REPORT vs ANALYSIS:
                - Both → Documents/Reports
              
              MAPPING TO VALID SUBFOLDERS:
              • Invoice/Bill content → Documents/Invoices ✓ (valid)
              • Receipt content → Documents/Receipts ✓ (valid)
              • Financial statement/Account statement → Documents/Financial ✓ (valid)
              • Report/Analysis content → Documents/Reports ✓ (valid)
              • Presentation content → Documents/Presentations ✓ (valid)
              • Personal documents → Documents/Personal ✓ (valid)
              • Grievance/Complaint → Documents/General (NOT in valid list - grievance is NOT an invoice!)
              • Contract/Legal → Documents/General (NOT in valid list)
              • Employment documents (job descriptions, reviews) → Documents/Personal or Documents/General
              • Medical records → Documents/Personal
              • Tax documents → Documents/Tax ✓ (valid) or Documents/Financial
              • Bank statements → Documents/Financial
              • If content type doesn't match any valid subfolder → ALWAYS use "General"
              
              ⚠️ CRITICAL: Before choosing a subfolder, verify it exists in the VALID SUBFOLDERS list above!
              ⚠️ CRITICAL: "Grievance" is NOT the same as "Invoice" - use Documents/General for grievances!
           
           Examples:
           • "document.pdf" with invoice content → Documents/Invoices (content wins)
           • "statement.pdf" with financial statement → Documents/Financial (both agree, high confidence)
           • "report.pdf" with invoice content → Documents/Invoices (content wins over filename)
        
        2. EXTENSION DETERMINES CATEGORY (use when no content preview):
           • Images (.webp, .jpg, .jpeg, .png, .gif, .svg, .heic, .bmp) → Media
           • Videos (.mp4, .mov, .avi, .mkv, .webm, .flv) → Media
           • Audio (.mp3, .wav, .aac, .flac, .m4a, .ogg) → Media
           • 3D Models (.stl, .obj, .fbx, .blend, .3ds, .dae) → Projects
           • Code (.swift, .js, .py, .java, .cpp, .c, .sh, .bat, .html, .css, .go, .rs) → Projects
           • Presentations (.ppt, .pptx, .key, .odp) → Documents
           • Spreadsheets (.xlsx, .xls, .csv, .numbers, .ods) → Documents
           • Documents (.pdf, .doc, .docx, .txt, .md, .rtf, .pages) → Documents
           • Archives (.zip, .rar, .7z, .tar, .gz, .bz2) → Classify by filename content:
             - If filename suggests design/assets (vector, logo, icon, design) → Projects/Assets
             - If filename suggests code/project (code, source, project, dev) → Projects/Code
             - Otherwise → Documents/General
           • Installers (.dmg, .pkg, .exe, .msi, .app, .deb, .rpm) → Documents/General
        
        3. FILENAME PATTERNS (for subfolder selection when content is unclear):
           • "invoice", "bill" → Documents/Invoices
           • "receipt" → Documents/Receipts
           • "report", "analysis" → Documents/Reports
           • "screenshot", "screen" → Media/Screenshots
           • "vector", "logo", "icon", "design" → Projects/Assets or Projects/Design
           • "presentation", "slides" → Documents/Presentations
        
        4. SUBFOLDER SELECTION:
           ⚠️ CRITICAL: You MUST choose a subfolder from the VALID SUBFOLDERS list below.
           You CANNOT create new subfolder names - only use the ones provided in the list.
           
           • Choose ONE word from the valid subfolders below
           • Be specific but not overly granular
           • NEVER use the filename itself as a subfolder
           • NEVER create nested paths (e.g., "Photos/Vacation" is invalid)
           • NEVER invent new subfolder names
           
           ⚠️ FORBIDDEN SUBFOLDER NAMES (DO NOT USE THESE):
           ❌ "Grievance" → Use "General" instead
           ❌ "Contract" → Use "General" instead
           ❌ "Legal" → Use "General" instead
           ❌ "Medical" → Use "Personal" instead
           ❌ "Employment" → Use "Personal" or "General" instead
           ❌ "Tax" → Use "Tax" (this IS valid, but only if in the valid list)
           
           If content suggests a document type that doesn't have a matching subfolder:
           • Grievance/Complaint → Documents/General (NOT "Grievance" - that's invalid!)
           • Contract/Agreement → Documents/General (NOT "Contract" - that's invalid!)
           • Legal documents → Documents/General (NOT "Legal" - that's invalid!)
           • Medical records → Documents/Personal (NOT "Medical" - that's invalid!)
           • Tax documents → Documents/Tax (if "Tax" is in valid list) or Documents/Financial
           • Bank statements → Documents/Financial
           • Employment documents → Documents/Personal or Documents/General
        
        """
    }
    
    private func buildExamples() -> String {
        return """
        EXAMPLES:
        
        Example 1 - Extension-based (no content):
        Input: vacation.webp
        Output: {"category": "Media", "subfolder": "Photos", "confidence": 0.95, "reasoning": "extension=webp → Media/Photos per rule #2"}
        
        Example 2 - Filename + Extension:
        Input: invoice_2024.pdf
        Output: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.92, "reasoning": "extension=pdf + filename contains 'invoice' → Documents/Invoices per rule #3"}
        
        Example 3 - Content-based (content differs from filename):
        Input: document.pdf
        Content: "INVOICE #12345\nDate: 2024-01-15\nAmount Due: $1,250.00\n..."
        Output: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.90, "reasoning": "Content analysis: Contains invoice number, amount due, payment terms → Documents/Invoices (content overrides generic filename)"}
        
        Example 4 - Content confirms filename:
        Input: financial_statement.pdf
        Content: "FINANCIAL STATEMENT\nPeriod: Q4 2024\nTotal Assets: $500,000\n..."
        Output: {"category": "Documents", "subfolder": "Financial", "confidence": 0.95, "reasoning": "Content confirms filename: Contains financial data, statement period, asset values → Documents/Financial (high confidence, both agree)"}
        
        Example 5 - Content conflicts with filename:
        Input: report.pdf
        Content: "INVOICE\nInvoice #: INV-2024-001\nBill To: ABC Company\nAmount: $500.00\n..."
        Output: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.75, "reasoning": "Content analysis: Contains invoice details (invoice number, bill to, amount) → Documents/Invoices (content overrides filename 'report', lower confidence due to conflict)"}
        
        Example 6 - Extension-based (binary file):
        Input: model.stl
        Output: {"category": "Projects", "subfolder": "3D", "confidence": 0.95, "reasoning": "extension=stl → Projects/3D per rule #2"}
        
        Example 7 - Archive with design context:
        Input: logo_vectors.zip
        Output: {"category": "Projects", "subfolder": "Assets", "confidence": 0.88, "reasoning": "extension=zip but filename contains 'vector' → Projects/Assets per rule #3"}
        
        Example 8 - Presentation file:
        Input: presentation.pptx
        Output: {"category": "Documents", "subfolder": "Presentations", "confidence": 0.95, "reasoning": "extension=pptx → Documents/Presentations per rule #2"}
        
        Example 9 - Code file:
        Input: script.sh
        Output: {"category": "Projects", "subfolder": "Code", "confidence": 0.95, "reasoning": "extension=sh → Projects/Code per rule #2"}
        
        Example 10 - Receipt content analysis:
        Input: scan.pdf
        Content: "RECEIPT\nMerchant: Coffee Shop\nDate: 2024-01-15\nTotal: $4.50\nThank you for your purchase!"
        Output: {"category": "Documents", "subfolder": "Receipts", "confidence": 0.92, "reasoning": "Content analysis: Contains receipt keywords (merchant, purchase, total) → Documents/Receipts (content determines classification)"}
        
        Example 11 - Grievance document (NOT an invoice):
        Input: grievance.pdf
        Content: "EMPLOYEE GRIEVANCE\nGrievant: John Doe\nBargaining Unit: Local 123\nViolation: Contract Article 5\nAppeal Date: 2024-01-15"
        Output: {"category": "Documents", "subfolder": "General", "confidence": 0.85, "reasoning": "Content analysis: Contains grievance keywords (grievance, grievant, bargaining unit, violation) → Documents/General (grievance is NOT an invoice, no matching subfolder)"}
        
        Example 12 - Invoice vs Grievance distinction:
        Input: document.pdf
        Content: "INVOICE #12345\nBill To: ABC Company\nAmount Due: $1,250.00\nPayment Due: 2024-01-30"
        Output: {"category": "Documents", "subfolder": "Invoices", "confidence": 0.95, "reasoning": "Content analysis: Contains invoice keywords (invoice number, bill to, amount due, payment due) → Documents/Invoices"}
        
        Input: document.pdf
        Content: "GRIEVANCE FORM\nGrievant: Jane Smith\nDepartment: Engineering\nViolation: Article 8.2\nUnion: Local 456"
        Output: {"category": "Documents", "subfolder": "General", "confidence": 0.90, "reasoning": "Content analysis: Contains grievance keywords (grievance, grievant, violation, union) → Documents/General (NOT Invoices - grievance documents go to General)"}
        
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
        
        When CONTENT PREVIEW is available:
        • 0.90-1.00: Content clearly indicates purpose AND filename/extension agrees (e.g., invoice content + "invoice.pdf")
        • 0.80-0.89: Content clearly indicates purpose, filename is generic (e.g., invoice content + "document.pdf")
        • 0.70-0.79: Content suggests purpose but conflicts with filename (e.g., invoice content + "report.pdf")
        • 0.60-0.69: Content is ambiguous or unclear
        
        When NO CONTENT PREVIEW:
        • 0.95-1.00: Extension directly determines both category and subfolder
        • 0.85-0.94: Extension determines category, filename strongly suggests subfolder
        • 0.70-0.84: Extension determines category, subfolder chosen by keyword match
        • 0.50-0.69: Ambiguous case, subfolder is best guess
        
        VALIDATION CHECKLIST (MUST PASS ALL):
        ✓ Category is one of: Media, Projects, Documents
        ✓ Subfolder is EXACTLY one of the valid subfolders listed above (check the list!)
        ✓ Subfolder is ONE word (no slashes, no spaces, no hyphens)
        ✓ Subfolder matches the category (e.g., "Photos" only for Media, "Invoices" only for Documents)
        ✓ Confidence is between 0.0 and 1.0
        ✓ Response is ONLY JSON (no markdown blocks)
        
        ⚠️ COMMON MISTAKES TO AVOID:
        ❌ DON'T use: "Grievance" → Use "General" instead
        ❌ DON'T use: "Contract" → Use "General" instead
        ❌ DON'T use: "Legal" → Use "General" instead
        ❌ DON'T use: "Medical" → Use "Personal" instead
        ❌ DON'T use: "Employment" → Use "Personal" or "General" instead
        ✅ DO use: "General", "Personal", "Financial", "Reports", "Tax", "Invoices", "Receipts", "Presentations" (from valid list)
        
        If you're unsure which valid subfolder to use, choose "General" for Documents category.
        
        Now classify the file:
        """
    }
    
    private func buildContextualHints(metadata: FileMetadata, preCategory: String?) -> String {
        var hints = ""
        let fileName = metadata.fileName.lowercased()
        
        // Add parent folder context (important for classification)
        if let parentFolder = metadata.parentFolder, !parentFolder.isEmpty {
            hints += "\n• Parent Folder: \(parentFolder)"
            // Add hint about folder depth if significant
            if metadata.folderDepth > 1 {
                hints += " (depth: \(metadata.folderDepth))"
            }
        }
        
        // Add sibling files context (helps understand file purpose)
        if let siblings = metadata.siblingFiles, !siblings.isEmpty {
            let siblingCount = siblings.count
            let sampleSiblings = siblings.prefix(3).joined(separator: ", ")
            if siblingCount <= 3 {
                hints += "\n• Sibling Files: \(sampleSiblings)"
            } else {
                hints += "\n• Sibling Files: \(sampleSiblings) (+\(siblingCount - 3) more)"
            }
        }
        
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
        
        // Add content preview if available (CRITICAL for content-based classification)
        if let contentPreview = metadata.contentPreview, !contentPreview.isEmpty {
            let validSubfolders = ClassificationConstants.getValidSubfolders(for: preCategory)
            let validSubfoldersList = formatValidSubfolders(validSubfolders)
            
            hints += "\n\n📄 CONTENT PREVIEW (first \(min(contentPreview.count, 500)) characters):"
            hints += "\n─────────────────────────────────────────────────────────────"
            hints += "\n\(contentPreview)"
            hints += "\n─────────────────────────────────────────────────────────────"
            hints += "\n"
            hints += "\n🔍 CONTENT ANALYSIS INSTRUCTIONS:"
            hints += "\n1. Read the content above carefully"
            hints += "\n2. Identify document type from headers, structure, and keywords"
            hints += "\n3. Look for: invoice numbers, amounts, dates, document titles, section headers"
            hints += "\n4. Determine the TRUE purpose (invoice, report, receipt, statement, etc.)"
            hints += "\n5. Map the purpose to a VALID SUBFOLDER from this list:"
            hints += "\n\(validSubfoldersList)"
            hints += "\n6. If content suggests a type NOT in the list above → Use 'General' for Documents"
            hints += "\n7. If content clearly indicates purpose, use it even if filename is generic"
            hints += "\n8. Adjust confidence: High (0.9+) if content and filename agree, Medium (0.7-0.8) if they conflict"
            hints += "\n"
            hints += "\n⚠️ CRITICAL: Content analysis takes priority over filename/extension when available!"
            hints += "\n⚠️ CRITICAL: You MUST use a subfolder from the valid list above - NO custom names!"
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