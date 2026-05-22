import XCTest
@testable import FileOrganizerApp

final class SubjectLocationTests: XCTestCase {

    private func profile(name: String = "Mrinal Thigale", region: String = "California") -> UserProfile {
        var p = UserProfile(
            fullName: name,
            nameAliases: ["Mrinal", "Thigale", "MrinalThigale"],
            homeRegion: region,
            enableSubjectFolders: true
        )
        p.syncDerivedFields()
        return p
    }

    private func metadata(fileName: String, preview: String? = nil) -> FileMetadata {
        FileMetadata(
            fileName: fileName,
            fileExtension: (fileName as NSString).pathExtension,
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
            contentPreview: preview,
            hasTextContent: preview != nil,
            siblingFiles: nil,
            folderDepth: 1,
            commonPatterns: [],
            isProjectDirectory: false,
            hasTemporalName: false,
            detectedIntent: nil,
            author: nil,
            keywords: nil,
            whereFrom: nil
        )
    }

    func testMineFileFlatPathWhenDefaultRegion() {
        let p = profile()
        let meta = metadata(fileName: "MrinalThigale-Resume.docx")
        let subject = SubjectResolver(profile: p).resolve(meta)
        XCTAssertEqual(subject.ownership, .mine)

        let location = LocationResolver(profile: p).resolve(meta, subject: subject)
        XCTAssertNil(location.pathRegionSegment)

        let dest = OrganizeDestination(
            classification: ClassificationResult(category: "Career", subfolder: "Resumes", confidence: 0.9, method: .fallback),
            subject: subject,
            location: location
        )
        XCTAssertEqual(dest.relativePath(profile: p), "Career/Resumes")
    }

    func testOtherPersonUnderOthers() {
        let p = profile()
        let known = [KnownPerson(displayName: "Jon Richardson", matchTokens: ["richardson", "jon-paul"])]
        let meta = metadata(fileName: "RICHARDSON, JON-PAUL - 2023.xlsm")
        let subject = SubjectResolver(profile: p, knownPeople: known).resolve(meta)
        XCTAssertEqual(subject.ownership, .other)
        XCTAssertEqual(subject.subjectSlug, "Jon Richardson")

        let location = LocationResolver(profile: p, knownPeople: known).resolve(meta, subject: subject)
        let dest = OrganizeDestination(
            classification: ClassificationResult(category: "Career", subfolder: "Work", confidence: 0.9, method: .fallback),
            subject: subject,
            location: location
        )
        XCTAssertEqual(dest.relativePath(profile: p), "Others/Jon Richardson/Career/Work")
    }

    func testNonDefaultRegionSegment() {
        let p = profile(region: "California")
        let meta = metadata(
            fileName: "visa.pdf",
            preview: "Consulate General of India, San Francisco"
        )
        let subject = SubjectResolver(profile: p).resolve(meta)
        let location = LocationResolver(profile: p).resolve(meta, subject: subject)
        XCTAssertEqual(location.detectedRegionSlug, "India")
        XCTAssertEqual(location.pathRegionSegment, "India")

        let dest = OrganizeDestination(
            classification: ClassificationResult(category: "Legal", subfolder: "Immigration", confidence: 0.9, method: .fallback),
            subject: subject,
            location: location
        )
        XCTAssertEqual(dest.relativePath(profile: p), "India/Legal/Immigration")
    }

    func testCaliforniaDetectedOmitsPathSegment() {
        let p = profile(region: "California")
        let meta = metadata(
            fileName: "GSI Grievance_jon_paul.pdf",
            preview: "STATE OF CALIFORNIA Employment Development"
        )
        let known = [KnownPerson(displayName: "Jon Richardson", matchTokens: ["jon_paul", "jon-paul"])]
        let subject = SubjectResolver(profile: p, knownPeople: known).resolve(meta)
        let location = LocationResolver(profile: p, knownPeople: known).resolve(meta, subject: subject)
        XCTAssertEqual(location.detectedRegionSlug, "California")
        XCTAssertNil(location.pathRegionSegment)
    }

    func testEstateNameExtraction() {
        let p = profile()
        let meta = metadata(fileName: "(Neelmani_Singh_Estate_2022)_Tax_Relief.zip")
        let subject = SubjectResolver(profile: p).resolve(meta)
        XCTAssertEqual(subject.ownership, .other)
        XCTAssertTrue(subject.primarySubjectName?.contains("Neelmani") ?? false)
    }
}
