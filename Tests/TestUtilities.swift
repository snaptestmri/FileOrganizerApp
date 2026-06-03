import Foundation
@testable import FileOrganizerApp

// MARK: - Shared Test Utilities

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

extension KeywordStore {
    /// Empty in-memory store for unit tests (does not read/write ~/Documents JSON).
    static func isolatedForTests() -> KeywordStore {
        KeywordStore(loadFromDisk: false)
    }
}

extension MockLLMService {
    /// Mock with no artificial network delay (for faster tests).
    static func fast() -> MockLLMService {
        let mock = MockLLMService()
        mock.delay = 0
        return mock
    }

    /// Mock that fails immediately with no artificial delay (for fast integration tests).
    static func failingInstantly() -> MockLLMService {
        let mock = fast()
        mock.shouldFail = true
        return mock
    }
}

extension FileMetadata {
    /// Builds test metadata with personal-domain signal defaults.
    static func forTest(
        fileName: String,
        fileExtension: String,
        fileNameWithoutExtension: String? = nil,
        fullPath: String? = nil,
        parentFolder: String? = nil,
        fileSize: Int64 = 1024,
        fileSizeFormatted: String = "1 KB",
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        fileType: String? = nil,
        mimeType: String? = nil,
        isDirectory: Bool = false,
        isHidden: Bool = false,
        isPackage: Bool = false,
        contentPreview: String? = nil,
        hasTextContent: Bool = false,
        siblingFiles: [String]? = nil,
        folderDepth: Int = 0,
        commonPatterns: [String] = [],
        isProjectDirectory: Bool = false,
        hasTemporalName: Bool = false,
        detectedIntent: String? = nil,
        author: String? = nil,
        keywords: [String]? = nil,
        whereFrom: String? = nil
    ) -> FileMetadata {
        FileMetadata(
            fileName: fileName,
            fileExtension: fileExtension,
            fileNameWithoutExtension: fileNameWithoutExtension ?? (fileName as NSString).deletingPathExtension,
            fullPath: fullPath,
            parentFolder: parentFolder,
            fileSize: fileSize,
            fileSizeFormatted: fileSizeFormatted,
            creationDate: creationDate,
            modificationDate: modificationDate,
            fileType: fileType,
            mimeType: mimeType,
            isDirectory: isDirectory,
            isHidden: isHidden,
            isPackage: isPackage,
            contentPreview: contentPreview,
            hasTextContent: hasTextContent,
            siblingFiles: siblingFiles,
            folderDepth: folderDepth,
            commonPatterns: commonPatterns,
            isProjectDirectory: isProjectDirectory,
            hasTemporalName: hasTemporalName,
            detectedIntent: detectedIntent,
            author: author,
            keywords: keywords,
            whereFrom: whereFrom
        )
    }
}
