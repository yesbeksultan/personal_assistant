import Foundation
import SwiftData
import SwiftUI

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
    let group: TaskTimeGroup
    let title: String
    let subtitle: String?
    let icon: String
    let colorHex: String
    var tasks: [TaskItem]
    
    var id: String { group.id }
}

@Observable
class TaskViewModel {
    var searchText = ""
    var selectedCategory = "Все"
    var selectedTimeFilter: TaskTimeFilter = .all
    var showCompleted = false
    
    // MARK: - Time Grouping
    
    func groupedTasks(_ tasks: [TaskItem]) -> [TaskTimeSection] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        let endOfNext7Days = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
        
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
            } else if due < startOfTomorrow {
                today.append(task)
            } else if due < startOfDayAfterTomorrow {
                tomorrow.append(task)
            } else if due < endOfNext7Days {
                thisWeek.append(task)
            } else {
                later.append(task)
            }
        }
        
        // Sort chronologically by due date (earliest first), then by priority
        let sortByTime: (TaskItem, TaskItem) -> Bool = { t1, t2 in
            if let d1 = t1.dueDate, let d2 = t2.dueDate {
                if d1 != d2 {
                    return d1 < d2
                }
            }
            return self.priorityOrder(t1.priority) > self.priorityOrder(t2.priority)
        }
        
        overdue.sort(by: sortByTime)
        today.sort(by: sortByTime)
        tomorrow.sort(by: sortByTime)
        thisWeek.sort(by: sortByTime)
        later.sort(by: sortByTime)
        
        // Sort tasks without dates by priority and creation time
        noDate.sort { t1, t2 in
            if t1.priority != t2.priority {
                return self.priorityOrder(t1.priority) > self.priorityOrder(t2.priority)
            }
            return t1.createdAt > t2.createdAt
        }
        
        var sections: [TaskItemSectionBuilder] = []
        
        switch selectedTimeFilter {
        case .all:
            if !overdue.isEmpty {
                sections.append(.init(group: .overdue, tasks: overdue, subtitle: "\(overdue.count) требует внимания"))
            }
            if !today.isEmpty || (selectedTimeFilter == .all && overdue.isEmpty && tomorrow.isEmpty && thisWeek.isEmpty && later.isEmpty && noDate.isEmpty) {
                sections.append(.init(group: .today, tasks: today, subtitle: dateSubtitle(for: now)))
            }
            if !tomorrow.isEmpty {
                sections.append(.init(group: .tomorrow, tasks: tomorrow, subtitle: dateSubtitle(for: startOfTomorrow)))
            }
            if !thisWeek.isEmpty {
                sections.append(.init(group: .thisWeek, tasks: thisWeek, subtitle: "Ближайшие 7 дней"))
            }
            if !later.isEmpty {
                sections.append(.init(group: .later, tasks: later, subtitle: "Будущие сроки"))
            }
            if !noDate.isEmpty {
                sections.append(.init(group: .noDate, tasks: noDate, subtitle: "В любое время"))
            }
            
        case .today:
            if !overdue.isEmpty {
                sections.append(.init(group: .overdue, tasks: overdue, subtitle: "Просрочено"))
            }
            sections.append(.init(group: .today, tasks: today, subtitle: dateSubtitle(for: now)))
            
        case .upcoming:
            if !tomorrow.isEmpty {
                sections.append(.init(group: .tomorrow, tasks: tomorrow, subtitle: dateSubtitle(for: startOfTomorrow)))
            }
            if !thisWeek.isEmpty {
                sections.append(.init(group: .thisWeek, tasks: thisWeek, subtitle: "Ближайшие 7 дней"))
            }
            if !later.isEmpty {
                sections.append(.init(group: .later, tasks: later, subtitle: "Будущие сроки"))
            }
            
        case .noDate:
            sections.append(.init(group: .noDate, tasks: noDate, subtitle: "Без привязки ко времени"))
        }
        
        // Add completed tasks if enabled
        if showCompleted && !completedTasks.isEmpty {
            var sortedCompleted = completedTasks
            sortedCompleted.sort { $0.createdAt > $1.createdAt }
            sections.append(.init(group: .completed, tasks: sortedCompleted, subtitle: "\(completedTasks.count) выполнено"))
        }
        
        return sections.compactMap { builder in
            guard !builder.tasks.isEmpty else { return nil }
            return TaskTimeSection(
                group: builder.group,
                title: builder.group.title,
                subtitle: builder.subtitle,
                icon: builder.group.icon,
                colorHex: builder.group.colorHex,
                tasks: builder.tasks
            )
        }
    }
    
    private func dateSubtitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
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
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return tasks.filter { !$0.isCompleted && ($0.dueDate != nil && $0.dueDate! < startOfToday) }.count
    }
    
    func pendingCount(_ tasks: [TaskItem]) -> Int {
        tasks.filter { !$0.isCompleted }.count
    }
    
    func completedTodayCount(_ tasks: [TaskItem]) -> Int {
        tasks.filter { $0.isCompleted && Calendar.current.isDateInToday($0.createdAt) }.count
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

private struct TaskItemSectionBuilder {
    let group: TaskTimeGroup
    var tasks: [TaskItem]
    var subtitle: String?
}
