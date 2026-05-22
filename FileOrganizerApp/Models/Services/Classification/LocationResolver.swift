import Foundation

/// Detects region from file signals; path segment only when ≠ Settings default (§6.0).
final class LocationResolver {

    private let profile: UserProfile
    private let knownPeople: [KnownPerson]

    init(profile: UserProfile, knownPeople: [KnownPerson] = []) {
        var p = profile
        p.syncDerivedFields()
        self.profile = p
        self.knownPeople = knownPeople
    }

    func resolve(_ metadata: FileMetadata, subject: SubjectResolution) -> LocationResolution {
        var signals: [String] = []
        let defaultSlug = profile.homeRegionSlug

        guard defaultSlug != nil, !(defaultSlug?.isEmpty ?? true) else {
            return LocationResolution(
                detectedRegionSlug: nil,
                pathRegionSegment: nil,
                confidence: 0,
                method: .none,
                signals: ["no-default-region"]
            )
        }

        let fileName = metadata.fileName
        let preview = metadata.contentPreview ?? ""
        var bestSlug: String?
        var bestStrength = 0
        var method: LocationMethod = .none

        func consider(_ text: String, source: LocationMethod) {
            if let match = RegionCatalog.detectRegion(in: text) {
                if match.strength > bestStrength {
                    bestStrength = match.strength
                    bestSlug = match.slug
                    method = source
                    signals.append("\(source.rawValue):\(match.keyword)→\(match.slug)")
                }
            }
        }

        consider(fileName, source: .filename)
        if !preview.isEmpty {
            consider(preview, source: .preview)
        }

        if subject.ownership == .other,
           let name = subject.primarySubjectName,
           let person = knownPeople.first(where: { $0.displayName == name }),
           let personSlug = person.regionSlug {
            if bestSlug == nil {
                bestSlug = personSlug
                method = .knownPerson
                signals.append("known-person-region:\(personSlug)")
            }
        }

        let pathSegment = RegionCatalog.pathRegionSegment(
            detectedSlug: bestSlug,
            defaultSlug: defaultSlug
        )

        let confidence: Double
        if pathSegment != nil {
            confidence = min(0.95, 0.7 + Double(bestStrength) * 0.02)
        } else if bestSlug != nil {
            confidence = 0.85
            signals.append("matches-default:\(defaultSlug ?? "")")
        } else {
            confidence = 0.5
            signals.append("implicit-default")
        }

        return LocationResolution(
            detectedRegionSlug: bestSlug,
            pathRegionSegment: pathSegment,
            confidence: confidence,
            method: method,
            signals: signals
        )
    }
}
