import XCTest

final class Round2Tests: XCTestCase {
    func testCoreRegression() {
        runCoreRound2 { passed, name in XCTAssertTrue(passed, name) }
    }
}
