import XCTest
final class SMCTests: XCTestCase {
    func testReadOnlyAndBoundaries() {
        runSMCRound2 { passed, name in XCTAssertTrue(passed, name) }
    }
}
