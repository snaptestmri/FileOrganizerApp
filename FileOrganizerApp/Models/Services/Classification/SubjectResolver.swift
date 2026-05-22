import Foundation

/// Determines document ownership (primary user vs other person) from filename and preview.
final class SubjectResolver {

    private let profile: UserProfile
    private let knownPeople: [KnownPerson]

    init(profile: UserProfile, knownPeople: [KnownPerson] = []) {
        var p = profile
        p.syncDerivedFields()
        self.profile = p
        self.knownPeople = knownPeople
    }

    func resolve(_ metadata: FileMetadata) -> SubjectResolution {
        var signals: [String] = []
        let fileName = metadata.fileName
        let lowerName = fileName.lowercased()
        let preview = metadata.contentPreview?.lowercased() ?? ""

        var primaryScore = 0.0
        var otherScore = 0.0
        var otherName: String?
        var otherSlug: String?

        // Profile tokens
        for token in profile.profileMatchTokens() where token.count >= 3 {
            if lowerName.contains(token) {
                primaryScore += token.count >= 8 ? 3.0 : 2.0
                signals.append("profile:\(token)")
            } else if preview.contains(token) {
                primaryScore += 1.5
                signals.append("preview-profile:\(token)")
            }
        }

        // Known people (explicit list)
        for person in knownPeople {
            var personScore = 0.0
            for token in person.matchTokens where token.count >= 3 {
                if lowerName.contains(token) {
                    personScore += 2.5
                    signals.append("known:\(token)")
                } else if preview.contains(token) {
                    personScore += 1.5
                }
            }
            if personScore > otherScore {
                otherScore = personScore
                otherName = person.displayName
                otherSlug = UserProfile.personSlug(from: person.displayName)
            }
        }

        // LAST, FIRST — e.g. RICHARDSON, JON-PAUL
        if let commaName = extractLastCommaFirstName(from: fileName) {
            if !matchesProfile(commaName) {
                let score = 4.0
                if score > otherScore {
                    otherScore = score
                    otherName = commaName
                    otherSlug = UserProfile.personSlug(from: commaName)
                    signals.append("pattern:last,first")
                }
            }
        }

        // Estate: Neelmani_Singh_Estate
        if let estateName = extractEstateName(from: lowerName) {
            if !matchesProfile(estateName) {
                let score = 4.0
                if score > otherScore {
                    otherScore = score
                    otherName = estateName
                    otherSlug = UserProfile.personSlug(from: estateName)
                    signals.append("pattern:estate")
                }
            }
        }

        // Grievance / embedded name tokens (jon_paul, jon-paul)
        if let embedded = extractEmbeddedPersonToken(from: lowerName) {
            if let matched = matchKnownPerson(token: embedded) {
                if 3.0 > otherScore {
                    otherScore = 3.0
                    otherName = matched.displayName
                    otherSlug = UserProfile.personSlug(from: matched.displayName)
                    signals.append("pattern:embedded-\(embedded)")
                }
            }
        }

        let threshold = 1.5
        if otherScore > primaryScore + threshold, let name = otherName, let slug = otherSlug {
            return SubjectResolution(
                ownership: .other,
                primarySubjectName: name,
                subjectSlug: slug,
                confidence: min(0.98, 0.75 + otherScore * 0.05),
                method: .rules,
                signals: signals
            )
        }

        if primaryScore > 0 {
            return SubjectResolution(
                ownership: .mine,
                primarySubjectName: profile.fullName.nilIfEmpty,
                subjectSlug: nil,
                confidence: min(0.98, 0.8 + primaryScore * 0.03),
                method: .rules,
                signals: signals
            )
        }

        return SubjectResolution(
            ownership: .unknown,
            primarySubjectName: nil,
            subjectSlug: nil,
            confidence: 0.45,
            method: .rules,
            signals: signals.isEmpty ? ["no-subject-signal"] : signals
        )
    }

    // MARK: - Private

    private func matchesProfile(_ name: String) -> Bool {
        let lower = name.lowercased()
        return profile.profileMatchTokens().contains { lower.contains($0) && $0.count >= 4 }
    }

    private func matchKnownPerson(token: String) -> KnownPerson? {
        knownPeople.first { person in
            person.matchTokens.contains { token.contains($0) || $0.contains(token) }
                || person.displayName.lowercased().contains(token)
        }
    }

    private func extractLastCommaFirstName(from fileName: String) -> String? {
        let base = (fileName as NSString).deletingPathExtension
        guard let commaRange = base.range(of: ",") else { return nil }
        let last = String(base[..<commaRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var first = String(base[base.index(after: commaRange.lowerBound)...])
        if let dash = first.range(of: " -") { first = String(first[..<dash.lowerBound]) }
        first = first.trimmingCharacters(in: .whitespacesAndNewlines)
        guard last.count >= 2, first.count >= 2 else { return nil }
        let lastWords = last.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
        let firstWords = first.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        return "\(firstWords) \(lastWords)"
    }

    private func extractEstateName(from lowerName: String) -> String? {
        guard lowerName.contains("estate") else { return nil }
        let parts = lowerName.split(separator: "_")
        guard parts.count >= 2 else { return nil }
        let nameParts = parts.prefix(while: { !$0.contains("estate") })
        guard nameParts.count >= 2 else { return nil }
        let stripped = nameParts.map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
        return stripped.map { $0.capitalized }.joined(separator: " ")
    }

    private func extractEmbeddedPersonToken(from lowerName: String) -> String? {
        if let range = lowerName.range(of: "grievance_") {
            let tail = lowerName[range.upperBound...]
            let token = tail.split(separator: "_").first.map(String.init) ?? ""
            return token.count >= 3 ? token : nil
        }
        if let range = lowerName.range(of: "grievance ") {
            let tail = lowerName[range.upperBound...]
            let token = tail.split(separator: " ").first.map(String.init) ?? ""
            return token.count >= 3 ? token : nil
        }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
