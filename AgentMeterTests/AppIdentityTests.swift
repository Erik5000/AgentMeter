import XCTest
@testable import AgentMeter

final class AppIdentityTests: XCTestCase {
    func test_displayName_isAgentMeter() {
        XCTAssertEqual(AppIdentity.displayName, "AgentMeter")
    }

    func test_bundleIdentifiers_areErik5000AgentMeter() {
        XCTAssertEqual(AppIdentity.bundleIdentifier, "com.erik5000.AgentMeter")
        XCTAssertEqual(AppIdentity.testBundleIdentifier, "com.erik5000.AgentMeterTests")
    }

    func test_pathsAndKeychain_doNotUseClaudeMeterIds() {
        XCTAssertEqual(AppIdentity.loggerSubsystem, "com.erik5000.AgentMeter")
        XCTAssertEqual(AppIdentity.keychainService, "com.erik5000.AgentMeter.sessionkey")
        XCTAssertEqual(AppIdentity.appSupportDirectoryName, "com.erik5000.AgentMeter")
        XCTAssertEqual(AppIdentity.publicExportDirectoryName, ".agentmeter")
        XCTAssertFalse(AppIdentity.publicExportDirectoryName.contains("claude"))
        XCTAssertFalse(AppIdentity.keychainService.contains("claudemeter"))
    }

    func test_githubAndCodexClient_matchFork() {
        XCTAssertEqual(AppIdentity.githubURL.absoluteString, "https://github.com/Erik5000/AgentMeter")
        XCTAssertEqual(AppIdentity.codexClientName, "agentmeter")
        XCTAssertEqual(AppIdentity.copyrightLine, "© 2025 Edd Mann · © 2026 Erik Biebinger")
        XCTAssertEqual(AppIdentity.tagline, "Monitor Claude and Codex usage limits")
        XCTAssertEqual(AppIdentity.forkAttribution, "Fork of ClaudeMeter by Edd Mann")
        XCTAssertTrue(AppIdentity.notificationUsageDescription.contains("Claude"))
        XCTAssertFalse(AppIdentity.notificationUsageDescription.localizedCaseInsensitiveContains("Codex"))
    }
}
