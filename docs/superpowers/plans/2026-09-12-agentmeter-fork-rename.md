# AgentMeter Fork & Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move this working tree onto a GitHub repo we own (`Erik5000/AgentMeter`), land the existing Codex usage work there, then change product identity so the app is AgentMeter without colliding with ClaudeMeter.

**Architecture:** Keep Edd Mann’s git history. `upstream` = `eddmann/ClaudeMeter` (never push). `origin` = `Erik5000/AgentMeter`. Centralize product strings in `AppIdentity`. Change bundle ID, Keychain, cache paths, display name, and `PRODUCT_NAME` to AgentMeter while leaving the Swift module named `ClaudeMeter`.

**Tech Stack:** Git, GitHub CLI (`gh`), Xcode / `xcodebuild`, Swift, SwiftUI, macOS 14+

**Spec:** `docs/superpowers/specs/2026-09-12-agentmeter-fork-rename-design.md`

## Global Constraints

- Product name is **AgentMeter**; GitHub repo is **Erik5000/AgentMeter** (public).
- App bundle ID is `com.erik5000.AgentMeter`; tests `com.erik5000.AgentMeterTests`.
- Swift module stays `ClaudeMeter` (`PRODUCT_MODULE_NAME = ClaudeMeter`); `@testable import ClaudeMeter` stays.
- Built app is `AgentMeter.app` (`PRODUCT_NAME = AgentMeter` on the app target).
- MIT: keep `Copyright (c) 2025 Edd Mann`; add `Copyright (c) 2026 Erik Biebinger`.
- Never `git push upstream` or open a PR to `eddmann/ClaudeMeter`.
- Do not stage `docs/heading.png` unless Erik asks.
- Do not rename `ClaudeMeter.xcodeproj`, scheme name, source folders, `ClaudeMeterApp`, or file headers.
- Do not implement remaining-capacity-alert.
- Do not enable Homebrew tap updates or GitHub Pages for Edd’s `site/`.
- Clear `DEVELOPMENT_TEAM = ANGUD7343N` unless Erik supplies a replacement team ID.
- Build/test: `xcodebuild` with `-project ClaudeMeter.xcodeproj -scheme ClaudeMeter -configuration Debug` and `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`.
- Every task’s requirements implicitly include this section.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| git remotes | `upstream` Edd, `origin` Erik | Rename/add; push history |
| Codex usage files (already implemented) | Claude + Codex meters | Commit to origin only |
| `ClaudeMeter/Models/AppIdentity.swift` | Single source of product identity | Create |
| `ClaudeMeterTests/AppIdentityTests.swift` | Lock IDs/paths so they cannot revert | Create |
| `ClaudeMeter/Models/Constants.swift` | Unrelated app constants | Unchanged |
| `ClaudeMeter/Repositories/CacheRepository.swift` | Disk cache + `~/.agentmeter/usage.json` | Use `AppIdentity` |
| `ClaudeMeter/Repositories/KeychainRepository.swift` | Session Keychain service/group | Use `AppIdentity` |
| `ClaudeMeter/Resources/ClaudeMeter.entitlements` | Keychain access group | New group |
| `ClaudeMeter.xcodeproj/project.pbxproj` | Bundle IDs, display name, product name, TEST_HOST, team | Identity only |
| `ClaudeMeter.xcodeproj/xcshareddata/xcschemes/ClaudeMeter.xcscheme` | `BuildableName` → `AgentMeter.app` | Product filename |
| Loggers + Codex clientInfo | Runtime identity | Use `AppIdentity` |
| User-facing SwiftUI / Info.plist | Visible name and About | AgentMeter copy |
| `LICENSE`, `README.md`, `CLAUDE.md`, `AGENTS.md`, `CHANGELOG.md` | Attribution and docs | Fork wording |
| `.github/workflows/test.yml` | CI tests | Keep scheme; unsigned |
| `.github/workflows/release.yml` | Must not touch Edd’s tap | Strip tap; AgentMeter zip name |
| `.github/workflows/deploy-pages.yml` | Would publish Edd’s site | Delete |

---

### Task 1: Create GitHub repo and retarget remotes

