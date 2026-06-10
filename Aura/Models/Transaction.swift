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

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let expenseKey = "customExpenseCategories"
    private let incomeKey  = "customIncomeCategories"
    private let suggestKey = "customCategorySuggestions"

    var customExpenseCategories: [String] = []
    var customIncomeCategories: [String] = []
    var customSuggestions: [String: [String]] = [:]

    private init() {
        loadFromStore()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: .iCloudKVStoreDidChange,
            object: nil
        )
    }

    @objc private func kvStoreChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.loadFromStore()
        }
    }

    private func loadFromStore() {
        // iCloud KV Store сначала, фолбек на UserDefaults
        if let expenses = kvStore.array(forKey: expenseKey) as? [String] {
            customExpenseCategories = expenses
        } else if let saved = UserDefaults.standard.stringArray(forKey: expenseKey) {
            customExpenseCategories = saved
        }

        if let incomes = kvStore.array(forKey: incomeKey) as? [String] {
            customIncomeCategories = incomes
        } else if let saved = UserDefaults.standard.stringArray(forKey: incomeKey) {
            customIncomeCategories = saved
        }

        if let suggestions = kvStore.dictionary(forKey: suggestKey) as? [String: [String]] {
            customSuggestions = suggestions
        } else if let saved = UserDefaults.standard.dictionary(forKey: suggestKey) as? [String: [String]] {
            customSuggestions = saved
        }
    }

    private func persistExpenses() {
        kvStore.set(customExpenseCategories, forKey: expenseKey)
        UserDefaults.standard.set(customExpenseCategories, forKey: expenseKey)
        kvStore.synchronize()
        iCloudService.shared.markSynced()
    }

    private func persistIncomes() {
        kvStore.set(customIncomeCategories, forKey: incomeKey)
        UserDefaults.standard.set(customIncomeCategories, forKey: incomeKey)
        kvStore.synchronize()
        iCloudService.shared.markSynced()
    }

    private func persistSuggestions() {
        kvStore.set(customSuggestions, forKey: suggestKey)
        UserDefaults.standard.set(customSuggestions, forKey: suggestKey)
        kvStore.synchronize()
    }

    func addCategory(_ category: String, type: TransactionType, suggestions: [String] = []) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if type == .expense {
            if !expenseCategories.contains(trimmed) && !customExpenseCategories.contains(trimmed) {
                customExpenseCategories.append(trimmed)
                persistExpenses()
            }
        } else {
            if !incomeCategories.contains(trimmed) && !customIncomeCategories.contains(trimmed) {
                customIncomeCategories.append(trimmed)
                persistIncomes()
            }
        }

        if !suggestions.isEmpty {
            customSuggestions[trimmed] = suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            persistSuggestions()
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
