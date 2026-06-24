# Remaining Capacity Alert — Design Spec

**Date:** 2026-06-24  
**Branch:** feature/remaining-capacity-alert  
**Status:** In progress — data model approved, remaining sections pending

---

## Problem

ClaudeMeter already notifies when you're *running out* of session capacity. This feature adds the opposite: a "use it or lose it" nudge that fires when your reset is approaching but you still have significant capacity left. Goal is to prompt the user to make good use of remaining Claude time before it resets.

---

## Decisions Made

- **Trigger:** Time-based — fires when reset is within a configurable window AND remaining capacity is above a configurable minimum.
- **Approach:** New `RemainingCapacityAlert` struct (Approach B), separate from the existing `NotificationThresholds` — cleaner separation of concerns.
- **Both thresholds are user-adjustable** via sliders in the Notifications settings tab.

---

## Data Model ✅ (approved)

### New file: `Models/RemainingCapacityAlert.swift`

```swift
struct RemainingCapacityAlert: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var minimumRemainingPercent: Double  // only fire if remaining capacity >= this
    var resetWindowHours: Double         // fire when reset is within this many hours

    static let `default` = RemainingCapacityAlert(
        isEnabled: true,
        minimumRemainingPercent: 50,
        resetWindowHours: 1.0
    )

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case minimumRemainingPercent = "minimum_remaining_percent"
        case resetWindowHours = "reset_window_hours"
    }
}
```

### Changes to `AppSettings`

- Add `remainingCapacityAlert: RemainingCapacityAlert` with coding key `"remaining_capacity_alert"`
- Decoded with `decodeIfPresent` fallback to `.default` so existing saved settings don't break

### Changes to `NotificationState`

- Add `hasRemainingCapacityBeenNotified: Bool` (default `false`)
- Add `lastResetAt: Date?` (default `nil`)
- Clear `hasRemainingCapacityBeenNotified` when `lastResetAt` changes — ensures exactly one nudge per session window, not one per refresh cycle

---

## Remaining Sections (pending)

- [ ] Notification content — title/body for the new `.remainingCapacity` threshold type
- [ ] `NotificationService` evaluation logic
- [ ] Constants — slider bounds for the two new settings
- [ ] Settings UI — new section in the Notifications tab
- [ ] Testing plan
