# Live Activities Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live-activity carousel to the NotchBay notch with morph transitions, balanced layout, and three new modules (Clipboard, Notification auto-dismiss, Timer).

**Architecture:** SceneDetector becomes a carousel controller publishing an ordered list of relevant modules and a rotating index. NotchView observes the index and runs a 4-phase morph animation (widen → swap → narrow). A shared `NotchActivityView` component provides the B-style balanced layout used by all compact views.

**Tech Stack:** SwiftUI, AppKit, Combine, UserNotifications, NSPasteboard, UserDefaults, macOS 14+

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `Sources/Core/AppState.swift` | Modify | Add `carouselModules`, `carouselIndex`, `activeCarouselModule` |
| `Sources/Core/SceneDetector.swift` | Modify | Carousel list + 5s rotation timer + priority interrupt |
| `Sources/Core/IslandWindow.swift` | Modify | `NotchView` morph transition state machine |
| `Sources/Views/Components/NotchActivityView.swift` | Create | Shared balanced layout component |
| `Sources/Modules/NowPlaying/NowPlayingModule.swift` | Modify | Use `NotchActivityView` |
| `Sources/Modules/Battery/BatteryModule.swift` | Modify | Use `NotchActivityView` |
| `Sources/Modules/Notification/NotificationModule.swift` | Modify | Auto-dismiss 8s, use `NotchActivityView` |
| `Sources/Services/NotificationService.swift` | Modify | Auto-dismiss timer |
| `Sources/Services/ClipboardMonitor.swift` | Create | NSPasteboard polling every 0.5s |
| `Sources/Modules/Clipboard/ClipboardModule.swift` | Create | Clipboard live activity |
| `Sources/Modules/Timer/TimerModule.swift` | Create | Countdown + UserDefaults persistence |
| `Sources/Views/MenuBarView.swift` | Modify | Add timer start/stop controls |
| `Sources/Core/AppDelegate.swift` | Modify | Register ClipboardModule, TimerModule |

---

## Task 1: AppState Carousel State

**Files:**
- Modify: `Sources/Core/AppState.swift`

- [ ] **Step 1: Add carousel properties to AppState**

Open `Sources/Core/AppState.swift`. Add below `@Published var modules: [IslandModule] = []`:

```swift
@Published var carouselModules: [IslandModule] = []
@Published var carouselIndex: Int = 0
@Published var notchHovered: Bool = false  // already exists — verify it's there

var activeCarouselModule: IslandModule? {
    guard !carouselModules.isEmpty else { return nil }
    return carouselModules[carouselIndex % carouselModules.count]
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/Core/AppState.swift
git commit -m "feat: add carousel state to AppState"
```

---

## Task 2: SceneDetector Carousel

**Files:**
- Modify: `Sources/Core/SceneDetector.swift`

- [ ] **Step 1: Replace SceneDetector with carousel logic**

Replace the entire contents of `Sources/Core/SceneDetector.swift`:

