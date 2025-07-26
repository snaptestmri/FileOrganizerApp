import Foundation
import AppKit

struct FileMover {
    let sourceFolder: URL
    let baseTargetFolder: URL

    init(sourceFolder: URL) {
        self.sourceFolder = sourceFolder
        self.baseTargetFolder = sourceFolder
    }

    func run(with keywords: [KeywordEntry]) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil) else { return }

        for item in contents {
            let lowerName = item.lastPathComponent.lowercased()
            var matchedKeyword: KeywordEntry? = nil

            for keyword in keywords {
                if lowerName.contains(keyword.keyword.lowercased()) {
                    matchedKeyword = keyword
                    break
                }
            }

            guard let keyword = matchedKeyword else { continue }

            let targetFolder = baseTargetFolder.appendingPathComponent(keyword.category).appendingPathComponent(keyword.subfolder)
            try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)

            var destination = targetFolder.appendingPathComponent(item.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                destination = targetFolder.appendingPathComponent("\(timestamp)_\(item.lastPathComponent)")
            }

            try? FileManager.default.moveItem(at: item, to: destination)
        }
    }

    static func chooseSourceFolder() -> URL? {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        return dialog.runModal() == .OK ? dialog.url : nil
    }
}
