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
