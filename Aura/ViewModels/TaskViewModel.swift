import Foundation
import SwiftData
import SwiftUI

@Observable
class TaskViewModel {
    var searchText = ""
    var selectedCategory = "Все"
    var showCompleted = false
    
    func filteredTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var result = tasks
        
        // Filter by completion
        if !showCompleted {
            result = result.filter { !$0.isCompleted }
        }
        
        // Filter by category
        if selectedCategory != "Все" {
            result = result.filter { $0.category == selectedCategory }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort: urgent first, then by due date
        result.sort { task1, task2 in
            if task1.priority != task2.priority {
                return priorityOrder(task1.priority) > priorityOrder(task2.priority)
            }
            if let d1 = task1.dueDate, let d2 = task2.dueDate {
                return d1 < d2
            }
            return task1.createdAt > task2.createdAt
        }
        
        return result
    }
    
    func todayTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { task in
            !task.isCompleted && (task.dueDate?.isToday ?? false || task.dueDate == nil)
        }
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
