# AgentMeter Fork & Rename Design

**Date:** 2026-09-12
**Status:** Draft for review
**Product name:** AgentMeter (spoken: “Agent Meter”)

## Problem

This working tree is a clone of [eddmann/ClaudeMeter](https://github.com/eddmann/ClaudeMeter) (MIT). The app now meters Claude **and** Codex, so the ClaudeMeter name, Edd’s bundle IDs, and `origin` pointing at his GitHub are the wrong identity. We need a fork we own, a name that fits more than one agent, and no risk of pushing to Edd’s repo.

## Goal

Ship a personal fork named **AgentMeter** under GitHub user `Erik5000`, with a distinct macOS identity, so it can run next to ClaudeMeter without colliding on Keychain, caches, or bundle ID. Keep git history and MIT attribution. Land the already-built Codex usage work on the new origin before renaming.

## Non-goals (this pass)

- Renaming the Xcode project, scheme, source folders, Swift module, `ClaudeMeterApp`, file headers, or `@testable import ClaudeMeter`.
- Implementing the remaining-capacity-alert spec.
- Homebrew tap, notarization, or a rewritten `site/` marketing page.
- Opening a PR against `eddmann/ClaudeMeter`.
- Migrating settings/Keychain from an installed ClaudeMeter (new bundle ID starts clean).
- Renaming the local disk folder `/Users/erik/Developer/ideas/ClaudeMeter`.

A later “structure rename” pass can turn `ClaudeMeter.xcodeproj` / the Swift module into AgentMeter. Do not mix that with this identity pass.

## Constraints

- MIT: keep `Copyright (c) 2025 Edd Mann` in `LICENSE`. Add `Copyright (c) 2026 Erik Biebinger` for new work. README and About must say this is a fork of ClaudeMeter.
- Never `git push` to `eddmann/ClaudeMeter`. After retargeting, that remote is `upstream` (fetch-only in practice).
- Do not stage the untracked/unrelated `docs/heading.png` deletion unless Erik asks.
- macOS 14+ SwiftUI menu bar app; UI on `@MainActor @Observable`; services/repositories stay actors.
- New user-facing settings keys still go through `SettingsRepository` (unchanged by this pass).

## Locked identity

| Role | Value |
|---|---|
| Display / marketing name | AgentMeter |
| GitHub repo | `https://github.com/Erik5000/AgentMeter` (public) |
| App bundle ID | `com.erik5000.AgentMeter` |
| Test bundle ID | `com.erik5000.AgentMeterTests` |
| Built product | `AgentMeter.app` (`PRODUCT_NAME = AgentMeter`) |
| Swift module | `ClaudeMeter` (`PRODUCT_MODULE_NAME = ClaudeMeter`) |
| Xcode project / scheme / target names | stay `ClaudeMeter` / `ClaudeMeterTests` |
| Logger subsystem | `com.erik5000.AgentMeter` |
| Keychain service | `com.erik5000.AgentMeter.sessionkey` |
| Keychain access group | `$(AppIdentifierPrefix)com.erik5000.AgentMeter` |
| App Support folder | `Application Support/com.erik5000.AgentMeter/` |
| Public JSON export | `~/.agentmeter/usage.json` |
| Codex app-server client | `name: "agentmeter"`, `title: "AgentMeter"` |
| GitHub About link | `https://github.com/Erik5000/AgentMeter` |
| Apple `DEVELOPMENT_TEAM` | must not remain Edd’s `ANGUD7343N`. Clear it unless Erik supplies his team ID. |

UserDefaults stay on `UserDefaults.standard` (scoped by bundle ID automatically). No settings migration.

## Git topology

```
upstream  → https://github.com/eddmann/ClaudeMeter.git   (fetch Claude-only fixes; never push)
origin    → https://github.com/Erik5000/AgentMeter.git   (our repo; push here)
```

Current clone: `origin` is Edd’s repo; branch `feature/remaining-capacity-alert` plus uncommitted Codex work.

Sequence:

1. Create empty public repo `Erik5000/AgentMeter` (no README/gitignore, so history can push).
2. `git remote rename origin upstream` then `git remote add origin <Erik5000/AgentMeter>`.
3. Push existing `main` so the fork has ClaudeMeter history.
4. Commit Codex usage (already implemented) on a dedicated branch off current HEAD; push that to **origin only**.
5. Identity commits on top of that branch; merge to `origin/main` when Erik wants default-branch to be AgentMeter.

Do not push `upstream`. Do not use GitHub’s “Contribute / Open pull request” against Edd.

## Architecture

Centralize product strings in `AppIdentity` (`ClaudeMeter/Models/AppIdentity.swift`). Repositories, loggers, Codex clientInfo, About, setup copy, and accessibility labels read from it. Xcode bundle IDs and `PRODUCT_NAME` stay in `project.pbxproj` but must match `AppIdentity`.

Keep Swift types that mean “Claude the product” (`UsageData`, Claude session import). Only rename **this app’s** product identity.

## User-visible copy

Replace “ClaudeMeter” with “AgentMeter” in setup, settings, About, menu-bar accessibility, notification usage description, and Keychain prompt preamble. Tagline becomes usage limits for Claude and Codex, not Claude-only. About shows both copyrights and links to `Erik5000/AgentMeter`. README: fork attribution, clone URL, `~/.agentmeter/usage.json`, no `brew install eddmann/tap/claudemeter`.

## CI and distribution

- Keep `.github/workflows/test.yml`. After `PRODUCT_NAME` changes, `TEST_HOST` and the scheme’s `BuildableName` must point at `AgentMeter.app`. `xcodebuild` still uses `-project ClaudeMeter.xcodeproj -scheme ClaudeMeter`.
- Disable or delete `.github/workflows/deploy-pages.yml` so this repo cannot publish Edd’s `site/` as if it were ours.
- Rewrite `.github/workflows/release.yml` so it cannot clone `eddmann/homebrew-tap`. Notarization stays off until Erik has Apple Developer credentials on this repo. Building a GitHub Release zip named `AgentMeter-<version>.zip` is enough if the rest of signing is missing.

## Testing

- Unit-test `AppIdentity` so IDs and paths cannot silently revert to `claudemeter` / `eddmann`.
- Existing suite must still `@testable import ClaudeMeter` and pass with unsigned Debug (`CODE_SIGN_IDENTITY="-"`, signing disabled), same as today.
- No snapshot-test updates required for a name change (snapshots skip in CI).

## Follow-up (not this plan)

Rename `ClaudeMeter.xcodeproj`, scheme, folders, module, and `ClaudeMeterApp` to AgentMeter. Optional: Homebrew tap under Erik, notarization, AgentMeter marketing site, settings migration from ClaudeMeter.
