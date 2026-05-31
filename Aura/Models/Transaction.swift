import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var type: TransactionType
    var category: String
    var date: Date
    var note: String
    
    init(
        title: String,
        amount: Double,
        type: TransactionType,
        category: String,
        date: Date = Date(),
        note: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "Доход"
    case expense = "Расход"
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.left"
        case .expense: return "arrow.up.right"
        }
    }
}

let expenseCategories = [
    "🍔 Еда", "🚗 Транспорт", "🏠 Жильё", "🎮 Развлечения",
    "👕 Одежда", "💊 Здоровье", "📚 Образование", "💡 Коммуналка",
    "📱 Связь", "🎁 Подарки", "✈️ Путешествия", "📦 Другое"
]

let incomeCategories = [
    "💼 Зарплата", "💰 Фриланс", "📈 Инвестиции",
    "🎁 Подарки", "💵 Другое"
]

@Observable
final class FinanceCategoryStore {
    static let shared = FinanceCategoryStore()
    
    var customExpenseCategories: [String] = []
    var customIncomeCategories: [String] = []
    var customSuggestions: [String: [String]] = [:]
    
    private init() {
        if let savedExpenses = UserDefaults.standard.stringArray(forKey: "customExpenseCategories") {
            self.customExpenseCategories = savedExpenses
        }
        if let savedIncomes = UserDefaults.standard.stringArray(forKey: "customIncomeCategories") {
            self.customIncomeCategories = savedIncomes
        }
        if let savedSuggestions = UserDefaults.standard.dictionary(forKey: "customCategorySuggestions") as? [String: [String]] {
            self.customSuggestions = savedSuggestions
        }
    }
    
    func addCategory(_ category: String, type: TransactionType, suggestions: [String] = []) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if type == .expense {
            if !expenseCategories.contains(trimmed) && !customExpenseCategories.contains(trimmed) {
                customExpenseCategories.append(trimmed)
                UserDefaults.standard.set(customExpenseCategories, forKey: "customExpenseCategories")
            }
        } else {
            if !incomeCategories.contains(trimmed) && !customIncomeCategories.contains(trimmed) {
                customIncomeCategories.append(trimmed)
                UserDefaults.standard.set(customIncomeCategories, forKey: "customIncomeCategories")
            }
        }
        
        if !suggestions.isEmpty {
            customSuggestions[trimmed] = suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            UserDefaults.standard.set(customSuggestions, forKey: "customCategorySuggestions")
        }
    }
    
    func suggestions(for category: String) -> [String]? {
        customSuggestions[category]
    }
    
    func allCategories(for type: TransactionType) -> [String] {
        if type == .expense {
            return expenseCategories + customExpenseCategories
        } else {
            return incomeCategories + customIncomeCategories
        }
    }
}
