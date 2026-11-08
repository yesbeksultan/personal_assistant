import Foundation
import SwiftData
import SwiftUI

// MARK: - Date Filters

enum TaskDateFilter: Hashable, Identifiable {
    case all
    case today
    case tomorrow
    case thisWeek
    case thisMonth
    case overdue
    case noDate
    case custom(Date)
    
    var id: String {
        switch self {
        case .all: return "all"
        case .today: return "today"
        case .tomorrow: return "tomorrow"
        case .thisWeek: return "thisWeek"
        case .thisMonth: return "thisMonth"
        case .overdue: return "overdue"
        case .noDate: return "noDate"
        case .custom(let date):
            let start = Calendar.autoupdatingCurrent.startOfDay(for: date)
            return "custom_\(start.timeIntervalSince1970)"
        }
    }
    
    var title: String {
        switch self {
        case .all: return "Все"
        case .today: return "Сегодня"
        case .tomorrow: return "Завтра"
        case .thisWeek: return "Неделя"
        case .thisMonth: return "Месяц"
        case .overdue: return "Просрочено"
        case .noDate: return "Без даты"
        case .custom(let date):
            let f = DateFormatter()
            f.locale = Locale.autoupdatingCurrent
            f.dateFormat = "d MMM"
            return f.string(from: date)
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.2.fill"
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeek: return "calendar.badge.clock"
        case .thisMonth: return "calendar"
        case .overdue: return "exclamationmark.circle.fill"
        case .noDate: return "tray.fill"
        case .custom: return "calendar.circle.fill"
        }
    }
    
    static let standardFilters: [TaskDateFilter] = [
        .all,
        .today,
        .tomorrow,
        .thisWeek,
        .thisMonth,
        .overdue,
        .noDate
    ]
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .all: hasher.combine(0)
        case .today: hasher.combine(1)
        case .tomorrow: hasher.combine(2)
        case .thisWeek: hasher.combine(3)
        case .thisMonth: hasher.combine(4)
        case .overdue: hasher.combine(5)
        case .noDate: hasher.combine(6)
        case .custom(let date):
            hasher.combine(7)
            let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
            hasher.combine(day)
        }
    }
    
    static func == (lhs: TaskDateFilter, rhs: TaskDateFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all),
             (.today, .today),
             (.tomorrow, .tomorrow),
             (.thisWeek, .thisWeek),
             (.thisMonth, .thisMonth),
             (.overdue, .overdue),
             (.noDate, .noDate):
            return true
        case (.custom(let d1), .custom(let d2)):
            return Calendar.autoupdatingCurrent.isDate(d1, inSameDayAs: d2)
        default:
            return false
        }
    }
}

// Backward-compatible enum for any legacy callers
enum TaskTimeFilter: String, CaseIterable, Identifiable {
    case all = "Все"
    case today = "Сегодня"
    case upcoming = "Предстоящие"
    case noDate = "Без даты"
    
    var id: String { rawValue }
}

enum TaskTimeGroup: String, CaseIterable, Identifiable {
    case overdue = "overdue"
    case today = "today"
    case tomorrow = "tomorrow"
    case thisWeek = "thisWeek"
    case later = "later"
    case noDate = "noDate"
    case completed = "completed"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overdue: return "Просроченные"
        case .today: return "Сегодня"
        case .tomorrow: return "Завтра"
        case .thisWeek: return "На этой неделе"
        case .later: return "Позже"
        case .noDate: return "Без даты"
        case .completed: return "Выполненные"
        }
    }
    
    var icon: String {
        switch self {
        case .overdue: return "exclamationmark.circle.fill"
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeek: return "calendar.badge.clock"
        case .later: return "calendar"
        case .noDate: return "tray.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var colorHex: String {
        switch self {
        case .overdue: return "f5576c"
        case .today: return "4facfe"
        case .tomorrow: return "667eea"
        case .thisWeek: return "43e97b"
        case .later: return "a8edea"
        case .noDate: return "a0a5b5"
        case .completed: return "38ef7d"
        }
    }
}

struct TaskTimeSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let colorHex: String
    var tasks: [TaskItem]
}

@Observable
class TaskViewModel {
    var searchText = ""
    var selectedCategory = "Все"
    var selectedDateFilter: TaskDateFilter = .all
    var selectedCustomDate: Date = Date()
    var showCompleted = false
    
