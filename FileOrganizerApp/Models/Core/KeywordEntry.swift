import Foundation

struct KeywordEntry: Identifiable, Codable {
    var id = UUID()
    var keyword: String
    var subfolder: String
    var category: String
}
