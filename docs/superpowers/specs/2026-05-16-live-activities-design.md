# NotchBay Live Activities — Design Spec
Date: 2026-05-16

## Summary

Extend NotchBay's notch with a full live-activity carousel: all relevant modules rotate through the notch with a morph transition, using a balanced info-density layout. New modules: Clipboard, Notification, Timer.

---

## 1. Carousel System

**Behavior:**
- All currently-relevant modules participate in the carousel (not just the highest-priority one)
- Rotation interval: 5 seconds per module (configurable in Settings)
- If only one module is relevant, no rotation — stays static
- When a new high-priority event fires (notification, clipboard change), that module jumps to front and resets the timer
- Priority interrupts: Notification > Timer (expiring) > Clipboard > others

**Implementation changes to `SceneDetector`:**
- Replace single-winner selection with an ordered list of all relevant modules
- Add `@Published var carouselModules: [IslandModule]`
- Add `@Published var carouselIndex: Int = 0`
- Timer fires every 5s → `carouselIndex = (carouselIndex + 1) % carouselModules.count`
- High-priority interrupt: set `carouselIndex` to that module's position immediately

---

## 2. Morph Transition (Style C)

When `carouselIndex` changes:

1. **Widen** notch from `notchW` → `notchW * 1.12` over 120ms (spring)
2. **Swap content** at peak width: old content fades out (60ms), new content fades in (60ms)
3. **Narrow** back to `notchW` over 150ms (spring)

Total ~330ms. Implemented in `NotchView` by observing `appState.carouselIndex` with a state machine: `.idle → .widening → .swapping → .narrowing → .idle`.

---

## 3. Layout — Balanced (Style B)

Each module's `compactView()` uses a shared `NotchActivityView` component:

```
[ icon/indicator ] [ label (9px, 45%) ] [ main value (11px, white) ] [ optional: bar/secondary ]
```

Separator line (1px, 10% white) between two data sections when applicable.

**Per module:**

| Module | Left | Label | Value | Right |
|--------|------|-------|-------|-------|
| NowPlaying | EQ bars (animated) | artist name (9px) | song title | — |
| Battery | — | 电池 | 87% | progress bar (green/orange/red) |
| Clipboard | — | 剪贴板 | truncated text (max 24 chars) | — |
| Notification | app icon (12pt) | app name | message preview | — |
| Timer | — | 倒计时 | MM:SS | pulsing orange dot |
| AISession | colored dot | state label | agent name | — |

---

## 4. New Modules

### 4.1 ClipboardModule
- **File:** `Sources/Modules/Clipboard/ClipboardModule.swift`
- **Priority:** 35
- **Relevance:** true when pasteboard changed in last 30s AND contains text
- **Monitoring:** `Timer` every 0.5s checks `NSPasteboard.general.changeCount`
- **Display:** last copied text, truncated to 24 chars. Empty pasteboard or non-text = not relevant
- **Auto-dismiss:** becomes not-relevant 30s after last copy

### 4.2 NotificationModule (complete existing stub)
- **File:** `Sources/Modules/Notification/NotificationModule.swift`
- **Priority:** 70 (highest — interrupts carousel)
- **Relevance:** true for 8s after receiving a notification
- **Monitoring:** Two-layer approach:
  1. `UNUserNotificationCenter` — receives notifications delivered to NotchBay itself
  2. `NSDistributedNotificationCenter` — catches broadcasted system/app events (partial coverage)
  - Note: full interception of all apps' notifications requires Accessibility permission or private API; out of scope
- **Display:** app name (label) + message body (value), truncated
- **Permission:** request `UNAuthorizationOptions: [.alert]` on start + optional Accessibility in Settings

### 4.3 TimerModule
- **File:** `Sources/Modules/Timer/TimerModule.swift`  
- **Priority:** 55
- **Relevance:** true when a countdown is active
- **State:** `remainingSeconds: Int`, counts down via `Timer` every 1s
- **Display:** `MM:SS` format, pulsing orange dot when < 60s
- **Control:** start/stop/reset from MenuBar popover (not notch click)
- **Persistence:** saves timer state to `UserDefaults` (survives app restart)

---

## 5. Other Apps Integration

Scope: monitor **frontmost app context** to show relevant info.

- Use `NSWorkspace.shared.notificationCenter` for app-switch events
- When frontmost app changes, evaluate if any module becomes newly relevant
- Example: switching to Terminal/Xcode → AISession module may activate
- No per-app custom integrations in this phase (that's a future plugin system)

---

## 6. Architecture Changes Summary

| File | Change |
|------|--------|
| `SceneDetector.swift` | carousel list + index + interrupt logic |
| `AppState.swift` | `carouselModules`, `carouselIndex`, `activeCarouselModule` |
| `IslandWindow.swift` | morph transition state machine in `NotchView` |
| `Sources/Views/Components/NotchActivityView.swift` | new shared balanced layout component |
| `Sources/Modules/Clipboard/ClipboardModule.swift` | new |
| `Sources/Modules/Notification/NotificationModule.swift` | complete existing stub |
| `Sources/Modules/Timer/TimerModule.swift` | new |
| `Sources/Services/ClipboardMonitor.swift` | new |
| `AppDelegate.swift` | register new modules |

---

## 7. Out of Scope (this phase)

- Per-app custom integrations beyond frontmost-app context switching
- Clipboard history list (only latest item)
- Timer UI within notch (set via menu bar only)
- Weather module completion
