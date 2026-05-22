import Foundation

/// Persists user profile and known-other-people list for subject/location-aware filing.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    private static let profileFileName = "file_organizer_profile.json"
    private static let knownPeopleFileName = "file_organizer_known_people.json"

    @Published var profile: UserProfile
    @Published var knownPeople: [KnownPerson] = []

    private var documentsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    }

    init() {
        profile = UserProfile()
        profile.syncDerivedFields()
        load()
    }

    /// Update profile fields safely for SwiftUI bindings (never bind with `$store.profile.field`).
    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        var updated = profile
        mutate(&updated)
        updated.syncDerivedFields()
        profile = updated
    }

    func load() {
        let profileURL = documentsDirectory.appendingPathComponent(Self.profileFileName)
        if let data = try? Data(contentsOf: profileURL),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
            profile.syncDerivedFields()
        }

        let peopleURL = documentsDirectory.appendingPathComponent(Self.knownPeopleFileName)
        if let data = try? Data(contentsOf: peopleURL),
           let decoded = try? JSONDecoder().decode([KnownPerson].self, from: data) {
            knownPeople = decoded
        }
    }

    func save() {
        profile.syncDerivedFields()
        let profileURL = documentsDirectory.appendingPathComponent(Self.profileFileName)
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: profileURL)
        }

        let peopleURL = documentsDirectory.appendingPathComponent(Self.knownPeopleFileName)
        if let data = try? JSONEncoder().encode(knownPeople) {
            try? data.write(to: peopleURL)
        }
    }

    func addKnownPerson(displayName: String, matchTokens: String, relationship: String? = nil, region: String? = nil) {
        let tokens = matchTokens
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        knownPeople.append(KnownPerson(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            matchTokens: tokens,
            relationship: relationship,
            region: region?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ))
        save()
    }

    func removeKnownPerson(at offsets: IndexSet) {
        knownPeople.remove(atOffsets: offsets)
        save()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
