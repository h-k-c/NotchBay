import Foundation
import Combine
import AppKit

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
        guard relevant.map(\.id) != carouselModules.map(\.id) else { return }

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
