import Foundation
import SwiftData
import SwiftUI

@Observable
class FinanceViewModel {
    var selectedPeriod: TimePeriod = .month
    var selectedSection: FinanceSection = .expenses
    var selectedType: TransactionType? = nil
    
    enum FinanceSection: String, CaseIterable, Identifiable {
        case expenses = "Расходы"
        case income = "Доходы"
        case all = "Обзор"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .expenses: return "arrow.up.right"
            case .income:   return "arrow.down.left"
            case .all:      return "chart.pie.fill"
            }
        }
        
        var accentColor: Color {
            switch self {
            case .expenses: return Color(hex: "fa709a")
            case .income:   return Color(hex: "43e97b")
            case .all:      return Color(hex: "667eea")
            }
        }
    }
    
    enum TimePeriod: String, CaseIterable {
        case week = "Неделя"
        case month = "Месяц"
        case all = "Всё время"
    }
    
    // MARK: - Filtering
    
    /// Transactions filtered purely by selected period (week, month, all)
    func periodFilteredTransactions(_ transactions: [Transaction]) -> [Transaction] {
        var result = transactions
        switch selectedPeriod {
        case .week:
            result = result.filter { $0.date.isThisWeek }
        case .month:
            result = result.filter { $0.date.isThisMonth }
        case .all:
            break
        }
        result.sort { $0.date > $1.date }
        return result
    }
    
    /// Transactions filtered by period AND section/type
    func filteredTransactions(_ transactions: [Transaction]) -> [Transaction] {
        var result = periodFilteredTransactions(transactions)
        
        if let type = selectedType {
            result = result.filter { $0.type == type }
        } else {
            switch selectedSection {
            case .expenses:
                result = result.filter { $0.type == .expense }
            case .income:
                result = result.filter { $0.type == .income }
            case .all:
                break
            }
        }
        
        return result
    }
    
    /// Explicitly get income transactions for selected period
    func filteredIncomeTransactions(_ transactions: [Transaction]) -> [Transaction] {
        periodFilteredTransactions(transactions).filter { $0.type == .income }
    }
    
    /// Explicitly get expense transactions for selected period
    func filteredExpenseTransactions(_ transactions: [Transaction]) -> [Transaction] {
        periodFilteredTransactions(transactions).filter { $0.type == .expense }
    }
    
    // MARK: - Period Totals
    
    func totalIncome(_ transactions: [Transaction]) -> Double {
        periodFilteredTransactions(transactions)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    func totalExpenses(_ transactions: [Transaction]) -> Double {
        periodFilteredTransactions(transactions)
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    func balance(_ transactions: [Transaction]) -> Double {
        totalIncome(transactions) - totalExpenses(transactions)
    }
    
    // MARK: - All-Time Totals (To avoid manual calculation)
    
    func totalIncomeAllTime(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    func totalExpensesAllTime(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    func balanceAllTime(_ transactions: [Transaction]) -> Double {
        totalIncomeAllTime(transactions) - totalExpensesAllTime(transactions)
    }
    
    // MARK: - Month & Today Stats
    
    func monthIncome(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .income && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    func monthExpenses(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .expense && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    func todayExpenses(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .expense && $0.date.isToday }
            .reduce(0) { $0 + $1.amount }
    }
    
    func todayIncome(_ transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .income && $0.date.isToday }
            .reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Category Breakdowns
    
    /// Get expenses grouped by category for selected period
    func expensesByCategory(_ transactions: [Transaction]) -> [(category: String, amount: Double, percentage: Double)] {
        let expenses = periodFilteredTransactions(transactions).filter { $0.type == .expense }
        let total = expenses.reduce(0) { $0 + $1.amount }
        
        guard total > 0 else { return [] }
        
        var categoryTotals: [String: Double] = [:]
        for expense in expenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        
        return categoryTotals
            .map { (category: $0.key, amount: $0.value, percentage: $0.value / total) }
            .sorted { $0.amount > $1.amount }
    }
    
    /// Get income grouped by category for selected period
    func incomeByCategory(_ transactions: [Transaction]) -> [(category: String, amount: Double, percentage: Double)] {
        let incomes = periodFilteredTransactions(transactions).filter { $0.type == .income }
        let total = incomes.reduce(0) { $0 + $1.amount }
        
        guard total > 0 else { return [] }
        
        var categoryTotals: [String: Double] = [:]
        for income in incomes {
            categoryTotals[income.category, default: 0] += income.amount
        }
        
        return categoryTotals
            .map { (category: $0.key, amount: $0.value, percentage: $0.value / total) }
            .sorted { $0.amount > $1.amount }
    }
    
    /// Get spending for last 7 days
    func last7DaysSpending(_ transactions: [Transaction]) -> [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        var result: [(date: Date, amount: Double)] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!.startOfDay
            let dayExpenses = transactions
                .filter { $0.type == .expense && calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            result.append((date: date, amount: dayExpenses))
        }
        
        return result.reversed()
    }
}