**Files:**
- Modify: git remotes only (no source changes)

**Interfaces:**
- Consumes: GitHub auth as `Erik5000`; current clone of `eddmann/ClaudeMeter`
- Produces: `origin` → `Erik5000/AgentMeter`; `upstream` → `eddmann/ClaudeMeter`; `main` pushed to origin

- [ ] **Step 1: Confirm GitHub user and that the repo name is free**

Run:

```bash
gh api user --jq .login
gh repo view Erik5000/AgentMeter --json name 2>&1 || true
```

Expected: login is `Erik5000`. `gh repo view` fails with “not found” (name is free). If the repo already exists, **stop** and ask Erik.

- [ ] **Step 2: Create the public repo with no seed files**

Run:

```bash
gh repo create AgentMeter \
  --public \
  --description "macOS menu bar app for Claude and Codex usage limits (fork of ClaudeMeter)" \
  --disable-wiki
```

Expected: `https://github.com/Erik5000/AgentMeter` created. Do **not** pass `--clone`, `--add-readme`, or `.gitignore` (those would block pushing existing history).

- [ ] **Step 3: Retarget remotes**

From `/Users/erik/Developer/ideas/ClaudeMeter`:

```bash
git remote rename origin upstream
git remote add origin https://github.com/Erik5000/AgentMeter.git
git remote -v
```

Expected:

```
origin    https://github.com/Erik5000/AgentMeter.git (fetch)
origin    https://github.com/Erik5000/AgentMeter.git (push)
upstream  https://github.com/eddmann/ClaudeMeter.git (fetch)
upstream  https://github.com/eddmann/ClaudeMeter.git (push)
```

Leave `upstream` push URL as-is; the rule is never to use it. Do not `git remote set-url --push upstream` unless Erik wants a dummy URL.

- [ ] **Step 4: Push ClaudeMeter history to origin `main`**

```bash
git push -u origin main
```

Expected: `main` on `Erik5000/AgentMeter` matches local `main` (`da44a40` at plan time). **Do not** `git push upstream`.

- [ ] **Step 5: Record default branch**

```bash
gh repo view Erik5000/AgentMeter --json name,url,defaultBranchRef,isPrivate
```

Expected: `isPrivate` false, `defaultBranchRef` `main`, url `https://github.com/Erik5000/AgentMeter`.

No source commit in this task.

---

### Task 2: Land existing Codex usage work on origin

**Files:**
- Existing dirty Codex/layout files only (see step 2). Do **not** include `docs/heading.png`.

**Interfaces:**
- Consumes: Uncommitted Codex integration already in the working tree
- Produces: A commit on a branch pushed to `origin` (not `upstream`)

- [ ] **Step 1: Confirm tests still pass on the dirty tree**

Run:

```bash
xcodebuild test \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Debug \
  -skip-testing:ClaudeMeterTests/MenuBarIconSnapshotTests \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `TEST SUCCEEDED`. If not, fix Codex work before forking identity; do not mix debug with rename.

- [ ] **Step 2: Commit only Codex usage files**

```bash
git add \
  ClaudeMeter/App/AppModel.swift \
  ClaudeMeter/App/ClaudeMeterApp.swift \
  ClaudeMeter/Models/AppSettings.swift \
  ClaudeMeter/Models/CodexUsageData.swift \
  ClaudeMeter/Models/IconStyle.swift \
  ClaudeMeter/Models/MenuBarUsageSnapshot.swift \
  ClaudeMeter/Models/UsageLimit.swift \
  ClaudeMeter/Models/UsageStatus.swift \
  ClaudeMeter/Services/CodexUsageService.swift \
  ClaudeMeter/Services/Protocols/CodexUsageServiceProtocol.swift \
  ClaudeMeter/Utilities/DemoDataFactory.swift \
  ClaudeMeter/Views/MenuBar/IconCache.swift \
  ClaudeMeter/Views/MenuBar/IconStyles/DualBarIcon.swift \
  ClaudeMeter/Views/MenuBar/MenuBarIconRenderer.swift \
  ClaudeMeter/Views/MenuBar/MenuBarIconView.swift \
  ClaudeMeter/Views/MenuBar/MenuBarManager.swift \
  ClaudeMeter/Views/MenuBar/UsageComparisonCardView.swift \
  ClaudeMeter/Views/MenuBar/UsagePopoverView.swift \
  ClaudeMeter/Views/Settings/IconStylePicker.swift \
  ClaudeMeter/Views/Settings/SettingsView.swift \
  ClaudeMeterTests/AppModelTests.swift \
  ClaudeMeterTests/CodexUsageServiceTests.swift \
  ClaudeMeterTests/MenuBarIconRendererTests.swift \
  ClaudeMeterTests/MenuBarUsageSnapshotTests.swift \
  ClaudeMeterTests/SettingsRepositoryTests.swift \
  ClaudeMeterTests/UsageLimitRiskTests.swift \
  ClaudeMeterTests/TestDoubles/CodexUsageServiceStub.swift

