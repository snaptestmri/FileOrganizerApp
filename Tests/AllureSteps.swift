import XCTest

/// Helpers for Allure-compatible test steps via `XCTContext.runActivity`.
///
/// Allure Report 3 reads `.xcresult` bundles produced by `xcodebuild test` and maps
/// each activity to a report step with pass/fail status and attachments.
enum AllureStep {
    /// Runs a synchronous step that appears in the Allure report.
    @discardableResult
    static func run<T>(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> T
    ) rethrows -> T {
        var value: T!
        try XCTContext.runActivity(named: name) { _ in
            value = try block()
        }
        return value
    }

    /// Runs a synchronous step and attaches a text summary of the result.
    @discardableResult
    static func run<T>(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> T,
        resultDescription: @escaping (T) -> String
    ) rethrows -> T {
        var value: T!
        try XCTContext.runActivity(named: name) { activity in
            value = try block()
            attach(text: resultDescription(value), name: "Step result", to: activity)
        }
        return value
    }

    /// Runs an async step that appears in the Allure report.
    ///
    /// Async work runs off the main actor; the Allure activity is recorded on the main
    /// actor afterward so XCTest does not deadlock.
    @discardableResult
    static func runAsync<T>(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: @escaping () async throws -> T
    ) async throws -> T {
        do {
            let value = try await block()
            await recordStep(name)
            return value
        } catch {
            await recordStep("\(name) — failed")
            throw error
        }
    }

    /// Runs an async step and attaches a text summary of the result.
    @discardableResult
    static func runAsync<T>(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: @escaping () async throws -> T,
        resultDescription: @escaping (T) -> String
    ) async throws -> T {
        let describe = resultDescription
        do {
            let value = try await block()
            await recordStep(name, resultText: describe(value))
            return value
        } catch {
            await recordStep("\(name) — failed")
            throw error
        }
    }

    /// Attaches text output to the current test case (visible in Allure attachments).
    static func attach(
        text: String,
        name: String = "Attachment",
        lifetime: XCTAttachment.Lifetime = .keepAlways,
        to testCase: XCTestCase
    ) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = lifetime
        testCase.add(attachment)
    }

    @MainActor
    private static func recordStep(_ name: String, resultText: String? = nil) {
        XCTContext.runActivity(named: name) { activity in
            if let resultText {
                attach(text: resultText, name: "Step result", to: activity)
            }
        }
    }

    private static func attach(text: String, name: String, to activity: XCTActivity) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        activity.add(attachment)
    }
}
