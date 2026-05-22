import Foundation

// MARK: - User profile (Settings)

struct UserProfile: Codable, Equatable {
    var fullName: String = ""
    var nameAliases: [String] = []
    var homeRegion: String?
    var homeRegionSlug: String?
    var employers: [String] = []
    var emailDomains: [String] = []

    var enableSubjectFolders: Bool = true
    var othersRootFolderName: String = "Others"

    var hasIdentity: Bool {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || nameAliases.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    mutating func syncDerivedFields() {
        homeRegionSlug = homeRegion.map { UserProfile.regionSlug(from: $0) }
        nameAliases = nameAliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        employers = employers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// All lowercase tokens used to match the primary user in filenames / previews.
    func profileMatchTokens() -> [String] {
        var tokens: [String] = []
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !name.isEmpty {
            tokens.append(name)
            tokens.append(contentsOf: name.split(separator: " ").map(String.init))
            tokens.append(name.replacingOccurrences(of: " ", with: ""))
            tokens.append(name.replacingOccurrences(of: " ", with: "-"))
            tokens.append(name.replacingOccurrences(of: " ", with: "_"))
        }
        for alias in nameAliases {
            let a = alias.lowercased()
            if !a.isEmpty { tokens.append(a) }
        }
        return Array(Set(tokens))
    }

    static func regionSlug(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(cleaned)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func personSlug(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }
        return trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}

// MARK: - Known other people

struct KnownPerson: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var displayName: String
    var matchTokens: [String]
    var relationship: String?
    var region: String?

    var regionSlug: String? {
        guard let region, !region.isEmpty else { return nil }
        return UserProfile.regionSlug(from: region)
    }
}

// MARK: - Subject

enum DocumentOwnership: String, Codable {
    case mine
    case other
    case unknown
}

enum SubjectMethod: String, Codable {
    case rules
    case llm
    case userOverride
}

struct SubjectResolution: Codable, Equatable {
    let ownership: DocumentOwnership
    let primarySubjectName: String?
    let subjectSlug: String?
    let confidence: Double
    let method: SubjectMethod
    let signals: [String]
}

// MARK: - Location

enum LocationMethod: String, Codable {
    case filename
    case preview
    case knownPerson
    case llm
    case none
}

struct LocationResolution: Codable, Equatable {
    let detectedRegionSlug: String?
    let pathRegionSegment: String?
    let confidence: Double
    let method: LocationMethod
    let signals: [String]
}

// MARK: - Organize destination

struct OrganizeDestination {
    let classification: ClassificationResult
    let subject: SubjectResolution
    let location: LocationResolution

    var domainPath: String {
        "\(classification.category)/\(classification.subfolder)"
    }

    func relativePath(profile: UserProfile) -> String {
        OrganizePathBuilder.relativePath(
            profile: profile,
            subject: subject,
            location: location,
            domainPath: domainPath
        )
    }
}