    // Convenience helper for new task due dates based on active filter
    var initialDueDateForNewTask: Date? {
        let calendar = Calendar.autoupdatingCurrent
        switch selectedDateFilter {
        case .today:
            return Date()
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: Date())
        case .custom(let date):
            return date
        default:
            return nil
        }
    }
    
    // MARK: - Time & Date Grouping
    
    func groupedTasks(_ tasks: [TaskItem]) -> [TaskTimeSection] {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let endOfWeek = weekInterval?.end ?? calendar.date(byAdding: .day, value: 7, to: startOfToday)!
        
        // 1. Initial filter by search & category
        var baseTasks = tasks
        
        if selectedCategory != "Все" {
            baseTasks = baseTasks.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            baseTasks = baseTasks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 2. Separate active and completed
        let activeTasks = baseTasks.filter { !$0.isCompleted }
        let completedTasks = baseTasks.filter { $0.isCompleted }
        
        let sortByTimeAndPriority: (TaskItem, TaskItem) -> Bool = { t1, t2 in
            if let d1 = t1.dueDate, let d2 = t2.dueDate {
                if d1 != d2 {
                    return d1 < d2
                }
            }
            if t1.priority != t2.priority {
                return self.priorityOrder(t1.priority) > self.priorityOrder(t2.priority)
            }
            return t1.createdAt > t2.createdAt
        }
        
        var sections: [TaskTimeSection] = []
        
        switch selectedDateFilter {
        case .all:
            var overdue: [TaskItem] = []
            var today: [TaskItem] = []
            var tomorrow: [TaskItem] = []
            var thisWeek: [TaskItem] = []
            var later: [TaskItem] = []
            var noDate: [TaskItem] = []
            
            for task in activeTasks {
                guard let due = task.dueDate else {
                    noDate.append(task)
                    continue
                }
                
                if due < startOfToday {
                    overdue.append(task)
                } else if calendar.isDateInToday(due) {
                    today.append(task)
                } else if calendar.isDateInTomorrow(due) {
                    tomorrow.append(task)
                } else if due < endOfWeek {
                    thisWeek.append(task)
                } else {
                    later.append(task)
                }
            }
            
            overdue.sort(by: sortByTimeAndPriority)
            today.sort(by: sortByTimeAndPriority)
            tomorrow.sort(by: sortByTimeAndPriority)
            thisWeek.sort(by: sortByTimeAndPriority)
            later.sort(by: sortByTimeAndPriority)
            noDate.sort(by: sortByTimeAndPriority)
            
            if !overdue.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_overdue",
                    title: "Просроченные",
                    subtitle: "\(overdue.count) требует внимания",
                    icon: "exclamationmark.circle.fill",
                    colorHex: "f5576c",
                    tasks: overdue
                ))
            }
            if !today.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_today",
                    title: "Сегодня",
                    subtitle: dateSubtitle(for: now),
                    icon: "sun.max.fill",
                    colorHex: "4facfe",
                    tasks: today
                ))
            }
            if !tomorrow.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_tomorrow",
                    title: "Завтра",
                    subtitle: dateSubtitle(for: startOfTomorrow),
                    icon: "sunrise.fill",
                    colorHex: "667eea",
                    tasks: tomorrow
                ))
            }
            if !thisWeek.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_thisWeek",
                    title: "На этой неделе",
                    subtitle: "До конца недели",
                    icon: "calendar.badge.clock",
                    colorHex: "43e97b",
                    tasks: thisWeek
                ))
            }
            if !later.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_later",
                    title: "Позже",
                    subtitle: "Будущие сроки",
                    icon: "calendar",
                    colorHex: "a8edea",
                    tasks: later
                ))
            }
            if !noDate.isEmpty {
                sections.append(TaskTimeSection(
                    id: "all_noDate",
                    title: "Без даты",
                    subtitle: "В любое время",
                    icon: "tray.fill",
                    colorHex: "a0a5b5",
                    tasks: noDate
                ))
            }
            
            if showCompleted && !completedTasks.isEmpty {
                var sortedCompleted = completedTasks
                sortedCompleted.sort { $0.createdAt > $1.createdAt }
                sections.append(TaskTimeSection(
                    id: "all_completed",
                    title: "Выполненные",
                    subtitle: "\(completedTasks.count) выполнено",
                    icon: "checkmark.circle.fill",
                    colorHex: "38ef7d",
                    tasks: sortedCompleted
                ))
            }
            
        case .today:
            // Check overdue
            let overdue = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < startOfToday
            }.sorted(by: sortByTimeAndPriority)
            
            let today = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInToday(due)
            }.sorted(by: sortByTimeAndPriority)
            
            if !overdue.isEmpty {
                sections.append(TaskTimeSection(
                    id: "today_overdue",
                    title: "Просрочено ранее",
                    subtitle: "\(overdue.count) требует завершения",
                    icon: "exclamationmark.circle.fill",
                    colorHex: "f5576c",
                    tasks: overdue
                ))
            }
            
            if !today.isEmpty || overdue.isEmpty {
                sections.append(TaskTimeSection(
                    id: "today_main",
                    title: "Сегодня",
                    subtitle: dateSubtitle(for: now),
                    icon: "sun.max.fill",
                    colorHex: "4facfe",
                    tasks: today
                ))
            }
            
            if showCompleted {
                let completedToday = completedTasks.filter {
                    calendar.isDateInToday($0.createdAt) || ($0.dueDate != nil && calendar.isDateInToday($0.dueDate!))
                }
                if !completedToday.isEmpty {
                    sections.append(TaskTimeSection(
                        id: "today_completed",
                        title: "Выполнено сегодня",
                        subtitle: "\(completedToday.count) завершено",
                        icon: "checkmark.circle.fill",
                        colorHex: "38ef7d",
                        tasks: completedToday
                    ))
                }
            }
            
        case .tomorrow:
            let tomorrow = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInTomorrow(due)
            }.sorted(by: sortByTimeAndPriority)
            
            sections.append(TaskTimeSection(
                id: "tomorrow_main",
                title: "Завтра",
                subtitle: dateSubtitle(for: startOfTomorrow),
                icon: "sunrise.fill",
                colorHex: "667eea",
                tasks: tomorrow
            ))
            
            if showCompleted {
                let completedTomorrow = completedTasks.filter {
                    guard let due = $0.dueDate else { return false }
                    return calendar.isDateInTomorrow(due)
                }
                if !completedTomorrow.isEmpty {
                    sections.append(TaskTimeSection(
                        id: "tomorrow_completed",
                        title: "Выполненные на завтра",
                        subtitle: "\(completedTomorrow.count) выполнено",
                        icon: "checkmark.circle.fill",
                        colorHex: "38ef7d",
                        tasks: completedTomorrow
                    ))
                }
            }
            
        case .thisWeek:
            let weekTasks = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                if let interval = weekInterval {
                    return due >= interval.start && due < interval.end
                }
                return due >= startOfToday && due < calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            }
            
            // Group by day of week
            var dayGroups: [Date: [TaskItem]] = [:]
            for task in weekTasks {
                guard let due = task.dueDate else { continue }
                let day = calendar.startOfDay(for: due)
                dayGroups[day, default: []].append(task)
            }
            
            let sortedDays = dayGroups.keys.sorted()
            for day in sortedDays {
                let dayTasks = (dayGroups[day] ?? []).sorted(by: sortByTimeAndPriority)
                let title: String
                if calendar.isDateInToday(day) {
                    title = "Сегодня"
                } else if calendar.isDateInTomorrow(day) {
                    title = "Завтра"
                } else {
                    title = dayOfWeek(for: day)
                }
                
                sections.append(TaskTimeSection(
                    id: "week_day_\(day.timeIntervalSince1970)",
                    title: title,
                    subtitle: dateSubtitle(for: day),
                    icon: "calendar",
                    colorHex: "43e97b",
                    tasks: dayTasks
                ))
            }
            
            if showCompleted {
                let completedWeek = completedTasks.filter {
                    guard let due = $0.dueDate else { return false }
                    if let interval = weekInterval {
                        return due >= interval.start && due < interval.end
                    }
                    return false
                }
                if !completedWeek.isEmpty {
                    sections.append(TaskTimeSection(
                        id: "week_completed",
                        title: "Выполненные на этой неделе",
                        subtitle: "\(completedWeek.count) выполнено",
                        icon: "checkmark.circle.fill",
                        colorHex: "38ef7d",
                        tasks: completedWeek
                    ))
                }
            }
            
        case .thisMonth:
            let monthTasks = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                if let interval = monthInterval {
                    return due >= interval.start && due < interval.end
                }
                return calendar.isDate(due, equalTo: now, toGranularity: .month)
            }
            
            // Split into this week vs rest of month
            let thisWeekMonth = monthTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < endOfWeek
            }.sorted(by: sortByTimeAndPriority)
            
            let laterThisMonth = monthTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due >= endOfWeek
            }.sorted(by: sortByTimeAndPriority)
            
            if !thisWeekMonth.isEmpty {
                sections.append(TaskTimeSection(
                    id: "month_thisWeek",
                    title: "На этой неделе",
                    subtitle: "Текущие дни месяца",
                    icon: "calendar.badge.clock",
                    colorHex: "43e97b",
                    tasks: thisWeekMonth
                ))
            }
            
            if !laterThisMonth.isEmpty {
                sections.append(TaskTimeSection(
                    id: "month_later",
                    title: "Позже в этом месяце",
                    subtitle: "До конца месяца",
                    icon: "calendar",
                    colorHex: "667eea",
                    tasks: laterThisMonth
                ))
            }
            
            if showCompleted {
                let completedMonth = completedTasks.filter {
                    guard let due = $0.dueDate else { return false }
                    return calendar.isDate(due, equalTo: now, toGranularity: .month)
                }
                if !completedMonth.isEmpty {
                    sections.append(TaskTimeSection(
                        id: "month_completed",
                        title: "Выполненные в этом месяце",
                        subtitle: "\(completedMonth.count) выполнено",
                        icon: "checkmark.circle.fill",
                        colorHex: "38ef7d",
                        tasks: completedMonth
                    ))
                }
            }
            
        case .overdue:
            let overdue = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < startOfToday || due < now
            }.sorted(by: sortByTimeAndPriority)
            
            sections.append(TaskTimeSection(
                id: "overdue_all",
                title: "Просроченные задачи",
                subtitle: "\(overdue.count) требует немедленного внимания",
                icon: "exclamationmark.circle.fill",
                colorHex: "f5576c",
                tasks: overdue
            ))
            
        case .noDate:
            let noDate = activeTasks.filter { $0.dueDate == nil }.sorted(by: sortByTimeAndPriority)
            sections.append(TaskTimeSection(
                id: "noDate_all",
                title: "Без даты",
                subtitle: "\(noDate.count) задач в очереди",
                icon: "tray.fill",
                colorHex: "a0a5b5",
                tasks: noDate
            ))
            
        case .custom(let targetDate):
            let customTasks = activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: targetDate)
            }.sorted(by: sortByTimeAndPriority)
            
            sections.append(TaskTimeSection(
                id: "custom_\(targetDate.timeIntervalSince1970)",
                title: dateSubtitle(for: targetDate),
                subtitle: "\(customTasks.count) задач на этот день",
                icon: "calendar.circle.fill",
                colorHex: "4facfe",
                tasks: customTasks
            ))
            
            if showCompleted {
                let completedCustom = completedTasks.filter {
                    guard let due = $0.dueDate else { return false }
                    return calendar.isDate(due, inSameDayAs: targetDate)
                }
                if !completedCustom.isEmpty {
                    sections.append(TaskTimeSection(
                        id: "custom_completed_\(targetDate.timeIntervalSince1970)",
                        title: "Выполнено",
                        subtitle: "\(completedCustom.count) задач завершено",
                        icon: "checkmark.circle.fill",
                        colorHex: "38ef7d",
                        tasks: completedCustom
                    ))
                }
            }
        }
        
        // Remove completely empty sections
        return sections.filter { !$0.tasks.isEmpty }
    }
    
    // MARK: - Filter Counts
    
    func count(for filter: TaskDateFilter, in tasks: [TaskItem]) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        
        var baseTasks = tasks
        if selectedCategory != "Все" {
            baseTasks = baseTasks.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            baseTasks = baseTasks.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        let activeTasks = baseTasks.filter { !$0.isCompleted }
        
        switch filter {
        case .all:
            return activeTasks.count
        case .today:
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInToday(due)
            }.count
        case .tomorrow:
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInTomorrow(due)
            }.count
        case .thisWeek:
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                if let interval = weekInterval {
                    return due >= interval.start && due < interval.end
                }
                return due >= startOfToday && due < calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            }.count
        case .thisMonth:
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                if let interval = monthInterval {
                    return due >= interval.start && due < interval.end
                }
                return calendar.isDate(due, equalTo: now, toGranularity: .month)
            }.count
        case .overdue:
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < startOfToday || due < now
            }.count
        case .noDate:
            return activeTasks.filter { $0.dueDate == nil }.count
        case .custom(let targetDate):
            return activeTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: targetDate)
            }.count
        }
    }
    
    // MARK: - Date Formatting Helpers
    
    private func dateSubtitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: date).capitalized
    }
    
    private func dateSubtitleShort(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized
    }
    
    // MARK: - Filtered List (flat fallback)
    
    func filteredTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        groupedTasks(tasks).flatMap { $0.tasks }
    }
    
    // MARK: - Stats
    
    func todayTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { task in
            !task.isCompleted && (task.dueDate?.isToday ?? false)
        }
    }
    
    func overdueCount(_ tasks: [TaskItem]) -> Int {
        let startOfToday = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        return tasks.filter { !$0.isCompleted && ($0.dueDate != nil && $0.dueDate! < startOfToday) }.count
    }
    
    func pendingCount(_ tasks: [TaskItem]) -> Int {
        tasks.filter { !$0.isCompleted }.count
    }
    
    func completedTodayCount(_ tasks: [TaskItem]) -> Int {
        tasks.filter { $0.isCompleted && Calendar.autoupdatingCurrent.isDateInToday($0.createdAt) }.count
    }
    
    func completionRate(_ tasks: [TaskItem]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = Double(tasks.filter { $0.isCompleted }.count)
        return completed / Double(tasks.count)
    }
    
    private func priorityOrder(_ priority: TaskPriority) -> Int {
        switch priority {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}
