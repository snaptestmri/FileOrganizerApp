import Foundation

/// Maps text signals to canonical region slugs for path segments (when ≠ user default).
enum RegionCatalog {

    struct RegionRule {
        let slug: String
        let keywords: [String]
    }

    static let rules: [RegionRule] = [
        RegionRule(slug: "California", keywords: [
            "california", "state of california", "ca ", " ca,", "(ca)", "pge", "pg&e",
            "edd.ca.gov", "dmv.ca", "franchise tax board", "sacramento"
        ]),
        RegionRule(slug: "New-York", keywords: [
            "new york", "state of new york", "ny ", " ny,", "(ny)", "nyc", "new-york"
        ]),
        RegionRule(slug: "Texas", keywords: ["texas", "state of texas", "tx ", " tx,"]),
        RegionRule(slug: "India", keywords: [
            "india", "aadhaar", "aadhar", "pan card", "mumbai", "delhi", "bangalore",
            "vfs global", "uidai"
        ]),
        RegionRule(slug: "United-Kingdom", keywords: ["united kingdom", " u.k.", " uk ", "england", "scotland", "wales"]),
    ]

    /// Returns the best-matching region slug and match strength (keyword count).
    static func detectRegion(in text: String) -> (slug: String, strength: Int, keyword: String)? {
        let lower = text.lowercased()
        var best: (slug: String, strength: Int, keyword: String)?

        for rule in rules {
            for keyword in rule.keywords {
                if lower.contains(keyword) {
                    let strength = keyword.count
                    if best == nil || strength > best!.strength {
                        best = (rule.slug, strength, keyword)
                    }
                }
            }
        }
        return best
    }

    static func pathRegionSegment(
        detectedSlug: String?,
        defaultSlug: String?
    ) -> String? {
        guard let detected = detectedSlug, !detected.isEmpty else { return nil }
        guard let defaultSlug, !defaultSlug.isEmpty else { return nil }
        if detected.caseInsensitiveCompare(defaultSlug) == .orderedSame { return nil }
        return detected
    }
}
