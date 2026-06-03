import EventKit
import SwiftUI

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColor: Color
    let notes: String?
    let location: String?

    // Выносим форматтер в статику, чтобы не создавать его каждый раз
    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var duration: String {
        if isAllDay { return "Весь день" }
        return Self.durationFormatter.string(from: startDate, to: endDate) ?? ""
    }
}

// MARK: - Calendar Service

@Observable
final class CalendarService {
    static let shared = CalendarService()

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var events: [CalendarEvent] = []
    var isLoading = false
    var errorMessage: String? = nil

    private let store = EKEventStore()

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        setupObservers()
    }

    // MARK: - Observers
    
    private func setupObservers() {
        // Слушаем изменения в календаре извне системы
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.fetchEvents()
            }
        }
    }

    // MARK: - Permissions

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                // ВАЖНО: Убедитесь, что ключ NSCalendarsFullAccessUsageDescription есть в Info.plist
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            
            if granted { await fetchEvents() }
            return granted
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .fullAccess
    }

    // MARK: - Fetch Events

    func fetchEvents(daysAhead: Int = 30) async {
        guard isAuthorized else { return }
        
        await MainActor.run { isLoading = true }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) ?? startDate

        // Выполняем тяжелый запрос и маппинг в фоновом потоке
        let fetchedEvents = await Task.detached { [store] () -> [CalendarEvent] in
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let ekEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

            return ekEvents.map { event in
                let cgColor = event.calendar.cgColor
                let uiColor = cgColor.map { UIColor(cgColor: $0) } ?? UIColor.systemBlue
                return CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Без названия",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    calendarColor: Color(uiColor),
                    notes: event.notes,
                    location: event.location
                )
            }
        }.value

        // Возвращаем результаты в MainActor
        await MainActor.run {
            self.events = fetchedEvents
            self.isLoading = false
        }
    }

    // MARK: - Create Event

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        notes: String? = nil,
        location: String? = nil
    ) async -> Bool {
        guard isAuthorized else { return false }

        // Безопасное извлечение календаря
        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            await MainActor.run {
                errorMessage = "Нет доступного календаря для сохранения."
            }
            return false
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.notes = notes
        event.location = location
        event.calendar = defaultCalendar

        do {
            try store.save(event, span: .thisEvent)
            await fetchEvents()
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Не удалось сохранить событие: \(error.localizedDescription)"
            }
            return false
        }
    }

    // MARK: - Grouped Events

    func eventsGrouped(for date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    var todayEvents: [CalendarEvent] {
        eventsGrouped(for: Date())
    }

    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events.filter { $0.startDate >= now }.prefix(10).map { $0 }
    }

    // MARK: - Days with Events

    func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return events.contains { calendar.isDate($0.startDate, inSameDayAs: date) }
    }
}

// MARK: - EKAuthorizationStatus helpers

extension EKAuthorizationStatus {
    var isFullAccess: Bool {
        if #available(iOS 17.0, *) {
            return self == .fullAccess
        }
        return self == .authorized
    }
}