```swift
import Foundation
import Combine

/// Maintains an ordered carousel of all currently-relevant modules.
/// Rotates every 5 seconds. High-priority modules interrupt immediately.
@MainActor
final class SceneDetector: ObservableObject {
    @Published var carouselModules: [IslandModule] = []
    @Published var carouselIndex: Int = 0

    /// Legacy single-winner ID used by existing AppState wiring — kept for compatibility
    var activeModuleID: String? { carouselModules.isEmpty ? nil : carouselModules[carouselIndex % carouselModules.count].id }

    private var registeredModules: [IslandModule] = []
    private var rotationTimer: Timer?
    private var evaluationTimer: Timer?
    private let rotationInterval: TimeInterval = 5.0
    private let evaluationInterval: TimeInterval = 0.5

    func register(_ module: IslandModule) {
        guard !registeredModules.contains(where: { $0.id == module.id }) else { return }
        registeredModules.append(module)
        registeredModules.sort { $0.priority > $1.priority }
    }

    func unregister(_ module: IslandModule) {
        registeredModules.removeAll { $0.id == module.id }
        rebuildCarousel()
    }

    /// Start evaluation + rotation loop
    func startCarousel() {
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: evaluationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuildCarousel() }
        }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        // Re-evaluate immediately when user switches apps (faster than 0.5s poll)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildCarousel() }
        }
    }

    func stopCarousel() {
        evaluationTimer?.invalidate()
        rotationTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    /// Interrupt: jump immediately to a module by id (e.g. new notification)
    func interrupt(moduleID: String) {
        guard let idx = carouselModules.firstIndex(where: { $0.id == moduleID }) else { return }
        carouselIndex = idx
        // Reset rotation timer so the interrupted module gets full 5s
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
    }

    // MARK: - Legacy API (used by SceneDetector callers)

    func evaluate() { rebuildCarousel() }
    func evaluateImmediately() { rebuildCarousel() }
    func switchTo(moduleID: String) { interrupt(moduleID: moduleID) }

    // MARK: - Private

    private func advance() {
        guard carouselModules.count > 1 else { return }
        carouselIndex = (carouselIndex + 1) % carouselModules.count
    }

    private func rebuildCarousel() {
        let relevant = registeredModules.filter { $0.isRelevant() }
        guard relevant != carouselModules else { return }

        // Preserve current module position if it's still relevant
        let currentID = carouselModules.isEmpty ? nil : carouselModules[carouselIndex % max(carouselModules.count, 1)].id
        carouselModules = relevant

        if let id = currentID, let newIdx = relevant.firstIndex(where: { $0.id == id }) {
            carouselIndex = newIdx
        } else {
            carouselIndex = 0
        }
    }
}

extension Array where Element: IslandModule {
    static func != (lhs: [IslandModule], rhs: [IslandModule]) -> Bool {
        lhs.map(\.id) != rhs.map(\.id)
    }
}
```

- [ ] **Step 2: Wire carousel into AppState**

In `Sources/Core/AppState.swift`, find `setupSceneDetection()` and replace it:

```swift
private func setupSceneDetection() {
    sceneDetector.$carouselModules
        .receive(on: DispatchQueue.main)
        .sink { [weak self] modules in
            self?.carouselModules = modules
        }
        .store(in: &cancellables)

    sceneDetector.$carouselIndex
        .receive(on: DispatchQueue.main)
        .sink { [weak self] idx in
            guard let self else { return }
            self.carouselIndex = idx
            // Keep legacy activeModuleID in sync
            self.activeModuleID = self.activeCarouselModule?.id
        }
        .store(in: &cancellables)

    sceneDetector.startCarousel()
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/Core/SceneDetector.swift Sources/Core/AppState.swift
git commit -m "feat: SceneDetector becomes carousel with 5s rotation"
```

---

## Task 3: NotchView Morph Transition

**Files:**
- Modify: `Sources/Core/IslandWindow.swift`

- [ ] **Step 1: Add morph state machine to NotchView**

Replace the `NotchView` struct in `Sources/Core/IslandWindow.swift` with:

```swift
// Morph transition phases
private enum MorphPhase: Equatable { case idle, widening, swapping, narrowing }

struct NotchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isHovered = false
    @State private var morphPhase: MorphPhase = .idle
    @State private var displayedModuleID: String? = nil

    private let hoverScale: CGFloat = 1.2
    private let morphScale: CGFloat = 1.12

    private var currentW: CGFloat {
        let base: CGFloat
        switch morphPhase {
        case .widening, .swapping: base = notchW * morphScale
        default: base = isHovered ? notchW * hoverScale : notchW
        }
        return base
    }
    private var currentH: CGFloat { isHovered && morphPhase == .idle ? notchH * hoverScale : notchH }
    private var currentR: CGFloat { isHovered && morphPhase == .idle ? notchRadius * hoverScale : notchRadius }
    private var contentOpacity: Double { morphPhase == .swapping ? 0.0 : 1.0 }

    private var displayedModule: IslandModule? {
        guard let id = displayedModuleID else { return appState.activeCarouselModule }
        return appState.carouselModules.first { $0.id == id } ?? appState.activeCarouselModule
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: currentR,
                    bottomTrailingRadius: currentR,
                    topTrailingRadius: 0
                )
                .fill(.black)

                HStack(spacing: 6) {
                    if let m = displayedModule { m.compactView() }
                }
                .padding(.horizontal, 12)
                .opacity(contentOpacity)
                .animation(.easeInOut(duration: 0.06), value: contentOpacity)
            }
            .frame(width: currentW, height: currentH)
            .position(x: geo.size.width / 2, y: currentH / 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: currentW)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
            .onChange(of: appState.carouselIndex) { _ in
                triggerMorph()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            displayedModuleID = appState.activeCarouselModule?.id
        }
    }

    private func triggerMorph() {
        guard morphPhase == .idle else { return }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.8)) { morphPhase = .widening }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            morphPhase = .swapping
            displayedModuleID = appState.activeCarouselModule?.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) { morphPhase = .narrowing }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            morphPhase = .idle
        }
    }
}
```

