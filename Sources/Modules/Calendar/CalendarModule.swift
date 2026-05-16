import SwiftUI

final class CalendarModule: IslandModule {
    @ObservedObject private var service = CalendarService.shared

    init() {
        super.init(id: "calendar", name: "日历", icon: "calendar", priority: 40)
    }

    override func compactView() -> AnyView {
        AnyView(CalendarCompact())
    }

    override func expandedView() -> AnyView {
        AnyView(CalendarExpanded())
    }

    override func isRelevant() -> Bool {
        service.eventStartingWithin(minutes: 5)
    }

    override func startMonitoring() {
        service.start()
    }

    override func stopMonitoring() {
        service.stop()
    }
}

// MARK: - Compact View

struct CalendarCompact: View {
    @ObservedObject private var service = CalendarService.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.statusBlue)

            if let next = service.nextEvent {
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.startDate.timeString)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.statusBlue)

                    Text(next.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } else {
                Text("今日无日程")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        
    }

}

// MARK: - Expanded View

struct CalendarExpanded: View {
    @ObservedObject private var service = CalendarService.shared

    var body: some View {
        VStack(spacing: 12) {
            if service.upcoming.isEmpty {
                emptyState
            } else {
                eventsList
            }
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("今日无日程")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("需要授权日历访问权限")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 120)
    }

    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日日程")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            ForEach(service.upcoming) { event in
                EventRow(event: event)
            }
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarService.CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.startDate.timeString)

                    if !event.isAllDay {
                        Text("-")
                        Text(event.endDate.timeString)
                    }

                    if let location = event.location, !location.isEmpty {
                        Text("·")
                        Text(location)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if isSoon(event.startDate) {
                Text("即将开始")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.statusBlue.opacity(0.3))
                    .clipShape(Capsule())
            }
        }
        .padding(8)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var eventColor: Color {
        isSoon(event.startDate) ? .statusBlue : .white.opacity(0.3)
    }

    private func isSoon(_ date: Date) -> Bool {
        date.timeIntervalSinceNow < 600 // within 10 min
    }

}
