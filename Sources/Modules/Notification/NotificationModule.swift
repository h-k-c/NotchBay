import SwiftUI

final class NotificationModule: IslandModule {
    @ObservedObject private var service = NotificationService.shared

    init() {
        super.init(id: "notification", name: "通知", icon: "bell.fill", priority: 70)
    }

    override func compactView() -> AnyView {
        AnyView(NotificationCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(NotificationExpanded())
    }

    override func isRelevant() -> Bool {
        service.hasUnread
    }

    override func startMonitoring() {
        service.start()
    }

    override func stopMonitoring() {
        service.stop()
    }
}

// MARK: - Compact View

struct NotificationCompact: View {
    @ObservedObject private var service = NotificationService.shared

    var body: some View {
        if let latest = service.recentNotifications.first {
            NotchActivityView(
                left: AnyView(
                    Image(systemName: "app.badge")
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

// MARK: - Expanded View

struct NotificationExpanded: View {
    @ObservedObject private var service = NotificationService.shared
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            if service.recentNotifications.isEmpty {
                emptyState
            } else {
                HStack {
                    Text("最近通知")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    if !service.recentNotifications.isEmpty {
                        Button("清除") {
                            service.recentNotifications.removeAll()
                            service.hasUnread = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(service.recentNotifications.prefix(10)) { notif in
                            NotificationRow(notification: notif)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("暂无通知")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(height: 80)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: NotificationService.IslandNotification

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: notification.appIcon ?? "app.badge")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(notification.appName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(notification.timestamp.relativeDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Text(notification.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            // Dismiss this notification
            NotificationService.shared.recentNotifications.removeAll { $0.id == notification.id }
        }
    }

}
