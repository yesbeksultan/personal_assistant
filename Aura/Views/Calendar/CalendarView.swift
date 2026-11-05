import SwiftUI
import EventKit

// MARK: - Calendar View

struct CalendarView: View {
    @State private var calendarService = CalendarService.shared
    @State private var selectedDate = Date()
    @State private var showCreateEvent = false
    @State private var showCalendarFilter = false
    @State private var currentMonth = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                mainContent
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendarFilter = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 16))
                            Text("Календари")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                    }
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventSheet(selectedDate: selectedDate) {
                    Task { await calendarService.fetchEvents() }
                }
            }
            .sheet(isPresented: $showCalendarFilter) {
                CalendarFilterSheet()
            }
            .task {
                await calendarService.fetchEvents()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Если нет доступа к календарю телефона — ненавязчивый баннер
                if !calendarService.isAuthorized {
                    phoneCalendarBanner
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                miniCalendar
                    .padding(.horizontal)

                selectedDaySection
                    .padding(.horizontal)

                upcomingSection
                    .padding(.horizontal)
            }
            .padding(.bottom, 100)
        }
        .refreshable { await calendarService.fetchEvents() }
    }

    // MARK: - Phone Calendar Permission Banner

    private var phoneCalendarBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "667eea"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Синхронизация с iPhone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Подключи личные события телефона")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            }

            Spacer()

            Button {
                Task { await calendarService.requestAccess() }
            } label: {
                Text("Включить")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "667eea"))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(hex: "667eea").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Mini Calendar

    private var miniCalendar: some View {
        VStack(spacing: 0) {
            // Month navigation header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        currentMonth = Calendar.autoupdatingCurrent.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                        .padding(8)
                }

                Spacer()

                Text(monthTitle(currentMonth))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4)) {
                        currentMonth = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                        .padding(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            // Day labels
            HStack {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // Calendar grid
            let days = daysInMonth(currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        CalendarDayCell(
                            date: date,
                            isSelected: Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.autoupdatingCurrent.isDateInToday(date),
                            hasEvents: calendarService.hasEvents(on: date)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Selected Day Section

    private var selectedDaySection: some View {
        let dayEvents = calendarService.eventsGrouped(for: selectedDate)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDayTitle)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if !dayEvents.isEmpty {
                    Text("\(dayEvents.count) событ.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "667eea").opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if dayEvents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    Text("Нет событий на этот день")
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.textPrimary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(dayEvents) { event in
                    CalendarEventRow(event: event)
                }
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        let upcoming = calendarService.upcomingEvents.filter {
            !Calendar.autoupdatingCurrent.isDate($0.startDate, inSameDayAs: selectedDate)
        }.prefix(10)

        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Ближайшие события и праздники")
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                    }

                    ForEach(Array(upcoming)) { event in
                        CalendarEventRow(event: event, showDate: true)
                    }
                }
                .padding(16)
                .background(AppColors.textPrimary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    // MARK: - Helpers

    private var selectedDayTitle: String {
        let cal = Calendar.autoupdatingCurrent
        if cal.isDateInToday(selectedDate) { return "Сегодня" }
        if cal.isDateInTomorrow(selectedDate) { return "Завтра" }
        if cal.isDateInYesterday(selectedDate) { return "Вчера" }
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = "d MMMM"
        return f.string(from: selectedDate)
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }

    private func daysInMonth(_ date: Date) -> [Date?] {
        let cal = Calendar.autoupdatingCurrent
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return [] }

        let weekday = cal.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7 // Mon=0 … Sun=6

        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            if let day = cal.date(byAdding: .day, value: d - 1, to: firstDay) {
                days.append(day)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Calendar Filter Sheet

struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calendarService = CalendarService.shared
    @State private var showHolidaysList = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick Action Buttons
                        HStack(spacing: 10) {
                            Button {
                                calendarService.selectOnlyKazakhstanHolidays()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("🇰🇿")
                                    Text("Только Казахстан")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color(hex: "00afca"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                calendarService.enableAllCalendars()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Включить всё")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(AppColors.textPrimary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Section: Kazakhstan Holidays
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Праздники страны")
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "00afca").opacity(0.15))
                                            .frame(width: 38, height: 38)
                                        Text("🇰🇿")
                                            .font(.system(size: 20))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Праздники Казахстана")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text("Наурыз, День Республики, День Независимости и др.")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { calendarService.showKazakhstanHolidays },
                                        set: { calendarService.setKazakhstanHolidays(enabled: $0) }
                                    ))
                                    .labelsHidden()
                                    .tint(Color(hex: "00afca"))
                                }

                                Divider().opacity(0.15)

                                Button {
                                    withAnimation { showHolidaysList.toggle() }
                                } label: {
                                    HStack {
                                        Text("Все праздники Казахстана на год")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color(hex: "00afca"))
                                        Spacer()
                                        Image(systemName: showHolidaysList ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color(hex: "00afca"))
                                    }
                                }

                                if showHolidaysList {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(calendarService.currentYearKazakhstanHolidays) { holiday in
                                            HStack {
                                                Text(holiday.title)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                                                Spacer()
                                                Text(holiday.startDate.shortFormatted)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Color(hex: "00afca"))
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(14)
                            .background(AppColors.textPrimary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Section: Phone Calendars
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Календари в телефоне")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                Spacer()
                                if !calendarService.isAuthorized {
                                    Button("Разрешить доступ") {
                                        Task { await calendarService.requestAccess() }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(hex: "667eea"))
                                }
                            }

                            if calendarService.availableCalendars.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                                    Text("Календари телефона не подключены")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.textPrimary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(calendarService.availableCalendars) { source in
                                        let isEnabled = !calendarService.disabledCalendarIDs.contains(source.id)
                                        Button {
                                            calendarService.toggleCalendar(id: source.id)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(source.color)
                                                    .frame(width: 12, height: 12)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(source.title)
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundStyle(AppColors.textPrimary)
                                                    Text(source.accountName)
                                                        .font(.caption2)
                                                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                                                }

                                                Spacer()

                                                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 22))
                                                    .foregroundStyle(isEnabled ? Color(hex: "667eea") : AppColors.textPrimary.opacity(0.2))
                                            }
                                            .padding(12)
                                            .background(AppColors.textPrimary.opacity(0.04))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Info hint
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color(hex: "00afca"))
                            Text("Праздники России автоматически отключены. При выборе «Только Казахстан» отображаются государственные праздники РК.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                        }
                        .padding(12)
                        .background(Color(hex: "00afca").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
            .navigationTitle("Настройка календарей")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
        }
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        Circle()
                            .stroke(Color(hex: "667eea"), lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    Text("\(Calendar.autoupdatingCurrent.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? .white
                                : isToday
                                    ? Color(hex: "667eea")
                                    : AppColors.textPrimary.opacity(0.8)
                        )
                }
                .frame(width: 34, height: 34)

                Circle()
                    .fill(isSelected ? Color.white.opacity(0.7) : Color(hex: "00afca"))
                    .frame(width: 4, height: 4)
                    .opacity(hasEvents ? 1 : 0)
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: CalendarEvent
    var showDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Color strip
            RoundedRectangle(cornerRadius: 3)
                .fill(event.calendarColor)
                .frame(width: 4)
                .frame(height: showDate ? 52 : 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    if event.isNationalHoliday {
                        Text("🇰🇿")
                            .font(.caption2)
                    }
                }

                HStack(spacing: 8) {
                    if showDate {
                        Text(shortDate(event.startDate))
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(event.isAllDay ? "Весь день" : timeRange(event.startDate, event.endDate))
                            .font(.caption)
                    }
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                    }
                }

                Text(event.calendarTitle)
                    .font(.system(size: 10, weight: event.isNationalHoliday ? .semibold : .regular))
                    .foregroundStyle(event.calendarColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.calendarColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(12)
        .background(
            event.isNationalHoliday
                ? Color(hex: "00afca").opacity(0.06)
                : AppColors.textPrimary.opacity(0.04)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(event.isNationalHoliday ? Color(hex: "00afca").opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calendarService = CalendarService.shared

    let selectedDate: Date
    let onCreated: () -> Void

    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var notes = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var showError = false

    init(selectedDate: Date, onCreated: @escaping () -> Void) {
        self.selectedDate = selectedDate
        self.onCreated = onCreated
        let cal = Calendar.autoupdatingCurrent
        let start = cal.date(bySettingHour: cal.component(.hour, from: Date()), minute: 0, second: 0, of: selectedDate) ?? selectedDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Название", systemImage: "text.cursor")
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Название события", text: $title)
                                .font(.system(size: 16))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.textPrimary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // All-day toggle
                        HStack {
                            Label("Весь день", systemImage: "sun.max")
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $isAllDay)
                                .tint(Color(hex: "667eea"))
                        }
                        .padding(14)
                        .background(AppColors.textPrimary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Dates
                        VStack(spacing: 0) {
                            DateRow(label: "Начало", icon: "calendar", date: $startDate, isAllDay: isAllDay)
                            Divider().padding(.horizontal, 14).opacity(0.2)
                            DateRow(label: "Конец", icon: "calendar.badge.clock", date: $endDate, isAllDay: isAllDay)
                        }
                        .background(AppColors.textPrimary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Место", systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Необязательно", text: $location)
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.textPrimary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Заметки", systemImage: "note.text")
                                .font(.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Необязательно", text: $notes, axis: .vertical)
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(3...6)
                                .padding(14)
                                .background(AppColors.textPrimary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Новое событие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color(hex: "667eea"))
                        } else {
                            Text("Создать")
                                .fontWeight(.semibold)
                                .foregroundStyle(title.isEmpty ? AppColors.textPrimary.opacity(0.3) : Color(hex: "667eea"))
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(calendarService.errorMessage ?? "Неизвестная ошибка")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let cal = Calendar.autoupdatingCurrent
            let success = await calendarService.createEvent(
                title: title,
                startDate: isAllDay ? cal.startOfDay(for: startDate) : startDate,
                endDate: isAllDay ? cal.startOfDay(for: endDate) : endDate,
                isAllDay: isAllDay,
                notes: notes.isEmpty ? nil : notes,
                location: location.isEmpty ? nil : location
            )
            await MainActor.run {
                isSaving = false
                if success {
                    onCreated()
                    dismiss()
                } else {
                    showError = true
                }
            }
        }
    }
}

// MARK: - Date Row

private struct DateRow: View {
    let label: String
    let icon: String
    @Binding var date: Date
    let isAllDay: Bool

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            DatePicker(
                "",
                selection: $date,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(14)
    }
}