git status
git commit -m "$(cat <<'EOF'
Add Codex usage alongside Claude in the menu bar and popover.

Fetch Codex rate limits from the local app server and show session/weekly
comparison cards plus a 2x2 Dual Bar icon so both products stay visible.
EOF
)"
```

Expected: `docs/heading.png` is **not** in the commit. `git status` after commit may still show `D docs/heading.png`.

- [ ] **Step 3: Push the Codex branch to origin only**

Current HEAD is `feature/remaining-capacity-alert`. Rename the working branch so origin is not branded as an unfinished spec:

```bash
git branch -m feature/codex-usage
git push -u origin feature/codex-usage
```

Expected: `origin/feature/codex-usage` exists. `git push upstream` is **not** run.

---

### Task 3: Add `AppIdentity` with failing tests first

**Files:**
- Create: `ClaudeMeterTests/AppIdentityTests.swift`
- Create: `ClaudeMeter/Models/AppIdentity.swift`

**Interfaces:**
- Consumes: Locked table in the spec
- Produces:

```swift
enum AppIdentity {
    static let displayName: String
    static let bundleIdentifier: String
    static let testBundleIdentifier: String
    static let loggerSubsystem: String
    static let keychainService: String
    static let keychainAccessGroup: String
    static let appSupportDirectoryName: String
    static let publicExportDirectoryName: String
    static let githubURL: URL
    static let codexClientName: String
    static let copyrightLine: String
    static let tagline: String
}
```

- [ ] **Step 1: Write the failing tests**

Create `ClaudeMeterTests/AppIdentityTests.swift`:

```swift
import XCTest
@testable import ClaudeMeter

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
        XCTAssertEqual(
            AppIdentity.keychainAccessGroup,
            "$(AppIdentifierPrefix)com.erik5000.AgentMeter"
        )
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
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Debug \
  -only-testing:ClaudeMeterTests/AppIdentityTests \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Expected: FAIL — `AppIdentity` is not defined. (The project uses a synchronized root group, so new files under `ClaudeMeter/` and `ClaudeMeterTests/` are picked up automatically.)

- [ ] **Step 3: Add the minimal type**

Create `ClaudeMeter/Models/AppIdentity.swift`:

```swift
import Foundation

enum AppIdentity {
    static let displayName = "AgentMeter"
    static let bundleIdentifier = "com.erik5000.AgentMeter"
    static let testBundleIdentifier = "com.erik5000.AgentMeterTests"
    static let loggerSubsystem = "com.erik5000.AgentMeter"
    static let keychainService = "com.erik5000.AgentMeter.sessionkey"
    static let keychainAccessGroup = "$(AppIdentifierPrefix)com.erik5000.AgentMeter"
    static let appSupportDirectoryName = "com.erik5000.AgentMeter"
    static let publicExportDirectoryName = ".agentmeter"
    static let githubURL = URL(string: "https://github.com/Erik5000/AgentMeter")!
    static let codexClientName = "agentmeter"
    static let copyrightLine = "© 2025 Edd Mann · © 2026 Erik Biebinger"
    static let tagline = "Monitor Claude and Codex usage limits"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Same `xcodebuild test ... -only-testing:ClaudeMeterTests/AppIdentityTests` as Step 2.

Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add ClaudeMeter/Models/AppIdentity.swift ClaudeMeterTests/AppIdentityTests.swift
git commit -m "$(cat <<'EOF'
Add AppIdentity so product name and bundle IDs live in one place.

Locks AgentMeter naming before wiring caches, Keychain, and UI copy.
EOF
)"
```

