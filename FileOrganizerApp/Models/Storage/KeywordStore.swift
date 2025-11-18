import Foundation

class KeywordStore: ObservableObject {
    @Published var keywords: [KeywordEntry] = []

    init() {
        load()
    }

    func load() {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/file_organizer_keywords.json")
        if let data = try? Data(contentsOf: path),
           let decoded = try? JSONDecoder().decode([KeywordEntry].self, from: data) {
            keywords = decoded
        }
    }

    func save() {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/file_organizer_keywords.json")
        if let data = try? JSONEncoder().encode(keywords) {
            try? data.write(to: path)
        }
    }

    func add(keyword: String, subfolder: String, category: String) {
        keywords.append(KeywordEntry(keyword: keyword, subfolder: subfolder, category: category))
        save()
    }
    
    func clearAllKeywords() {
        keywords.removeAll()
        save()
    }
}
