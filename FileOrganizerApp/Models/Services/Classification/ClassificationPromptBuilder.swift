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
    /// Primary user context for life-domain prompts (optional).
    var userProfile: UserProfile?
    var knownPeople: [KnownPerson] = []

    // MARK: - Public Methods

    /// Build classification prompt for LLM (life-domain taxonomy).
    func buildPrompt(metadata: FileMetadata, preCategory: String?) -> String {
        buildPersonalDomainPrompt(metadata: metadata)
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
}

// MARK: - Prompt Variant (legacy A/B testing — prompt body is always life-domain)

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
