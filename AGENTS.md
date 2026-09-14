AgentMeter is a macOS 14+ SwiftUI menu bar app (fork of ClaudeMeter) that tracks Claude and Codex usage; keep UI state on `@MainActor @Observable` types and non-UI work in actor services/repositories.

Build with `xcodebuild clean build -project AgentMeter.xcodeproj -scheme AgentMeter -configuration Debug`; test with `xcodebuild test -project AgentMeter.xcodeproj -scheme AgentMeter -configuration Debug`.

New `AppSettings` keys must persist through `SettingsRepository`, appear in `SettingsView` when user-facing, and decode old saved settings safely.