---

### Task 4: Wire identity into storage, signing, and the built product

**Files:**
- Modify: `ClaudeMeter/Repositories/CacheRepository.swift`
- Modify: `ClaudeMeter/Repositories/KeychainRepository.swift`
- Modify: `ClaudeMeter/Resources/ClaudeMeter.entitlements`
- Modify: `ClaudeMeter/Services/UsageService.swift` (logger subsystem)
- Modify: `ClaudeMeter/Services/NetworkService.swift` (logger subsystem)
- Modify: `ClaudeMeter/Services/SessionKeyImportService.swift` (logger subsystem)
- Modify: `ClaudeMeter/Services/CodexUsageService.swift` (clientInfo)
- Modify: `ClaudeMeter.xcodeproj/project.pbxproj`
- Modify: `ClaudeMeter.xcodeproj/xcshareddata/xcschemes/ClaudeMeter.xcscheme`

**Interfaces:**
- Consumes: `AppIdentity` from Task 3
- Produces: Runtime paths/IDs and `AgentMeter.app` that do not collide with ClaudeMeter

- [ ] **Step 1: Point cache and Keychain at AppIdentity**

In `CacheRepository.init`, replace hardcoded folder names:

```swift
let cacheDir = appSupport.appendingPathComponent(
    AppIdentity.appSupportDirectoryName,
    isDirectory: true
)
let publicDir = homeDir.appendingPathComponent(
    AppIdentity.publicExportDirectoryName,
    isDirectory: true
)
```

In `KeychainRepository`, replace stored strings:

```swift
private let serviceName = AppIdentity.keychainService
private let accessGroup = AppIdentity.keychainAccessGroup
```

- [ ] **Step 2: Point loggers and Codex clientInfo at AppIdentity**

Replace `Logger(subsystem: "com.claudemeter", ...)` in `UsageService.swift`, `NetworkService.swift`, and `SessionKeyImportService.swift` with:

```swift
Logger(subsystem: AppIdentity.loggerSubsystem, category: "...")
```

Keep each file’s existing `category` string.

In `CodexUsageService.swift` `clientInfo`:

```swift
"name": AppIdentity.codexClientName,
"title": AppIdentity.displayName,
```

- [ ] **Step 3: Update entitlements**

`ClaudeMeter/Resources/ClaudeMeter.entitlements` keychain-access-groups entry becomes:

```xml
<string>$(AppIdentifierPrefix)com.erik5000.AgentMeter</string>
```

- [ ] **Step 4: Update Xcode identity (both Debug and Release)**

In `ClaudeMeter.xcodeproj/project.pbxproj`:

App target Debug **and** Release (`INFOPLIST_KEY_CFBundleDisplayName` blocks):

```
INFOPLIST_KEY_CFBundleDisplayName = AgentMeter;
PRODUCT_BUNDLE_IDENTIFIER = com.erik5000.AgentMeter;
PRODUCT_NAME = AgentMeter;
PRODUCT_MODULE_NAME = ClaudeMeter;
DEVELOPMENT_TEAM = "";
```

Leave `DEVELOPMENT_TEAM` empty unless Erik provided a team ID. Remove `ANGUD7343N` from **all** configurations (app + tests).

Test target Debug **and** Release:

```
PRODUCT_BUNDLE_IDENTIFIER = com.erik5000.AgentMeterTests;
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AgentMeter.app/Contents/MacOS/AgentMeter";
DEVELOPMENT_TEAM = "";
```

Do not rename `PBXNativeTarget` `name = ClaudeMeter` or the `.xcodeproj` filename.

- [ ] **Step 5: Update the shared scheme product filename**

