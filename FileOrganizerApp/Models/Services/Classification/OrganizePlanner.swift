import Foundation

/// Builds full organize destinations (domain + subject + location paths).
enum OrganizePlanner {

    static func plan(
        metadata: FileMetadata,
        classification: ClassificationResult,
        profile: UserProfile,
        knownPeople: [KnownPerson] = []
    ) -> OrganizeDestination {
        let subject = SubjectResolver(profile: profile, knownPeople: knownPeople).resolve(metadata)
        let location = LocationResolver(profile: profile, knownPeople: knownPeople).resolve(metadata, subject: subject)
        return OrganizeDestination(
            classification: classification,
            subject: subject,
            location: location
        )
    }

    static func targetFolderURL(
        base: URL,
        destination: OrganizeDestination,
        profile: UserProfile
    ) -> URL {
        let relative = destination.relativePath(profile: profile)
        var url = base
        for component in relative.split(separator: "/") where !component.isEmpty {
            url = url.appendingPathComponent(String(component))
        }
        return url
    }
}
