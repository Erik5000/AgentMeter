import AppKit
import XCTest
@testable import AgentMeter

final class StatusItemClickActionTests: XCTestCase {
    func test_leftClick_togglesPopover() {
        XCTAssertEqual(StatusItemClickAction.from(eventType: .leftMouseUp), .togglePopover)
    }

    func test_rightClick_showsMenu() {
        XCTAssertEqual(StatusItemClickAction.from(eventType: .rightMouseUp), .showMenu)
    }
}