- [ ] **Step 2: Build and run**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```
Expected: `** BUILD SUCCEEDED **`

```bash
pkill -f NotchBay; sleep 0.5
open /Users/openorange/Library/Developer/Xcode/DerivedData/NotchBay-dpllpkwhxipvagfbazklunckldsu/Build/Products/Debug/NotchBay.app
```

Verify: notch appears at screen top. Wait 5 seconds — if any module is relevant it transitions with a widen/narrow morph.

- [ ] **Step 3: Commit**

```bash
git add Sources/Core/IslandWindow.swift
git commit -m "feat: morph transition on carousel index change"
```

---

## Task 4: NotchActivityView Shared Component

**Files:**
- Create: `Sources/Views/Components/NotchActivityView.swift`

- [ ] **Step 1: Create the shared balanced layout component**

```swift
// Sources/Views/Components/NotchActivityView.swift
import SwiftUI

/// Balanced (Style B) compact layout used by all modules.
/// [ left ] [ separator ] [ label (9px, dim) / value (11px, white) ] [ right ]
struct NotchActivityView: View {
    var left: AnyView? = nil
    var label: String = ""
    var value: String
    var rightBar: BarConfig? = nil    // optional mini progress bar
    var rightDot: DotConfig? = nil    // optional pulsing dot

    struct BarConfig {
        var fraction: Double          // 0.0–1.0
        var color: Color
    }

    struct DotConfig {
        var color: Color
        var pulse: Bool
    }

    @State private var dotPulse = false

    var body: some View {
        HStack(spacing: 0) {
            // Left indicator (icon, EQ bars, etc.)
            if let left {
                left
                    .frame(width: 18)
                Divider()
                    .frame(width: 1, height: 16)
                    .background(.white.opacity(0.1))
                    .padding(.horizontal, 5)
            }

            // Label + value stack
            VStack(alignment: .leading, spacing: 1) {
                if !label.isEmpty {
                    Text(label.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(0.6)
                }
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            // Right: progress bar
            if let bar = rightBar {
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.12))
                        .frame(width: 36, height: 3)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(bar.color)
                                .frame(width: max(0, 36 * bar.fraction), height: 3)
                        }
                }
            }

            // Right: pulsing dot
            if let dot = rightDot {
                Circle()
                    .fill(dot.color)
                    .frame(width: 5, height: 5)
                    .opacity(dot.pulse ? (dotPulse ? 1.0 : 0.3) : 1.0)
                    .onAppear {
                        if dot.pulse {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                dotPulse = true
                            }
                        }
                    }
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Components/NotchActivityView.swift
git commit -m "feat: add NotchActivityView balanced layout component"
```

---

## Task 5: Update NowPlaying Compact View

**Files:**
- Modify: `Sources/Modules/NowPlaying/NowPlayingModule.swift`

- [ ] **Step 1: Replace NowPlayingCompact body**

Find `struct NowPlayingCompact` and replace its `body`:

```swift
struct NowPlayingCompact: View {
    @ObservedObject private var monitor = MediaMonitor.shared