In `ClaudeMeter.xcodeproj/xcshareddata/xcschemes/ClaudeMeter.xcscheme`, the three `BuildableName = "ClaudeMeter.app"` entries (build / run / profile-archive) become `BuildableName = "AgentMeter.app"`. Leave `BuildableName = "ClaudeMeterTests.xctest"`, `BlueprintName = ClaudeMeter`, and `ReferencedContainer = container:ClaudeMeter.xcodeproj`.

- [ ] **Step 6: Grep for leftover runtime IDs, then test**

```bash
rg -n "com\\.claudemeter|com\\.eddmann\\.ClaudeMeter|~/.claudemeter" \
  --glob '!docs/**' --glob '!site/**' --glob '!README.md' --glob '!CHANGELOG.md' \
  --glob '!LICENSE' --glob '!.github/workflows/release.yml'
```

Expected: no matches in Swift/plist/entitlements/pbxproj except comments/`//  ClaudeMeter` file headers (those stay). `site/` and README are later tasks.

Run full test command from Task 2 Step 1.

Expected: `TEST SUCCEEDED`. Confirm the built product path contains `AgentMeter.app` (xcodebuild log `Touch .../AgentMeter.app`).

- [ ] **Step 7: Commit**

```bash
git add ClaudeMeter/Repositories/CacheRepository.swift \
  ClaudeMeter/Repositories/KeychainRepository.swift \
  ClaudeMeter/Resources/ClaudeMeter.entitlements \
  ClaudeMeter/Services/UsageService.swift \
  ClaudeMeter/Services/NetworkService.swift \
  ClaudeMeter/Services/SessionKeyImportService.swift \
  ClaudeMeter/Services/CodexUsageService.swift \
  ClaudeMeter.xcodeproj/project.pbxproj \
  ClaudeMeter.xcodeproj/xcshareddata/xcschemes/ClaudeMeter.xcscheme
git commit -m "$(cat <<'EOF'
Use AgentMeter bundle ID, Keychain, and cache paths.

Stops the fork from colliding with ClaudeMeter if both apps run.
EOF
)"
```

---

### Task 5: User-visible copy

**Files:**
- Modify: `ClaudeMeter/Views/Settings/SettingsView.swift`
- Modify: `ClaudeMeter/Views/Setup/SetupWizardView.swift`
- Modify: `ClaudeMeter/Views/MenuBar/MenuBarManager.swift`
- Modify: `ClaudeMeter/App/SessionKeyImportPromptCoordinator.swift`
- Modify: `ClaudeMeter/Services/Protocols/SessionKeyImportServiceProtocol.swift`
- Modify: `ClaudeMeter/Resources/Info.plist`

**Interfaces:**
- Consumes: `AppIdentity.displayName`, `githubURL`, `copyrightLine`, `tagline`
- Produces: UI that says AgentMeter and links to Erik’s repo

- [ ] **Step 1: Settings, About, and setup**

`SettingsView` About section:

```swift
Text(AppIdentity.displayName)
Text(AppIdentity.copyrightLine)
Text(AppIdentity.tagline)
Link(destination: AppIdentity.githubURL) { ... Text("View Project on GitHub") ... }
```

Replace other user-facing `"ClaudeMeter"` in that file with `AppIdentity.displayName` (menu bar style caption, launch-at-login caption). Keep the visual layout.

`SetupWizardView`:

```swift
Text("Welcome to \(AppIdentity.displayName)")
Text("Setup complete! Launching \(AppIdentity.displayName)...")
```

- [ ] **Step 2: Menu bar accessibility and import prompts**

`MenuBarManager.swift`:

```swift
button.setAccessibilityLabel(AppIdentity.displayName)
```

`SessionKeyImportPromptCoordinator.swift` message:

```swift
"\(AppIdentity.displayName) will ask macOS Keychain for \"\(context.label)\" so it can decrypt your Claude browser session cookie.",
```

`SessionKeyImportServiceProtocol.swift` user-facing error:

```swift
return "\(AppIdentity.displayName) could not access browser cookies. Allow the macOS prompt or paste your session."
```

- [ ] **Step 3: Info.plist notification usage string**

Replace `NSUserNotificationsUsageDescription` with:

```xml
<string>AgentMeter sends notifications when Claude or Codex usage approaches warning or critical thresholds and when a usage window resets.</string>
```

