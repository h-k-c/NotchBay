@preconcurrency import AppKit

@MainActor
enum Permissions {

    enum PermissionType: CaseIterable {
        case accessibility
        case calendar
        case notifications

        var description: String {
            switch self {
            case .accessibility: "辅助功能 — 用于追踪 AI 终端会话"
            case .calendar: "日历 — 用于显示日程信息"
            case .notifications: "通知 — 用于显示系统通知"
            }
        }
    }

    static func status() -> [PermissionType: Bool] {
        var result: [PermissionType: Bool] = [:]
        result[.accessibility] = AXIsProcessTrusted()
        result[.calendar] = calendarGranted
        result[.notifications] = notificationsGranted
        return result
    }

    static func request(_ type: PermissionType) {
        switch type {
        case .accessibility: requestAccessibility()
        case .calendar: requestCalendar()
        case .notifications: requestNotifications()
        }
    }

    // MARK: - Private

    private static var calendarGranted: Bool {
        EKEventStoreAuthorizer.current == .authorized || EKEventStoreAuthorizer.current == .fullAccess
    }

    private static var notificationsGranted: Bool {
        NotificationService.hasPermission()
    }

    private static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(options)
    }

    private static func requestCalendar() {
        EKEventStoreAuthorizer.request()
    }

    private static func requestNotifications() {
        NotificationService.requestPermission()
    }
}

// MARK: - EventKit Authorization Wrapper

@preconcurrency import EventKit

@MainActor
private enum EKEventStoreAuthorizer {
    private static let store = EKEventStore()

    static var current: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    static func request() {
        store.requestFullAccessToEvents { _, _ in }
    }
}
