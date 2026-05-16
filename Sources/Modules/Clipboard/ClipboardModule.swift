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
