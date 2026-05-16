import SwiftUI
import Combine
import AppKit

/// Global application state — single source of truth
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Published State

    @Published var activeModuleID: String? = nil
    @Published var isExpanded: Bool = false
    @Published var modules: [IslandModule] = []
    @Published var notchHovered: Bool = false

    // MARK: - Window Management

    var islandWindow: IslandWindow?
    var settingsWindow: NSWindow?

    // MARK: - Scene Detection

    let sceneDetector = SceneDetector()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupSceneDetection()
    }

    private func setupSceneDetection() {
        sceneDetector.$activeModuleID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] moduleID in
                guard let self, self.activeModuleID != moduleID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.activeModuleID = moduleID
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Module Management

    func registerModule(_ module: IslandModule) {
        guard !modules.contains(where: { $0.id == module.id }) else { return }
        modules.append(module)
        module.startMonitoring()
        sceneDetector.register(module)
    }

    func unregisterModule(_ module: IslandModule) {
        modules.removeAll { $0.id == module.id }
        module.stopMonitoring()
        sceneDetector.unregister(module)
    }

    var activeModule: IslandModule? {
        modules.first { $0.id == activeModuleID }
    }

    // MARK: - Expand / Collapse

    func toggleExpanded() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
        islandWindow?.setExpanded(isExpanded)
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = false
        }
        islandWindow?.setExpanded(false)
    }
}
