import EventKit
import SwiftUI

// MARK: - Calendar Source Model

struct CalendarSource: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let accountName: String
    let isHoliday: Bool
}

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
    let isNationalHoliday: Bool

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarTitle: String,
        calendarColor: Color,
        notes: String? = nil,
        location: String? = nil,
        isNationalHoliday: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
        self.notes = notes
        self.location = location
        self.isNationalHoliday = isNationalHoliday
    }

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
    var availableCalendars: [CalendarSource] = []
    var disabledCalendarIDs: Set<String> = []
    var showKazakhstanHolidays: Bool = true
    var isLoading = false
    var errorMessage: String? = nil

    private let store = EKEventStore()
    private let disabledKey = "disabled_calendar_ids_v3"
    private let kzHolidaysKey = "show_kz_holidays_enabled_v3"

    var currentCountryCode: String {
        Locale.autoupdatingCurrent.region?.identifier ?? "KZ"
    }

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        loadPreferences()
        setupObservers()
        // Загружаем события сразу при инициализации
        Task {
            await fetchEvents()
        }
    }

    // MARK: - Preferences

    private func loadPreferences() {
        if let saved = UserDefaults.standard.array(forKey: disabledKey) as? [String] {
            disabledCalendarIDs = Set(saved)
        }
        if UserDefaults.standard.object(forKey: kzHolidaysKey) != nil {
            showKazakhstanHolidays = UserDefaults.standard.bool(forKey: kzHolidaysKey)
        } else {
            showKazakhstanHolidays = true // По умолчанию праздники Казахстана включены
        }
    }

    func toggleCalendar(id: String) {
        if disabledCalendarIDs.contains(id) {
            disabledCalendarIDs.remove(id)
        } else {
            disabledCalendarIDs.insert(id)
        }
        UserDefaults.standard.set(Array(disabledCalendarIDs), forKey: disabledKey)
        Task { await fetchEvents() }
    }

    func setKazakhstanHolidays(enabled: Bool) {
        showKazakhstanHolidays = enabled
        UserDefaults.standard.set(enabled, forKey: kzHolidaysKey)
        Task { await fetchEvents() }
    }

    func selectOnlyKazakhstanHolidays() {
        showKazakhstanHolidays = true
        UserDefaults.standard.set(true, forKey: kzHolidaysKey)
        // Отключаем все календари телефона
        let allIDs = availableCalendars.map { $0.id }
        disabledCalendarIDs = Set(allIDs)
        UserDefaults.standard.set(Array(disabledCalendarIDs), forKey: disabledKey)
        Task { await fetchEvents() }
    }

    func enableAllCalendars() {
        showKazakhstanHolidays = true
        UserDefaults.standard.set(true, forKey: kzHolidaysKey)
        disabledCalendarIDs.removeAll()
        UserDefaults.standard.set([], forKey: disabledKey)
        Task { await fetchEvents() }
    }

    // MARK: - Observers
    
    private func setupObservers() {
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
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            
            await fetchEvents()
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

    func fetchEvents(daysAhead: Int? = nil) async {
        await MainActor.run { isLoading = true }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        // Диапазон: 3 полных года (прошлый, текущий, следующий год)
        var startComps = DateComponents()
        startComps.year = currentYear - 1
        startComps.month = 1
        startComps.day = 1
        let startDate = calendar.date(from: startComps) ?? now

        var endComps = DateComponents()
        endComps.year = currentYear + 1
        endComps.month = 12
        endComps.day = 31
        endComps.hour = 23
        endComps.minute = 59
        let endDate = calendar.date(from: endComps) ?? now

        var fetchedPhoneEvents: [CalendarEvent] = []
        var sources: [CalendarSource] = []

        // 1. Получаем календари телефона, если есть доступ
        if isAuthorized {
            let ekCalendars = store.calendars(for: .event)
            
            sources = ekCalendars.map { cal in
                let cgColor = cal.cgColor
                let uiColor = cgColor.map { UIColor(cgColor: $0) } ?? UIColor.systemBlue
                let titleLower = cal.title.lowercased()
                let isHoliday = titleLower.contains("праздник") || titleLower.contains("holiday")
                return CalendarSource(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    color: Color(uiColor),
                    accountName: cal.source.title,
                    isHoliday: isHoliday
                )
            }

            // При первом запуске автоматически отключаем календари России
            var currentDisabled = disabledCalendarIDs
            if !UserDefaults.standard.bool(forKey: "calendar_initialized_v3") {
                UserDefaults.standard.set(true, forKey: "calendar_initialized_v3")
                if currentCountryCode != "RU" {
                    for cal in ekCalendars {
                        let titleLower = cal.title.lowercased()
                        if titleLower.contains("росси") || titleLower.contains("russia") {
                            currentDisabled.insert(cal.calendarIdentifier)
                        }
                    }
                    disabledCalendarIDs = currentDisabled
                    UserDefaults.standard.set(Array(currentDisabled), forKey: disabledKey)
                }
            }

            let activeCalendars = ekCalendars.filter { !currentDisabled.contains($0.calendarIdentifier) }

            if !activeCalendars.isEmpty {
                fetchedPhoneEvents = await Task.detached { [store, activeCalendars] () -> [CalendarEvent] in
                    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: activeCalendars)
                    let rawEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

                    return rawEvents.map { event in
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
                            location: event.location,
                            isNationalHoliday: false
                        )
                    }
                }.value
            }
        }

        // 2. Добавляем государственные праздники Казахстана (независимо от доступа к телефону)
        var allEvents = fetchedPhoneEvents
        if showKazakhstanHolidays {
            let kzHolidays = generateKazakhstanHolidays(from: startDate, to: endDate)
            allEvents.append(contentsOf: kzHolidays)
        }
        allEvents.sort { $0.startDate < $1.startDate }

        await MainActor.run {
            self.availableCalendars = sources
            self.events = allEvents
            self.isLoading = false
        }
    }

    // MARK: - Kazakhstan Holidays Generator

    func generateKazakhstanHolidays(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        let calendar = Calendar.autoupdatingCurrent
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        var holidays: [CalendarEvent] = []

        // Все официальные государственные и национальные праздники Республики Казахстан
        let fixedHolidays: [(day: Int, month: Int, title: String, desc: String)] = [
            (1, 1, "Новый год 🇰🇿", "Государственный праздник"),
            (2, 1, "Новый год (2-й день) 🇰🇿", "Государственный праздник"),
            (7, 1, "Православное Рождество 🇰🇿", "Выходной праздничный день"),
            (8, 3, "Международный женский день 🇰🇿", "Государственный праздник"),
            (21, 3, "Наурыз мейрамы 🇰🇿", "Государственный весенний праздник"),
            (22, 3, "Наурыз мейрамы (2-й день) 🇰🇿", "Государственный весенний праздник"),
            (23, 3, "Наурыз мейрамы (3-й день) 🇰🇿", "Государственный весенний праздник"),
            (1, 5, "Праздник единства народа Казахстана 🇰🇿", "Государственный праздник"),
            (7, 5, "День защитника Отечества 🇰🇿", "Государственный праздник"),
            (9, 5, "День Победы 🇰🇿", "Государственный праздник"),
            (6, 7, "День Столицы 🇰🇿", "Государственный праздник"),
            (30, 8, "День Конституции Республики Казахстан 🇰🇿", "Государственный праздник"),
            (25, 10, "День Республики (Национальный праздник) 🇰🇿", "Главный национальный праздник Казахстана"),
            (16, 12, "День Независимости Республики Казахстан 🇰🇿", "Государственный праздник")
        ]

        let kzColor = Color(hex: "00afca") // Официальный бирюзовый цвет Казахстана

        for year in startYear...endYear {
            for h in fixedHolidays {
                var comps = DateComponents()
                comps.year = year
                comps.month = h.month
                comps.day = h.day
                comps.hour = 0
                comps.minute = 0
                comps.second = 0

                if let holidayDate = calendar.date(from: comps) {
                    let endHolidayDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: holidayDate) ?? holidayDate
                    holidays.append(
                        CalendarEvent(
                            id: "kz_holiday_\(year)_\(h.month)_\(h.day)",
                            title: h.title,
                            startDate: holidayDate,
                            endDate: endHolidayDate,
                            isAllDay: true,
                            calendarTitle: "Праздники Казахстана",
                            calendarColor: kzColor,
                            notes: h.desc,
                            location: "Казахстан",
                            isNationalHoliday: true
                        )
                    )
                }
            }

            // Добавляем официальный праздничный день Курбан-айт (первый день)
            let kurbanAytDates: [Int: (month: Int, day: Int)] = [
                2024: (6, 17),
                2025: (6, 6),
                2026: (5, 27),
                2027: (5, 16)
            ]
            if let kurban = kurbanAytDates[year] {
                var kComps = DateComponents()
                kComps.year = year
                kComps.month = kurban.month
                kComps.day = kurban.day
                if let kDate = calendar.date(from: kComps) {
                    let kEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: kDate) ?? kDate
                    holidays.append(
                        CalendarEvent(
                            id: "kz_holiday_\(year)_kurban",
                            title: "Курбан-айт 🇰🇿",
                            startDate: kDate,
                            endDate: kEnd,
                            isAllDay: true,
                            calendarTitle: "Праздники Казахстана",
                            calendarColor: kzColor,
                            notes: "Священный праздник Курбан-айт (выходной день в РК)",
                            location: "Казахстан",
                            isNationalHoliday: true
                        )
                    )
                }
            }
        }

        return holidays
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
        guard isAuthorized else {
            await MainActor.run {
                errorMessage = "Для создания событий требуется доступ к календарю в Настройках."
            }
            return false
        }

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
        let calendar = Calendar.autoupdatingCurrent
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    var todayEvents: [CalendarEvent] {
        eventsGrouped(for: Date())
    }

    var upcomingEvents: [CalendarEvent] {
        let calendar = Calendar.autoupdatingCurrent
        let now = calendar.startOfDay(for: Date())
        return events.filter { $0.startDate >= now }.prefix(15).map { $0 }
    }

    // Список всех государственных праздников Казахстана на текущий год
    var currentYearKazakhstanHolidays: [CalendarEvent] {
        let calendar = Calendar.autoupdatingCurrent
        let year = calendar.component(.year, from: Date())
        var start = DateComponents(); start.year = year; start.month = 1; start.day = 1
        var end = DateComponents(); end.year = year; end.month = 12; end.day = 31
        let s = calendar.date(from: start) ?? Date()
        let e = calendar.date(from: end) ?? Date()
        return generateKazakhstanHolidays(from: s, to: e)
    }

    // MARK: - Days with Events

    func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
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
