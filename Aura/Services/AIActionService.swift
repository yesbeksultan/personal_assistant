import Foundation
import SwiftData
import SwiftUI

// MARK: - Action Payloads

struct TaskActionPayload: Codable, Hashable {
    let title: String
    let dueDate: String?
    let priority: String?
    let category: String?
}

struct TransactionActionPayload: Codable, Hashable {
    let title: String
    let amount: Double
    let type: String // "expense" or "income"
    let category: String?
}

enum AIAction: Hashable {
    case task(TaskActionPayload)
    case transaction(TransactionActionPayload)
}

// MARK: - AI Action Service

final class AIActionService {
    static let shared = AIActionService()
    
    private init() {}
    
    // MARK: - Extraction from Message Text
    
    static func extractActions(from text: String) -> (cleanText: String, actions: [AIAction]) {
        var actions: [AIAction] = []
        var clean = text
        
        // 1. Extract Task Actions: <<<ACTION_TASK:{...}>>>
        let taskPattern = #"<<<ACTION_TASK:(\{.*?\})>>>"#
        if let regex = try? NSRegularExpression(pattern: taskPattern, options: [.dotMatchesLineSeparators]) {
            let nsText = clean as NSString
            let matches = regex.matches(in: clean, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let jsonRange = Range(match.range(at: 1), in: clean) {
                    let jsonString = String(clean[jsonRange])
                    if let data = jsonString.data(using: .utf8),
                       let payload = try? JSONDecoder().decode(TaskActionPayload.self, from: data) {
                        actions.append(.task(payload))
                    }
                }
            }
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: nsText.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Extract Transaction Actions: <<<ACTION_TRANSACTION:{...}>>>
        let txPattern = #"<<<ACTION_TRANSACTION:(\{.*?\})>>>"#
        if let regex = try? NSRegularExpression(pattern: txPattern, options: [.dotMatchesLineSeparators]) {
            let nsText = clean as NSString
            let matches = regex.matches(in: clean, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let jsonRange = Range(match.range(at: 1), in: clean) {
                    let jsonString = String(clean[jsonRange])
                    if let data = jsonString.data(using: .utf8),
                       let payload = try? JSONDecoder().decode(TransactionActionPayload.self, from: data) {
                        actions.append(.transaction(payload))
                    }
                }
            }
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: NSRange(location: 0, length: nsText.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return (clean, actions)
    }
    
    // MARK: - Execution into SwiftData
    
    @MainActor
    static func execute(actions: [AIAction], in context: ModelContext) {
        guard !actions.isEmpty else { return }
        
        for action in actions {
            switch action {
            case .task(let payload):
                let resolvedDueDate = payload.dueDate.flatMap { parseDate($0) }
                let resolvedPriority = resolvePriority(payload.priority)
                let resolvedCategory = payload.category ?? "Общее"
                
                let task = TaskItem(
                    title: payload.title,
                    taskDescription: "Создано ассистентом Friday",
                    category: resolvedCategory,
                    priority: resolvedPriority,
                    dueDate: resolvedDueDate
                )
                context.insert(task)
                
                if let due = resolvedDueDate, due > Date() {
                    NotificationService.shared.scheduleTaskReminder(for: task)
                }
                
            case .transaction(let payload):
                let isIncome = payload.type.lowercased() == "income"
                let resolvedType: TransactionType = isIncome ? .income : .expense
                let defaultCategory = isIncome ? "💼 Зарплата" : "📦 Другое"
                let resolvedCategory = payload.category ?? defaultCategory
                
                let tx = Transaction(
                    title: payload.title,
                    amount: payload.amount,
                    type: resolvedType,
                    category: resolvedCategory,
                    date: Date(),
                    note: "Записано ассистентом Friday"
                )
                context.insert(tx)
            }
        }
        
        try? context.save()
    }
    
    // MARK: - Date Parsing Helper
    
    static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isoFormatter = ISO8601DateFormatter()
        if let d = isoFormatter.date(from: trimmed) {
            return d
        }
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.autoupdatingCurrent
        
        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: trimmed) {
                return d
            }
        }
        
        return nil
    }
    
    // MARK: - Priority Helper
    
    private static func resolvePriority(_ raw: String?) -> TaskPriority {
        guard let raw = raw?.lowercased().trimmingCharacters(in: .whitespaces) else { return .medium }
        if raw.contains("urgent") || raw.contains("сроч") { return .urgent }
        if raw.contains("high") || raw.contains("высок") { return .high }
        if raw.contains("low") || raw.contains("низк") { return .low }
        return .medium
    }
}

