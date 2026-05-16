import Foundation
import EventKit

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published var upcoming: [CalendarEvent] = []

    private let store = EKEventStore()
    private var timer: Timer?

    struct CalendarEvent: Identifiable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let isAllDay: Bool
    }

    private init() {}

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized || status == .fullAccess else {
            DispatchQueue.main.async { self.upcoming = [] }
            return
        }

        // Run EKEventStore query off main thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let now = Date()
            guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return }
            let predicate = self?.store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
            guard let predicate = predicate, let events = self?.store.events(matching: predicate) else { return }

            let result = events.prefix(5).map { ek in
                CalendarEvent(
                    id: ek.eventIdentifier,
                    title: ek.title,
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    location: ek.location,
                    isAllDay: ek.isAllDay
                )
            }

            DispatchQueue.main.async {
                self?.upcoming = result
            }
        }
    }

    /// Derived: no need for a separate @Published boolean
    var hasUpcomingEvent: Bool { !upcoming.isEmpty }

    func eventStartingWithin(minutes: Int) -> Bool {
        let now = Date()
        guard let threshold = Calendar.current.date(byAdding: .minute, value: minutes, to: now) else { return false }
        return upcoming.contains { $0.startDate > now && $0.startDate <= threshold }
    }

    var nextEvent: CalendarEvent? {
        let now = Date()
        return upcoming
            .filter { $0.startDate > now }
            .min { $0.startDate < $1.startDate }
    }
}
