//
//  ClassificationConstants.swift
//  File Classification System
//
//  Constants and helper methods for file classification categories,
//  subfolders, and file extension mappings.
//

import Foundation

// MARK: - Classification Mode

/// Determines which taxonomy is used for classification.
///
/// - standard:      Three functional buckets based on file type (Media / Projects / Documents).
///                  Best for general-purpose folder organisation.
///
/// - personalDomain: Seven life-domain buckets based on *purpose*, not file format.
///                  Best for a personal home folder where the same .pdf can be a
///                  tax record, a legal document, a resume, or a book — and needs
///                  to land in a different place each time.
///                  Priority chain: intent > temporal signals > filename keywords > extension.
enum ClassificationMode: String, CaseIterable {
    case standard       = "standard"
    case personalDomain = "personal_domain"

    private static let userDefaultsKey = "classification_mode"

    /// Persisted classification mode; defaults to personal domain for home-folder use.
    static var persisted: ClassificationMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let mode = ClassificationMode(rawValue: raw) else {
                return .personalDomain
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }

    var displayName: String {
        switch self {
        case .standard:       return "Standard (file type)"
        case .personalDomain: return "Personal (life domain)"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Sorts by file format: Media, Projects, Documents."
        case .personalDomain:
            return "Sorts by purpose: Career, Finance, Legal, Personal, Media, Projects. " +
                   "Career includes job search, work, and learning (courses, university, books). " +
                   "Ignores file type when purpose is clear from name, content, or context."
        }
    }
}

// MARK: - Classification Constants

struct ClassificationConstants {

    // MARK: - Standard Mode Taxonomy

    static let validCategories = ["Media", "Projects", "Documents"]

    static let validSubfolders: [String: [String]] = [
        "Media": ["Photos", "Videos", "Audio", "Screenshots"],
        "Projects": ["Code", "3D", "Design", "Assets", "Web"],
        "Documents": ["General", "Presentations", "Invoices", "Financial", "Reports", "Receipts", "Personal", "Tax"]
    ]

    // MARK: - Personal Domain Mode Taxonomy
    //
    // Categories are life domains, not file types. A PDF can land in Finance,
    // Legal, Career, or Personal depending on what it *is*, not how it's encoded.

    static let personalDomainCategories = [
        "Career", "Finance", "Legal", "Personal", "Media", "Projects"
    ]

    static let personalDomainSubfolders: [String: [String]] = [
        "Career": [
            "Resumes",           // resume, cv, curriculum vitae
            "Cover Letters",     // cover letter, application letter
            "Performance Reviews", // performance review, evaluation, appraisal
            "Job Prep",          // interview prep, career guides, homework, skill lists
            "Certifications",    // exam completion, course certificate, badge
            "Work",              // offer letters, reference letters, employment docs
            "PM Courses",        // cohort slides, product school, structured PM courses
            "University",        // admission, transcript, scholarship, degree
            "Books",             // ebook, textbook, career/PM reading material
            "Notes"              // class notes, lecture recordings, study material
        ],
        "Finance": [
            "Bank Statements",   // account statement, monthly statement, transaction history
            "Taxes",             // W-2, 1099, tax return, K-1, 1095
            "Investments",       // brokerage, portfolio, stock, mutual fund, ETF
            "Bills",             // utility bill, invoice, payment due
            "Receipts"           // purchase receipt, payment confirmation
        ],
        "Legal": [
            "Immigration",       // visa, I-94, passport, work permit, EAD
            "Court Cases",       // case filing, court order, legal notice
            "Probate",           // estate, probate, administrator, distribution
            "Evidence",          // evidence of funds, affidavit, declaration
            "Contracts"          // agreement, NDA, lease, rental contract
        ],
        "Personal": [
            "Health",            // medical record, appointment, lab result, insurance EOB
            "Identity",          // government ID, driving license, passport scan, SSN card
            "Insurance",         // insurance policy, coverage letter, claim
            "Rent",              // rental agreement, lease, payment receipt
            "General"            // personal items that don't fit above
        ],
        "Media": [
            "Photos",
            "Videos",
            "Audio",
            "Screenshots",
            "App UI",            // app mockups, design screenshots, UI previews
            "Creative"           // artwork, design assets, creative projects
        ],
        "Projects": [
            "Apps",              // named app project directories
            "Experiments",       // sandbox, prototype, test project
            "Assets",            // icons, vectors, logos, design files
            "Code",              // standalone scripts, code snippets
            "Scaffold"           // boilerplate, template, starter kit
        ]
    ]

