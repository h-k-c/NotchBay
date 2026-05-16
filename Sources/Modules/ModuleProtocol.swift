import SwiftUI

// MARK: - Module Base Class

/// Base class for all island modules. Uses class inheritance instead of protocol
/// because Swift existential types (any Protocol) don't work with ObservableObject.
@MainActor
class IslandModule: ObservableObject, Identifiable {
    let id: String
    let name: String
    let icon: String
    let priority: Int

    init(id: String, name: String, icon: String, priority: Int) {
        self.id = id
        self.name = name
        self.icon = icon
        self.priority = priority
    }

    /// Build the compact (single-line) view for the notch strip
    func compactView() -> AnyView {
        AnyView(EmptyView())
    }

    /// Build the expanded (detailed) view for the dropdown panel
    func expandedView() -> AnyView {
        AnyView(EmptyView())
    }

    /// Does this module currently have relevant data to show?
    func isRelevant() -> Bool {
        false
    }

    /// Start any background monitoring this module needs
    func startMonitoring() {}

    /// Stop background monitoring
    func stopMonitoring() {}
}
