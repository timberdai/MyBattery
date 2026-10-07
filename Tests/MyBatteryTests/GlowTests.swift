import XCTest
import AppKit
final class GlowTests: XCTestCase {
    func testWindowLifecycle() throws {
        guard ProcessInfo.processInfo.environment["MYBATTERY_UI_TESTS"] == "1" else {
            throw XCTSkip("Use MYBATTERY_UI_TESTS=1 on a desktop, or scripts/run-round2-tests.sh --glow")
        }
        let run = { runGlowRound2 { passed, name in XCTAssertTrue(passed, name) } }
        if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
    }
}