    // MARK: - Project Directory Signals
    //
    // Files whose presence in a directory strongly signals it is a software project root.
    // Used to classify *directories* rather than individual files.

    static let projectRootSignals: Set<String> = [
        "Package.swift",        // Swift Package Manager
        "package.json",         // Node.js / npm
        "Cargo.toml",           // Rust
        "go.mod",               // Go
        "pom.xml",              // Java / Maven
        "build.gradle",         // Gradle
        "Makefile",             // Make
        "docker-compose.yml",   // Docker Compose
        "Dockerfile",           // Docker
        "pyproject.toml",       // Python (PEP 517)
        "setup.py",             // Python setuptools
        "requirements.txt",     // Python deps
        ".git",                 // any git repo
        "CMakeLists.txt",       // CMake
        "*.xcodeproj",          // Xcode project (pattern — checked separately)
        "*.xcworkspace"         // Xcode workspace (pattern — checked separately)
    ]

    // MARK: - Temporal Filename Patterns
    //
    // Prefixes/patterns that indicate a file was auto-named by date and is
    // archival rather than a primary document.

    static let temporalPrefixPatterns: [String] = [
        "Screenshot",           // macOS screenshot: "Screenshot 2024-01-10 at..."
        "Screen Shot",          // older macOS format: "Screen Shot 2022-09-23 at..."
        "IMG_",                 // iPhone photo export
        "PXL_",                 // Google Pixel photo
        "photo_",               // generic phone photo
        "video_",               // generic phone video
        "DCIM"                  // digital camera
    ]
    
