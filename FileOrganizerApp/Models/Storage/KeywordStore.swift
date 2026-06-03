import Foundation

class KeywordStore: ObservableObject {
    @Published var keywords: [KeywordEntry] = []
    private let persistToDisk: Bool
    private let lock = NSLock()

    init(loadFromDisk: Bool = true) {
        persistToDisk = loadFromDisk
        if loadFromDisk {
            load()
        }
    }

    func load() {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/file_organizer_keywords.json")
        if let data = try? Data(contentsOf: path),
           let decoded = try? JSONDecoder().decode([KeywordEntry].self, from: data) {
            keywords = decoded
        }
    }

    func save() {
        guard persistToDisk else { return }
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/file_organizer_keywords.json")
        if let data = try? JSONEncoder().encode(keywords) {
            try? data.write(to: path)
        }
    }

    func add(keyword: String, subfolder: String, category: String) {
        lock.lock()
        keywords.append(KeywordEntry(keyword: keyword, subfolder: subfolder, category: category))
        lock.unlock()
        save()
    }
    
    func clearAllKeywords() {
        lock.lock()
        keywords.removeAll()
        lock.unlock()
        save()
    }
}
