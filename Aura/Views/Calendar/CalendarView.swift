import SwiftUI
import EventKit

// MARK: - Calendar View

struct CalendarView: View {
    @State private var calendarService = CalendarService.shared
    @State private var selectedDate = Date()
    @State private var showCreateEvent = false
    @State private var currentMonth = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                if !calendarService.isAuthorized {
                    permissionView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if calendarService.isAuthorized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateEvent = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventSheet(selectedDate: selectedDate) {
                    Task { await calendarService.fetchEvents() }
                }
            }
            .task {
                if calendarService.isAuthorized {
                    await calendarService.fetchEvents()
                }
            }
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(Color(hex: "667eea"))
            }

            VStack(spacing: 10) {
                Text("Доступ к Календарю")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Friday может читать и создавать события, чтобы помогать тебе планировать день и передавать расписание ассистенту.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await calendarService.requestAccess() }
            } label: {
                Text("Разрешить доступ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
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

    // MARK: - Mini Calendar

    private var miniCalendar: some View {
        VStack(spacing: 0) {
            // Month navigation header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        .padding(8)
                }

                Spacer()

                Text(monthTitle(currentMonth))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
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
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
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
                    Text("Нет событий")
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
            !Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }.prefix(7)

        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ближайшие события")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

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
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) { return "Сегодня" }
        if cal.isDateInTomorrow(selectedDate) { return "Завтра" }
        if cal.isDateInYesterday(selectedDate) { return "Вчера" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f.string(from: selectedDate)
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }

    private func daysInMonth(_ date: Date) -> [Date?] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return [] }

        // weekday offset (Monday = 1)
        let weekday = cal.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7 // Mon=0 … Sun=6

        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            if let day = cal.date(byAdding: .day, value: d - 1, to: firstDay) {
                days.append(day)
            }
        }
        // pad to full rows
        while days.count % 7 != 0 { days.append(nil) }
        return days
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

                    Text("\(Calendar.current.component(.day, from: date))")
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
                    .fill(isSelected ? Color.white.opacity(0.7) : Color(hex: "667eea"))
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
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if showDate {
                        Text(shortDate(event.startDate))
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.45))
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
                    .font(.system(size: 10))
                    .foregroundStyle(event.calendarColor.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(event.calendarColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(12)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
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
        let cal = Calendar.current
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
            let success = await calendarService.createEvent(
                title: title,
                startDate: isAllDay ? Calendar.current.startOfDay(for: startDate) : startDate,
                endDate: isAllDay ? Calendar.current.startOfDay(for: endDate) : endDate,
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

#Preview {
    CalendarView()
}
