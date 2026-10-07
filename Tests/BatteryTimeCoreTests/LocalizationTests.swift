import XCTest

final class LocalizationTests: XCTestCase {
    func testAutomaticLanguageAndFormatters() {
        runLocalizationCases { passed, name in XCTAssertTrue(passed, name) }
    }
}
