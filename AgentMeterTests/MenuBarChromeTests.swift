import XCTest
@testable import AgentMeter

final class MenuBarChromeTests: XCTestCase {
    func test_quitTitle_includesAppName() {
        XCTAssertEqual(MenuBarChrome.quitTitle, "Quit AgentMeter")
    }
}
