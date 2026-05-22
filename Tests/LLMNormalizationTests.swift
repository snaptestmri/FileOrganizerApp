import XCTest
@testable import FileOrganizerApp

final class LLMNormalizationTests: XCTestCase {

    private func metadata(
        fileName: String,
        ext: String,
        intent: String? = nil,
        hasTemporal: Bool = false,
        siblings: [String]? = nil
    ) -> FileMetadata {
        FileMetadata(
            fileName: fileName,
            fileExtension: ext,
            fileNameWithoutExtension: (fileName as NSString).deletingPathExtension,
            fullPath: nil,
            parentFolder: "Downloads",
            fileSize: 1000,
            fileSizeFormatted: "1 KB",
            creationDate: nil,
            modificationDate: nil,
            fileType: nil,
            mimeType: nil,
            isDirectory: false,
            isHidden: false,
            isPackage: false,
            contentPreview: nil,
            hasTextContent: false,
            siblingFiles: siblings,
            folderDepth: 1,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: hasTemporal,
            detectedIntent: intent,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
    }

    private func normalize(
        category: String,
        subfolder: String,
        fileName: String,
        ext: String,
        intent: String? = nil,
        confidence: Double = 0.99
    ) -> ClassificationResult {
        let result = ClassificationResult(
            category: category,
            subfolder: subfolder,
            confidence: confidence,
            reasoning: "test",
            method: .llm
        )
        return ClassificationConstants.normalizeLLMClassification(
            result,
            metadata: metadata(fileName: fileName, ext: ext, intent: intent),
            mode: .personalDomain
        )
    }

    func testMediaCSSBecomesProjectsCode() {
        let out = normalize(category: "Media", subfolder: "CSS", fileName: "lucy.css", ext: "css")
        XCTAssertEqual(out.category, "Projects")
        XCTAssertEqual(out.subfolder, "Code")
    }

    func testLegalDocumentsInventedSubfolder() {
        let out = normalize(category: "Personal", subfolder: "Legal Documents", fileName: "DOC_20250404_0001.pdf", ext: "pdf")
        XCTAssertEqual(out.category, "Legal")
        XCTAssertEqual(out.subfolder, "Contracts")
    }

    func testIdentityWithoutSignalsBecomesGeneral() {
        let out = normalize(
            category: "Personal",
            subfolder: "Identity",
            fileName: "Avaya Reference Letter 2016-2023.docx",
            ext: "docx",
            intent: "offer_letter"
        )
        XCTAssertEqual(out.category, "Career")
        XCTAssertEqual(out.subfolder, "Work")
    }

    func testEStmtTaxesBecomesBankStatements() {
        let out = normalize(category: "Finance", subfolder: "Taxes", fileName: "eStmt_2024-06-05.pdf", ext: "pdf")
        XCTAssertEqual(out.category, "Finance")
        XCTAssertEqual(out.subfolder, "Bank Statements")
    }

    func testFalseScreenshotZipBecomesScaffoldOrIntent() {
        let out = normalize(
            category: "Media",
            subfolder: "Screenshots",
            fileName: "AppIcons.zip",
            ext: "zip",
            confidence: 0.97
        )
        XCTAssertNotEqual(out.category, "Media")
        XCTAssertNotEqual(out.subfolder, "Screenshots")
    }

    func testJarInAppsBecomesCode() {
        let out = normalize(category: "Projects", subfolder: "Apps", fileName: "tomcat-util.jar", ext: "jar")
        XCTAssertEqual(out.category, "Projects")
        XCTAssertEqual(out.subfolder, "Code")
    }

    func testMatchesTaxFilename() {
        XCTAssertTrue(ClassificationConstants.matchesTaxFilename("Taxes2023.zip"))
        XCTAssertFalse(ClassificationConstants.matchesTaxFilename("eStmt_2024-06-05.pdf"))
    }

    func testMatchesBankStatementFilename() {
        XCTAssertTrue(ClassificationConstants.matchesBankStatementFilename("Pay Date 2024-07-19.pdf"))
    }

    func testLegacyEducationCategoryFoldsIntoCareer() {
        let out = normalize(category: "Education", subfolder: "PM Courses", fileName: "Intro to Prompt Engineering.docx", ext: "docx")
        XCTAssertEqual(out.category, "Career")
        XCTAssertEqual(out.subfolder, "PM Courses")
    }
}
