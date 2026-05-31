import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var taskDescription: String
    var category: String
    var priority: TaskPriority
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    
    init(
        title: String,
        taskDescription: String = "",
        category: String = "Общее",
        priority: TaskPriority = .medium,
        isCompleted: Bool = false,
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.category = category
        self.priority = priority
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.dueDate = dueDate
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low = "Низкий"
    case medium = "Средний"
    case high = "Высокий"
    case urgent = "Срочный"
    
    var color: String {
        switch self {
        case .low: return "PriorityLow"
        case .medium: return "PriorityMedium"
        case .high: return "PriorityHigh"
        case .urgent: return "PriorityUrgent"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

let taskCategories = [
    "Общее", "Работа", "Учёба", "Здоровье",
    "Покупки", "Дом", "Спорт", "Личное"
]
