import SwiftUI

@MainActor
final class TimerState: ObservableObject {
    static let shared = TimerState()

    @Published var remainingSeconds: Int = 0
    @Published var isRunning: Bool = false
    @Published var initialSeconds: Int = 300

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
    }
}

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

struct TimerCompact: View {
    @ObservedObject private var state = TimerState.shared

    var body: some View {
        NotchActivityView(
            label: "倒计时",
            value: state.formattedRemaining,
            rightDot: .init(
                color: state.remainingSeconds < 60 ? Color.statusOrange : .white.opacity(0.5),
                pulse: state.remainingSeconds < 60
            )
        )
    }
}