    // MARK: - File Extension Categories
    
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
        "webp", "svg", "heic", "heif", "ico", "raw", "cr2", "nef"
    ]
    
    static let videoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm",
        "m4v", "mpg", "mpeg", "3gp", "ogv"
    ]
    
    static let audioExtensions: Set<String> = [
        "mp3", "wav", "aac", "flac", "ogg", "m4a", "wma",
        "opus", "aiff", "ape", "alac"
    ]
    
    static let modelExtensions: Set<String> = [
        "stl", "obj", "fbx", "blend", "3ds", "dae", "gltf",
        "glb", "ply", "max", "c4d"
    ]
    
    static let codeExtensions: Set<String> = [
        "swift", "js", "ts", "py", "java", "cpp", "c", "h",
        "cs", "go", "rs", "rb", "php", "pl", "sh", "bat",
        "ps1", "scala", "kt", "m", "r", "lua", "vim"
    ]
    
    static let webExtensions: Set<String> = [
        "html", "htm", "css", "scss", "sass", "less",
        "jsx", "tsx", "vue", "svelte"
    ]
    
    static let presentationExtensions: Set<String> = [
        "ppt", "pptx", "key", "odp"
    ]
    
    static let spreadsheetExtensions: Set<String> = [
        "xlsx", "xls", "csv", "numbers", "ods", "tsv"
    ]
    
    static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "txt", "rtf", "odt", "pages",
        "md", "tex", "epub", "mobi"
    ]

    /// Extensions where a UTF-8 (or fallback) text preview helps classification.
    static let textPreviewExtensions: Set<String> = {
        var exts = Set(["txt", "md", "json", "xml", "yaml", "yml", "log", "ini", "env", "toml"])
        exts.formUnion(codeExtensions)
        exts.formUnion(webExtensions)
        exts.formUnion(["csv", "tsv"])
        return exts
    }()
    
    static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
        "tgz", "tbz2", "zipx", "iso"
    ]

    /// Editor plugin/theme bundles — not software project roots.
    static let editorPackageExtensions: Set<String> = [
        "sublime-package", "vsix", "lex"
    ]

    static func isCodeOrWebExtension(_ fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased()
        return codeExtensions.contains(ext) || webExtensions.contains(ext)
    }

    static func isEditorPackage(_ fileName: String, fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased()
        let name = fileName.lowercased()
        return editorPackageExtensions.contains(ext) || editorPackageExtensions.contains(where: { name.hasSuffix(".\($0)") })
    }
    
    static let installerExtensions: Set<String> = [
        "dmg", "pkg", "exe", "msi", "app", "deb", "rpm",
        "apk", "ipa"
    ]
    
    // MARK: - Helper Methods (Standard Mode)

    static func getValidSubfolders(for category: String?) -> [String: [String]] {
        if let category = category {
            return [category: validSubfolders[category] ?? ["General"]]
        }
        return validSubfolders
    }

    static func isValidCategory(_ category: String) -> Bool {
        return validCategories.contains(category)
    }

    static func isValidSubfolder(_ subfolder: String, for category: String) -> Bool {
        return validSubfolders[category]?.contains(subfolder) ?? false
    }

    static func getCategoryForExtension(_ fileExtension: String) -> String? {
        let ext = fileExtension.lowercased()

        if imageExtensions.contains(ext) || videoExtensions.contains(ext) || audioExtensions.contains(ext) {
            return "Media"
        } else if modelExtensions.contains(ext) || codeExtensions.contains(ext) || webExtensions.contains(ext) {
            return "Projects"
        } else if presentationExtensions.contains(ext) || spreadsheetExtensions.contains(ext) || documentExtensions.contains(ext) {
            return "Documents"
        }
        // Archives and installers are classified by filename/content, not extension
        // They default to Documents/General if no content hints
        return nil
    }

    // MARK: - Helper Methods (Personal Domain Mode)

    static func getPersonalDomainSubfolders(for category: String?) -> [String: [String]] {
        if let category = category {
            return [category: personalDomainSubfolders[category] ?? ["General"]]
        }
        return personalDomainSubfolders
    }

    static func isValidPersonalCategory(_ category: String) -> Bool {
        return personalDomainCategories.contains(category)
    }

    static func isValidPersonalSubfolder(_ subfolder: String, for category: String) -> Bool {
        return personalDomainSubfolders[category]?.contains(subfolder) ?? false
    }

    /// In personal domain mode, extension is a weak signal — it only pins the
    /// category when nothing else is known. Career / Finance / Legal / Personal
    /// categories can all contain the same file extensions.
    static func getDefaultPersonalCategoryForExtension(_ fileExtension: String) -> String {
        let ext = fileExtension.lowercased()

        if imageExtensions.contains(ext) || videoExtensions.contains(ext) || audioExtensions.contains(ext) {
            return "Media"
        } else if modelExtensions.contains(ext) || codeExtensions.contains(ext) || webExtensions.contains(ext) {
            return "Projects"
        }
        // All document-like formats could be in any life domain — caller must resolve
        return "Personal"
    }

    /// Returns true if the filename starts with a known temporal auto-naming prefix.
    static func hasTemporalPrefix(_ fileName: String) -> Bool {
        return temporalPrefixPatterns.contains { fileName.hasPrefix($0) }
    }

    // MARK: - Career Intent (filename signals)

    /// Interview prep, homework, PM/career guides — not an actual CV.
    static func matchesJobPrepFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        if containsAny(name, [
            "interview homework", "interview prep", "mock interview",
            "job prep", "job-prep", "jobprep", "career guide", "career ladder",
            "homework", "case study", "unofficial guide", "ultimate guide"
        ]) {
            return true
        }
        if containsAny(name, ["interview"]) { return true }
        if containsAny(name, ["homework"]) { return true }
        if containsAny(name, ["career"]) && containsAny(name, ["guide", "ladder", "handbook", "playbook", "primer"]) {
            return true
        }
        let hasPM = containsAny(name, [" pm ", " pm_", "_pm_", "product manager", "product management"])
            || name.hasPrefix("pm ")
            || name.contains("pm career")
        if hasPM && containsAny(name, ["guide", "ladder", "handbook", "playbook"]) {
            return true
        }
        return false
    }

    /// True only when the file is likely the user's actual CV, not a guide that mentions resumes.
    static func matchesActualResumeFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        if matchesJobPrepFilename(fileName) { return false }
        if containsAny(name, [
            "resume guide", "resume tips", "resume writing", "how to write a resume",
            "writing a resume", "resume template", "sample resume"
        ]) {
            return false
        }
        if containsAny(name, ["curriculum vitae", "curriculum-vitae"]) { return true }
        if matchesWordBoundary(name, words: ["resume", "cv"]) { return true }
        if name.range(of: #"\b(resume|cv)[-_.\s]"#, options: .regularExpression) != nil { return true }
        if name.range(of: #"[-_.\s](resume|cv)\b"#, options: .regularExpression) != nil { return true }
        if name.hasSuffix("-resume") || name.hasSuffix("_resume") || name.hasSuffix("-cv") || name.hasSuffix("_cv") {
            return true
        }
        return false
    }

    private static func containsAny(_ target: String, _ keywords: [String]) -> Bool {
        keywords.contains { target.contains($0) }
    }

    private static func matchesWordBoundary(_ target: String, words: [String]) -> Bool {
        for word in words {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if target.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Filename signals (intent detection + LLM normalization)

    static func matchesIdentityFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        if containsAny(name, [
            "aadhaar", "passport", "biometric", "vfsappointment", "vfs appointment",
            "ssn", "ss card", "driver license", "driver licence", "driving license",
            "id card", "idcard", "national id", "green card", "invitation letter"
        ]) {
            return true
        }
        return matchesWordBoundary(name, words: ["passport", "aadhaar"])
    }

    static func matchesTaxFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        if containsAny(name, [
            "1099", "1095", "1040", "w-2", "w2", "k-1", "1099int", "taxes20",
            "taxdoc", "tax document", "form 8949", "8949-", "irs ", "schedule a",
            "coinbase-8949", "consolidated form", "tax relief", "tax_1099"
        ]) {
            return true
        }
        if matchesWordBoundary(name, words: ["taxes"]) { return true }
        if matchesWordBoundary(name, words: ["tax"]) {
            return !containsAny(name, ["syntax", "sublime", "prox"])
        }
        return false
    }

    static func matchesBankStatementFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        return containsAny(name, [
            "estmt", "e-stmt", "bank statement", "clientstatement", "client statement",
            "transactions_history", "transaction history", "pay date", "paydate",
            "transfer activity", "remitly"
        ])
    }

    static func matchesScreenshotFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        return hasTemporalPrefix(fileName)
            || name.contains("screenshot")
            || name.contains("screen shot")
    }

    static func matchesBrowserArtifactFilename(_ fileName: String) -> Bool {
        let name = fileName.lowercased()
        return containsAny(name, [
            "gapi", "adsct", "iframe", "saved_resource", "googletagmanager",
            "proxy.html", "loaded_0", "loaded_1", "m-outer-", "cb=gapi"
        ]) || name == "js"
    }

    static let bundledArtifactExtensions: Set<String> = [
        "jar", "dylib", "pyc", "pem", "icns", "typed", "loaded_0", "loaded_1"
    ]

    static func siblingIndicatesProjectRoot(_ siblings: [String]?) -> Bool {
        guard let siblings = siblings, !siblings.isEmpty else { return false }
        for sibling in siblings {
            if projectRootSignals.contains(sibling) { return true }
            if sibling.hasSuffix(".xcodeproj") || sibling.hasSuffix(".xcworkspace") { return true }
        }
        return false
    }

    /// Maps a pre-detected intent string to personal-domain category/subfolder.
    static func personalDomainRoute(for intent: String) -> (category: String, subfolder: String)? {
        switch intent {
        case "job_prep": return ("Career", "Job Prep")
        case "resume": return ("Career", "Resumes")
        case "cover_letter": return ("Career", "Cover Letters")
        case "performance_review": return ("Career", "Performance Reviews")
        case "offer_letter", "payroll": return ("Career", "Work")
        case "certification": return ("Career", "Certifications")
        case "tax": return ("Finance", "Taxes")
        case "bank_statement": return ("Finance", "Bank Statements")
        case "invoice": return ("Finance", "Bills")
        case "receipt": return ("Finance", "Receipts")
        case "investment": return ("Finance", "Investments")
        case "immigration": return ("Legal", "Immigration")
        case "probate": return ("Legal", "Probate")
        case "court_case": return ("Legal", "Court Cases")
        case "evidence": return ("Legal", "Evidence")
        case "contract": return ("Legal", "Contracts")
        case "health": return ("Personal", "Health")
        case "insurance": return ("Personal", "Insurance")
        case "identity": return ("Personal", "Identity")
        case "rent": return ("Personal", "Rent")
        case "travel": return ("Personal", "General")
        case "university": return ("Career", "University")
        case "course": return ("Career", "PM Courses")
        case "book": return ("Career", "Books")
        case "notes": return ("Career", "Notes")
        case "screenshot_or_photo": return ("Media", "Screenshots")
        case "video": return ("Media", "Videos")
        default: return nil
        }
    }

    /// Fix common LLM mistakes (invented subfolders, wrong category for code files) before validation.
    static func normalizeLLMClassification(
        _ result: ClassificationResult,
        metadata: FileMetadata,
        mode: ClassificationMode
    ) -> ClassificationResult {
        var category = result.category
        var subfolder = result.subfolder
        var reasoning = result.reasoning ?? ""
        let ext = metadata.fileExtension.lowercased()
        let subfolderMap = mode == .personalDomain ? personalDomainSubfolders : validSubfolders

        func subfolders(for cat: String) -> [String] {
            subfolderMap[cat] ?? []
        }

        func projectsCodeSubfolder() -> String {
            mode == .personalDomain ? "Code" : (webExtensions.contains(ext) ? "Web" : "Code")
        }

        var changed = false

        // Legacy: Education category folded into Career (subfolder names unchanged)
        if mode == .personalDomain, category == "Education" {
            category = "Career"
            if !subfolders(for: "Career").contains(subfolder) {
                subfolder = matchesJobPrepFilename(metadata.fileName) ? "Job Prep" : "PM Courses"
            }
            changed = true
        }

        // Sublime/VS Code plugin packages are not app project roots
        if isEditorPackage(metadata.fileName, fileExtension: ext) {
            if category != "Projects" || subfolder != projectsCodeSubfolder() {
                category = "Projects"
                subfolder = projectsCodeSubfolder()
                changed = true
            }
        }

        // Stylesheets and code must not land in Media
        if isCodeOrWebExtension(ext) || textPreviewExtensions.contains(ext) {
            let codeSub = projectsCodeSubfolder()
            if category == "Media" || !subfolders(for: category).contains(subfolder) {
                if category != "Projects" || subfolder != codeSub {
                    category = "Projects"
                    subfolder = codeSub
                    changed = true
                }
            }
        }

        // Case-insensitive subfolder match within category
        if let match = subfolders(for: category).first(where: { $0.lowercased() == subfolder.lowercased() }) {
            if match != subfolder { subfolder = match; changed = true }
        }

        // Career guides ≠ actual CVs — Resumes only for real resume files
        if mode == .personalDomain, category == "Career", subfolder == "Resumes" {
            if metadata.detectedIntent == "job_prep" || matchesJobPrepFilename(metadata.fileName) {
                subfolder = "Job Prep"
                changed = true
            } else if !matchesActualResumeFilename(metadata.fileName) {
                subfolder = "Job Prep"
                changed = true
            }
        }

        if mode == .personalDomain {
            // Identity requires real ID/passport signals — not prompt-example pattern matching
            if category == "Personal", subfolder == "Identity",
               !matchesIdentityFilename(metadata.fileName) {
                if let intent = metadata.detectedIntent,
                   let route = personalDomainRoute(for: intent), route.subfolder != "Identity" {
                    category = route.category
                    subfolder = route.subfolder
                } else if metadata.detectedIntent == "offer_letter" {
                    category = "Career"
                    subfolder = "Work"
                } else {
                    subfolder = "General"
                }
                changed = true
            }

            // eStmt / pay stubs are not tax returns
            if category == "Finance", subfolder == "Taxes",
               matchesBankStatementFilename(metadata.fileName),
               !matchesTaxFilename(metadata.fileName) {
                subfolder = "Bank Statements"
                changed = true
            }

            // PM/career guides misrouted to Personal/Health from noisy previews
            if category == "Personal", subfolder == "Health",
               matchesJobPrepFilename(metadata.fileName) {
                category = "Career"
                subfolder = "Job Prep"
                changed = true
            }

            // False "Screenshot" / Media when there is no temporal prefix
            if category == "Media", subfolder == "Screenshots",
               !matchesScreenshotFilename(metadata.fileName) {
                if isCodeOrWebExtension(ext) || matchesBrowserArtifactFilename(metadata.fileName) {
                    category = "Projects"
                    subfolder = projectsCodeSubfolder()
                } else if matchesJobPrepFilename(metadata.fileName) {
                    category = "Career"
                    subfolder = "Job Prep"
                } else if let intent = metadata.detectedIntent, let route = personalDomainRoute(for: intent) {
                    category = route.category
                    subfolder = route.subfolder
                } else {
                    category = "Personal"
                    subfolder = "General"
                }
                changed = true
            }

            // Browser / ad / cache artifacts
            if matchesBrowserArtifactFilename(metadata.fileName) {
                category = "Projects"
                subfolder = projectsCodeSubfolder()
                changed = true
            }

            // JARs, dylibs, etc. inside app bundles are not Projects/Apps
            if category == "Projects", subfolder == "Apps" {
                if bundledArtifactExtensions.contains(ext)
                    || isEditorPackage(metadata.fileName, fileExtension: ext) {
                    subfolder = projectsCodeSubfolder()
                    changed = true
                } else if (archiveExtensions.contains(ext) || installerExtensions.contains(ext)),
                          !siblingIndicatesProjectRoot(metadata.siblingFiles),
                          metadata.detectedIntent != nil,
                          let route = personalDomainRoute(for: metadata.detectedIntent!) {
                    category = route.category
                    subfolder = route.subfolder
                    changed = true
                } else if (archiveExtensions.contains(ext) || installerExtensions.contains(ext)),
                          !siblingIndicatesProjectRoot(metadata.siblingFiles) {
                    subfolder = "Scaffold"
                    changed = true
                }
            }
        }

        // Map invented subfolder labels (CSS, Java, legal documents, etc.) to valid taxonomy
        if !subfolders(for: category).contains(subfolder) {
            let lowerSub = subfolder.lowercased()
            let legalInvented: Set<String> = ["legal documents", "legal document", "legals", "legal"]
            if legalInvented.contains(lowerSub) {
                category = "Legal"
                let name = metadata.fileName.lowercased()
                subfolder = containsAny(name, ["probate", "estate", "grievance", "court"])
                    ? (containsAny(name, ["probate", "estate"]) ? "Probate" : "Court Cases")
                    : "Contracts"
                changed = true
            }

            let inventedTechLabels: Set<String> = [
                "css", "scss", "sass", "less", "html", "htm", "javascript", "typescript",
                "java", "python", "code", "source", "script", "web", "json", "xml", "yaml"
            ]
            if inventedTechLabels.contains(lowerSub) {
                category = "Projects"
                subfolder = projectsCodeSubfolder()
                changed = true
            }
        }

        // Trust pre-computed intent when it clearly contradicts a weak LLM guess
        if mode == .personalDomain,
           let intent = metadata.detectedIntent,
           let route = personalDomainRoute(for: intent),
           result.confidence < 0.88 {
            let llmLooksWeak = (category == "Personal" && subfolder == "General")
                || (category == "Media" && subfolder == "Screenshots" && !matchesScreenshotFilename(metadata.fileName))
                || (category == "Personal" && subfolder == "Identity" && !matchesIdentityFilename(metadata.fileName))
            if llmLooksWeak && (category != route.category || subfolder != route.subfolder) {
                category = route.category
                subfolder = route.subfolder
                changed = true
            }
        }

        // Still invalid — pick a safe default for the category, or Projects/Code for unknown
        if !subfolders(for: category).contains(subfolder) {
            if isCodeOrWebExtension(ext) {
                category = "Projects"
                subfolder = projectsCodeSubfolder()
            } else if mode == .personalDomain, category == "Personal" {
                subfolder = "General"
            } else if let fallback = subfolders(for: category).first {
                subfolder = fallback
            } else if mode == .personalDomain {
                category = "Personal"
                subfolder = "General"
            } else {
                category = "Documents"
                subfolder = "General"
            }
            changed = true
        }

        if changed {
            reasoning += " [normalized to \(category)/\(subfolder)]"
        }

        return ClassificationResult(
            category: category,
            subfolder: subfolder,
            confidence: result.confidence,
            reasoning: reasoning,
            method: result.method
        )
    }
}