    var body: some View {
        NotchActivityView(
            left: AnyView(EqualizerBars().opacity(monitor.isPlaying ? 1 : 0.3)),
            label: monitor.artist.isEmpty ? "音乐" : monitor.artist,
            value: monitor.title.isEmpty ? "未在播放" : String(monitor.title.prefix(22))
        )
    }
}
```

- [ ] **Step 2: Build and run, verify NowPlaying shows balanced layout**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
pkill -f NotchBay; sleep 0.3
open /Users/openorange/Library/Developer/Xcode/DerivedData/NotchBay-dpllpkwhxipvagfbazklunckldsu/Build/Products/Debug/NotchBay.app
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Modules/NowPlaying/NowPlayingModule.swift
git commit -m "feat: NowPlaying compact uses NotchActivityView"
```

---

## Task 6: Update Battery Compact View

**Files:**
- Modify: `Sources/Modules/Battery/BatteryModule.swift`

- [ ] **Step 1: Find BatteryCompact and read current monitor properties**

Read `Sources/Modules/Battery/BatteryModule.swift` lines 1-40 to check `BatteryMonitor` published property names before editing.

- [ ] **Step 2: Replace BatteryCompact body**

Find `struct BatteryCompact` and replace its `body` (adjust property names to match what you read in Step 1):

```swift
struct BatteryCompact: View {
    @ObservedObject private var monitor = BatteryMonitor.shared

    private var barColor: Color {
        if monitor.isCharging { return Color.statusGreen }
        if monitor.percentage <= 20 { return Color.statusRed }
        return .white.opacity(0.7)
    }

    var body: some View {
        NotchActivityView(
            label: monitor.isCharging ? "充电中" : "电池",
            value: "\(monitor.percentage)%",
            rightBar: .init(fraction: Double(monitor.percentage) / 100.0, color: barColor)
        )
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```

- [ ] **Step 4: Commit**

```bash
git add Sources/Modules/Battery/BatteryModule.swift
git commit -m "feat: Battery compact uses NotchActivityView with progress bar"
```

---

## Task 7: ClipboardMonitor Service

**Files:**
- Create: `Sources/Services/ClipboardMonitor.swift`

- [ ] **Step 1: Create ClipboardMonitor**

```swift
// Sources/Services/ClipboardMonitor.swift
import AppKit
import Combine

/// Polls NSPasteboard.general.changeCount every 0.5s.
/// Publishes latest text and timestamp of last copy.
@MainActor
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published var latestText: String = ""
    @Published var lastCopiedAt: Date = .distantPast

    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var pollTimer: Timer?

    private init() {}

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let text = pb.string(forType: .string), !text.isEmpty {
            latestText = text
            lastCopiedAt = Date()
        }
    }

    /// Returns true if a text copy happened within the last `seconds`
    func wasRecentlyCopied(within seconds: TimeInterval = 30) -> Bool {
        !latestText.isEmpty && Date().timeIntervalSince(lastCopiedAt) < seconds
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/ClipboardMonitor.swift
git commit -m "feat: ClipboardMonitor polls pasteboard every 0.5s"
```

---

## Task 8: ClipboardModule

**Files:**
- Create: `Sources/Modules/Clipboard/ClipboardModule.swift`

- [ ] **Step 1: Create ClipboardModule**

```swift
// Sources/Modules/Clipboard/ClipboardModule.swift
import SwiftUI

final class ClipboardModule: IslandModule {
    private let monitor = ClipboardMonitor.shared

    init() {
        super.init(id: "clipboard", name: "剪贴板", icon: "doc.on.clipboard", priority: 35)
    }

    override func compactView() -> AnyView { AnyView(ClipboardCompact()) }
    override func expandedView() -> AnyView { AnyView(EmptyView()) }

    override func isRelevant() -> Bool {
        monitor.wasRecentlyCopied(within: 30)
    }

    override func startMonitoring() { monitor.start() }
    override func stopMonitoring() { monitor.stop() }
}

// MARK: - Compact

struct ClipboardCompact: View {
    @ObservedObject private var monitor = ClipboardMonitor.shared

    private var preview: String {
        let text = monitor.latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = text.components(separatedBy: .newlines).joined(separator: " ")
        return single.count > 24 ? String(single.prefix(24)) + "…" : single
    }

    var body: some View {
        NotchActivityView(
            label: "剪贴板",
            value: preview.isEmpty ? "空" : preview
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Modules/Clipboard/ClipboardModule.swift
git commit -m "feat: ClipboardModule shows latest copy in notch"
```

---

## Task 9: NotificationModule Auto-Dismiss

**Files:**
- Modify: `Sources/Services/NotificationService.swift`
- Modify: `Sources/Modules/Notification/NotificationModule.swift`

- [ ] **Step 1: Add auto-dismiss timer to NotificationService**

In `Sources/Services/NotificationService.swift`, add a property and auto-dismiss logic.

After `@Published var hasUnread: Bool = false` add:
```swift
@Published var lastReceivedAt: Date = .distantPast
private var dismissTimer: Timer?
```

In `handleDistributedNotification` and `userNotificationCenter willPresent`, after setting `self.hasUnread = true` add:
```swift
self.lastReceivedAt = Date()
self.scheduleDismiss()
```

Add the method:
```swift
private func scheduleDismiss() {
    dismissTimer?.invalidate()
    dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.hasUnread = false
        }
    }
}
```

- [ ] **Step 2: Update NotificationModule priority and compact view**

In `Sources/Modules/Notification/NotificationModule.swift`:

Change `super.init` priority from `100` to `70`.

Replace `NotificationCompact` body:

```swift
struct NotificationCompact: View {
    @ObservedObject private var service = NotificationService.shared

    var body: some View {
        if let latest = service.recentNotifications.first {
            NotchActivityView(
                left: AnyView(
                    Image(systemName: latest.appIcon ?? "app.badge")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                ),
                label: latest.appName.isEmpty ? "通知" : String(latest.appName.prefix(12)),
                value: latest.title.isEmpty ? latest.body : String(latest.title.prefix(22))
            )
        } else {
            NotchActivityView(label: "通知", value: "暂无新通知")
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```

- [ ] **Step 4: Commit**

```bash
git add Sources/Services/NotificationService.swift Sources/Modules/Notification/NotificationModule.swift
git commit -m "feat: notifications auto-dismiss after 8s, balanced layout"
```

---

## Task 10: TimerModule

**Files:**
- Create: `Sources/Modules/Timer/TimerModule.swift`

- [ ] **Step 1: Create TimerModule**

```swift
// Sources/Modules/Timer/TimerModule.swift
import SwiftUI
import Combine

/// Countdown timer. Controlled from MenuBar. Persists via UserDefaults.
@MainActor
final class TimerState: ObservableObject {
    static let shared = TimerState()

    @Published var remainingSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var initialSeconds: Int = 300  // default 5 min

    private var countdownTimer: Timer?
    private let defaults = UserDefaults.standard

    private init() { restore() }

    func start(seconds: Int? = nil) {
        let s = seconds ?? initialSeconds
        initialSeconds = s
        remainingSeconds = s
        isRunning = true
        schedule()
        save()
    }

    func pause() {
        isRunning = false
        countdownTimer?.invalidate()
        save()
    }

    func resume() {
        guard remainingSeconds > 0 else { return }
        isRunning = true
        schedule()
    }

    func reset() {
        countdownTimer?.invalidate()
        remainingSeconds = 0
        isRunning = false
        save()
    }

    var formattedRemaining: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func schedule() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                    self.save()
                } else {
                    self.isRunning = false
                    self.countdownTimer?.invalidate()
                }
            }
        }
    }

    private func save() {
        defaults.set(remainingSeconds, forKey: "timer.remaining")
        defaults.set(isRunning, forKey: "timer.running")
        defaults.set(initialSeconds, forKey: "timer.initial")
    }

    private func restore() {
        remainingSeconds = defaults.integer(forKey: "timer.remaining")
        initialSeconds = max(defaults.integer(forKey: "timer.initial"), 60)
        // Don't auto-resume — user must re-start after app restart
    }
}

// MARK: - Module

final class TimerModule: IslandModule {
    private let state = TimerState.shared

    init() {
        super.init(id: "timer", name: "倒计时", icon: "timer", priority: 55)
    }

    override func compactView() -> AnyView { AnyView(TimerCompact()) }
    override func expandedView() -> AnyView { AnyView(EmptyView()) }

    override func isRelevant() -> Bool {
        state.isRunning && state.remainingSeconds > 0
    }

    override func startMonitoring() {}
    override func stopMonitoring() {}
}

// MARK: - Compact View

struct TimerCompact: View {
    @ObservedObject private var state = TimerState.shared

    var body: some View {
        NotchActivityView(
            label: "倒计时",
            value: state.formattedRemaining,
            rightDot: .init(color: state.remainingSeconds < 60 ? Color.statusOrange : .white.opacity(0.5),
                            pulse: state.remainingSeconds < 60)
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```

- [ ] **Step 3: Commit**

```bash
git add Sources/Modules/Timer/TimerModule.swift
git commit -m "feat: TimerModule with countdown and UserDefaults persistence"
```

---

## Task 11: MenuBar Timer Controls

**Files:**
- Modify: `Sources/Views/MenuBarView.swift` (or wherever the MenuBarExtra menu content is)

- [ ] **Step 1: Read current MenuBar view**

Read `Sources/Views/MenuBarView.swift` (or search for `MenuBarView` in the project) to understand existing structure before editing.

- [ ] **Step 2: Add timer controls section**

Find the main `VStack` or `Form` in the menu and add this section. Place it near the top, before existing module controls:

```swift
// Timer section
Divider()
Section {
    HStack {
        Image(systemName: "timer")
            .frame(width: 20)
        VStack(alignment: .leading, spacing: 1) {
            Text("倒计时")
                .font(.system(size: 12, weight: .medium))
            Text(timerState.isRunning ? timerState.formattedRemaining + " 剩余" : "未运行")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        Spacer()
        if timerState.isRunning {
            Button("暂停") { timerState.pause() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
        } else if timerState.remainingSeconds > 0 {
            Button("继续") { timerState.resume() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            Button("重置") { timerState.reset() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            Button("5分钟") { timerState.start(seconds: 300) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            Button("25分钟") { timerState.start(seconds: 1500) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
        }
    }
}
```

Add `@ObservedObject private var timerState = TimerState.shared` to the view's properties.

- [ ] **Step 3: Build**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
```

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/MenuBarView.swift
git commit -m "feat: timer start/pause/reset controls in MenuBar"
```

---

## Task 12: Register New Modules + Cleanup

**Files:**
- Modify: `Sources/Core/AppDelegate.swift`

- [ ] **Step 1: Register ClipboardModule and TimerModule**

In `Sources/Core/AppDelegate.swift`, inside `applicationDidFinishLaunching`, add after existing `registerModule` calls:

```swift
state.registerModule(ClipboardModule())
state.registerModule(TimerModule())
```

Also remove the debug line:
```swift
NSApp.setActivationPolicy(.regular) // DEBUG: test if panel is visible
```
Replace with:
```swift
NSApp.setActivationPolicy(.accessory) // hide from Dock
```

- [ ] **Step 2: Build and full run test**

```bash
xcodebuild -project NotchBay.xcodeproj -scheme NotchBay build 2>&1 | grep -E "(BUILD|error:)"
pkill -f NotchBay; sleep 0.5
open /Users/openorange/Library/Developer/Xcode/DerivedData/NotchBay-dpllpkwhxipvagfbazklunckldsu/Build/Products/Debug/NotchBay.app
```

Manual verification:
- Notch shows at screen top ✓
- Copy some text → clipboard module appears in notch ✓  
- Wait 5s → rotates to next relevant module with morph ✓
- Start timer from menu bar → timer appears in notch ✓
- Timer < 60s → orange pulsing dot ✓

- [ ] **Step 3: Final commit**

```bash
git add Sources/Core/AppDelegate.swift
git commit -m "feat: register Clipboard and Timer modules, fix activation policy"
```