- [ ] **Step 4: Grep UI copy, then test**

```bash
rg -n "ClaudeMeter" ClaudeMeter --glob '*.swift' --glob '*.plist'
```

Expected: remaining hits are file headers, `ClaudeMeterApp`, and type/module names only — no user-visible `"ClaudeMeter"` string literals.

Run full test command from Task 2 Step 1. Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add ClaudeMeter/Views/Settings/SettingsView.swift \
  ClaudeMeter/Views/Setup/SetupWizardView.swift \
  ClaudeMeter/Views/MenuBar/MenuBarManager.swift \
  ClaudeMeter/App/SessionKeyImportPromptCoordinator.swift \
  ClaudeMeter/Services/Protocols/SessionKeyImportServiceProtocol.swift \
  ClaudeMeter/Resources/Info.plist
git commit -m "$(cat <<'EOF'
Show AgentMeter in About, setup, and menu bar copy.

Points the GitHub link at the fork and mentions Claude and Codex.
EOF
)"
```

---

### Task 6: License, README, and agent docs

**Files:**
- Modify: `LICENSE`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: Identity table and MIT requirement from the spec
- Produces: Docs that describe AgentMeter as a fork, not Edd’s product

- [ ] **Step 1: LICENSE copyright lines**

Keep the MIT body. Change the copyright block to:

```
Copyright (c) 2025 Edd Mann
Copyright (c) 2026 Erik Biebinger
```

- [ ] **Step 2: README**

- Title `# AgentMeter`
- Opening paragraph: macOS menu bar app for **Claude and Codex** usage limits. One sentence: “Fork of [ClaudeMeter](https://github.com/eddmann/ClaudeMeter) by Edd Mann.”
- Remove the `docs/heading.png` banner (file is already deleted in the working tree and must not be restored for this pass).
- Installation: delete the Homebrew `eddmann/tap/claudemeter` section. Manual download links → `https://github.com/Erik5000/AgentMeter/releases`.
- Replace remaining `ClaudeMeter` product references with `AgentMeter` where they mean this app. Keep “Claude.ai” / Claude session import docs.
- Export path examples: `~/.agentmeter/usage.json`
- Clone snippet:

```bash
git clone https://github.com/Erik5000/AgentMeter.git
cd AgentMeter
open ClaudeMeter.xcodeproj
```

  (Folder on disk may still be `ClaudeMeter` locally; the clone URL and repo name are AgentMeter. The Xcode project filename stays `ClaudeMeter.xcodeproj` until the later structure pass.)
- Disclaimer: this app is not affiliated with Anthropic or OpenAI; session-cookie access may still violate Anthropic ToS (keep that warning).

- [ ] **Step 3: CLAUDE.md and AGENTS.md**

First sentence becomes: `AgentMeter is a macOS 14+ SwiftUI menu bar app (fork of ClaudeMeter) that tracks Claude and Codex usage; keep UI state on `@MainActor @Observable` types and non-UI work in actor services/repositories.`

Keep the same `xcodebuild` project/scheme names (`ClaudeMeter.xcodeproj`, scheme `ClaudeMeter`).

- [ ] **Step 4: CHANGELOG**

Insert at the top of `CHANGELOG.md` (keep existing ClaudeMeter history below):

```markdown
## [Unreleased]

### Changed
- Forked from ClaudeMeter; product name is AgentMeter.
- Tracks Codex usage alongside Claude.
- Cache export path is `~/.agentmeter/usage.json`.
```

- [ ] **Step 5: Commit**

```bash
git add LICENSE README.md CLAUDE.md AGENTS.md CHANGELOG.md
git commit -m "$(cat <<'EOF'
Document AgentMeter as a fork and keep Edd Mann's MIT notice.

Drops the upstream Homebrew tap and points clone/release URLs at this repo.
EOF
)"
```

---

### Task 7: Stop publishing Edd’s site and tap

**Files:**
- Delete: `.github/workflows/deploy-pages.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/test.yml` (only if a ClaudeMeter.app path is hardcoded; today it is not)

**Interfaces:**
- Consumes: `AgentMeter.app` product name from Task 4
- Produces: CI that tests this repo and cannot push to `eddmann/homebrew-tap`

- [ ] **Step 1: Delete Pages deploy**

Delete `.github/workflows/deploy-pages.yml`. Leave `site/` contents in git (Edd’s pages; rewriting is out of scope) but do not deploy them from this fork.

- [ ] **Step 2: Neutralize release.yml tap + names**

In `.github/workflows/release.yml`:

- `name: Release AgentMeter`
- Replace every `ClaudeMeter.app` path with `AgentMeter.app`
- Replace zip/release asset `ClaudeMeter-` with `AgentMeter-`
- Replace release title `ClaudeMeter v...` with `AgentMeter v...`
- **Delete** the entire “Update Homebrew tap” step (it clones `eddmann/homebrew-tap`). Do not point it at a new tap in this pass.
- Delete the notarization/`notarytool` steps. This repo has none of Edd’s Apple secrets; a dispatch must not try to notarize as ClaudeMeter.
- Keep `workflow_dispatch` so a later signing pass can restore notary. For this pass the job may build and attach `AgentMeter-<version>.zip` without notarizing.

- [ ] **Step 3: Confirm test.yml**

`.github/workflows/test.yml` must still use `-project ClaudeMeter.xcodeproj -scheme ClaudeMeter` and unsigned Debug flags. No `ClaudeMeter.app` path is in this file today — leave the xcodebuild invocation unchanged.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml .github/workflows/test.yml
git rm .github/workflows/deploy-pages.yml
git commit -m "$(cat <<'EOF'
Stop GitHub Pages and Homebrew tap publishes from the fork.

Release artifacts use the AgentMeter name and no longer update Edd's tap.
EOF
)"
```

---

### Task 8: Full verification and push to origin

**Files:** none new

**Interfaces:**
- Consumes: Tasks 1–7
- Produces: Green local tests; `origin/feature/codex-usage` contains identity work

- [ ] **Step 1: Grep leftover product identity**

```bash
rg -n "com\\.claudemeter|com\\.eddmann\\.ClaudeMeter|eddmann/tap|eddmann/homebrew-tap|~/.claudemeter" \
  --glob '!site/**' --glob '!docs/superpowers/**'
