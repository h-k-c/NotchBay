import Foundation
import Combine

/// Detects current user context and auto-switches the active island module
@MainActor
final class SceneDetector: ObservableObject {
    @Published var activeModuleID: String?

    private var registeredModules: [IslandModule] = []
    private var debounceTimer: Timer?
    private var lastSwitchTime: Date = .distantPast
    private let minIntervalBetweenSwitches: TimeInterval = 2.0

    func register(_ module: IslandModule) {
        registeredModules.append(module)
        registeredModules.sort { $0.priority > $1.priority }
    }

    func unregister(_ module: IslandModule) {
        registeredModules.removeAll { $0.id == module.id }
    }

    /// Evaluate all modules and switch to the most relevant one
    func evaluate() {
        // Debounce — accumulate changes and decide after 500ms
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: Constants.sceneDebounceInterval, repeats: false) { [weak self] _ in
            self?.performEvaluation()
        }
    }

    /// Force immediate evaluation (bypass debounce)
    func evaluateImmediately() {
        debounceTimer?.invalidate()
        performEvaluation()
    }

    // MARK: - Private

    private func performEvaluation() {
        // Prevent rapid switching — minimum 2s between auto-switches
        let now = Date()
        guard now.timeIntervalSince(lastSwitchTime) >= minIntervalBetweenSwitches else {
            return
        }

        // Find the highest-priority relevant module
        let relevant = registeredModules
            .filter { $0.isRelevant() }
            .sorted { $0.priority > $1.priority }
            .first

        if let target = relevant, target.id != activeModuleID {
            lastSwitchTime = now
            activeModuleID = target.id
        }
    }

    /// Manually switch to a specific module
    func switchTo(moduleID: String) {
        guard registeredModules.contains(where: { $0.id == moduleID }) else { return }
        lastSwitchTime = Date()
        activeModuleID = moduleID
    }
}
