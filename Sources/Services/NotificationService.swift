import Foundation
@preconcurrency import UserNotifications
import Combine

/// Bridges system notifications to the island
@MainActor
final class NotificationService: NSObject, ObservableObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published var recentNotifications: [IslandNotification] = []
    @Published var hasUnread: Bool = false
    @Published var lastReceivedAt: Date = .distantPast
    private var dismissTimer: Timer?

    struct IslandNotification: Identifiable {
        let id: String
        let appName: String
        let title: String
        let body: String
        let timestamp: Date
        let appIcon: String?
    }

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    static func hasPermission() -> Bool {
        var granted = false
        let semaphore = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            granted = settings.authorizationStatus == .authorized
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 0.5)
        return granted
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Monitor Distributed Notifications

    func start() {
        // Listen for distributed notifications from other apps
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDistributedNotification(_:)),
            name: NSNotification.Name("com.apple.notification.center.message"),
            object: nil
        )
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleDistributedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }

        let islandNotif = IslandNotification(
            id: UUID().uuidString,
            appName: userInfo["sender"] as? String ?? "System",
            title: userInfo["title"] as? String ?? "",
            body: userInfo["body"] as? String ?? "",
            timestamp: Date(),
            appIcon: userInfo["icon"] as? String
        )

        DispatchQueue.main.async {
            self.recentNotifications.insert(islandNotif, at: 0)
            if self.recentNotifications.count > 20 {
                self.recentNotifications = Array(self.recentNotifications.prefix(20))
            }
            self.hasUnread = true
            self.lastReceivedAt = Date()
            self.scheduleDismiss()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // When NotchBay is active, intercept and show in island instead of banner
        let content = notification.request.content
        let islandNotif = IslandNotification(
            id: notification.request.identifier,
            appName: content.targetContentIdentifier ?? content.categoryIdentifier,
            title: content.title,
            body: content.body,
            timestamp: notification.date,
            appIcon: nil
        )

        DispatchQueue.main.async {
            self.recentNotifications.insert(islandNotif, at: 0)
            self.hasUnread = true
            self.lastReceivedAt = Date()
            self.scheduleDismiss()
        }

        // Cap at 20
        if self.recentNotifications.count > 20 {
            self.recentNotifications = Array(self.recentNotifications.prefix(20))
        }
        // Suppress system banner
        completionHandler([])
    }

    // MARK: - Auto-dismiss

    private func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hasUnread = false
            }
        }
    }
}