```

Expected: no matches except possibly historical CHANGELOG entries about ClaudeMeter the upstream project. `site/` may still mention Edd — allowed this pass.

- [ ] **Step 2: Run full tests and a Debug build**

```bash
xcodebuild test \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Debug \
  -skip-testing:ClaudeMeterTests/MenuBarIconSnapshotTests \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `TEST SUCCEEDED` and `BUILD SUCCEEDED`. Product `AgentMeter.app`.

- [ ] **Step 3: Push to origin only**

```bash
git remote -v
git push origin HEAD
```

Expected: `origin` is `Erik5000/AgentMeter`. Confirm the push URL is **not** `eddmann/ClaudeMeter`.

Do not merge to `main` or open a PR unless Erik asks. Do not `git push upstream`.

---

## Spec coverage (self-review)

| Spec requirement | Task |
|---|---|
| New public repo `Erik5000/AgentMeter` | 1 |
| `origin` / `upstream` split; never push Edd | 1, 2, 8 |
| Land Codex before rename | 2 |
| `AppIdentity` + tests | 3 |
| Bundle ID, Keychain, caches, loggers, Codex client, entitlements | 4 |
| `AgentMeter.app` + module stays `ClaudeMeter` | 4 |
| Clear Edd’s `DEVELOPMENT_TEAM` | 4 |
| User-visible copy + About GitHub | 5 |
| LICENSE dual copyright + README fork attribution | 6 |
| No Homebrew / no Pages deploy | 6, 7 |
| Full test/build | 8 |
| No project/module/type rename | Global non-goal |
| No remaining-capacity-alert implementation | Global non-goal |
| Do not commit `docs/heading.png` deletion | Task 2 |

## Out of scope (later plan)

Rename `ClaudeMeter.xcodeproj`, scheme, folders, Swift module, and `ClaudeMeterApp`. Optional Homebrew tap, notarization, AgentMeter site, settings migration from ClaudeMeter.
