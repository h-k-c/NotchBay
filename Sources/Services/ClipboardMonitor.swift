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
