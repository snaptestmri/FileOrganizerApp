import Foundation

enum OrganizePathBuilder {

    static func relativePath(
        profile: UserProfile,
        subject: SubjectResolution,
        location: LocationResolution,
        domainPath: String
    ) -> String {
        let region = location.pathRegionSegment

        switch subject.ownership {
        case .mine, .unknown:
            if let region { return "\(region)/\(domainPath)" }
            return domainPath

        case .other:
            guard profile.enableSubjectFolders else {
                if let region { return "\(region)/\(domainPath)" }
                return domainPath
            }
            let root = profile.othersRootFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            let othersRoot = root.isEmpty ? "Others" : root
            let person = subject.subjectSlug ?? "Unknown"
            if let region { return "\(othersRoot)/\(person)/\(region)/\(domainPath)" }
            return "\(othersRoot)/\(person)/\(domainPath)"
        }
    }
}
