import Foundation

enum AppIdentity {
    static let displayName = "AgentMeter"
    static let bundleIdentifier = "com.erik5000.AgentMeter"
    static let testBundleIdentifier = "com.erik5000.AgentMeterTests"
    static let loggerSubsystem = "com.erik5000.AgentMeter"
    static let keychainService = "com.erik5000.AgentMeter.sessionkey"
    static let legacyKeychainServices = ["com.claudemeter.sessionkey"]
    static let appSupportDirectoryName = "com.erik5000.AgentMeter"
    static let publicExportDirectoryName = ".agentmeter"
    static let githubURL = URL(string: "https://github.com/Erik5000/AgentMeter")!
    static let codexClientName = "agentmeter"
    static let copyrightLine = "© 2025 Edd Mann · © 2026 Erik Biebinger"
    static let tagline = "Monitor Claude and Codex usage limits"
    static let forkAttribution = "Fork of ClaudeMeter by Edd Mann"
    static let notificationUsageDescription =
        "AgentMeter sends notifications when Claude session usage approaches warning or critical thresholds and when a usage window resets."
}
