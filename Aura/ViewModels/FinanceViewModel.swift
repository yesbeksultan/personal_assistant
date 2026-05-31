import Foundation
import SwiftData
import SwiftUI

@Observable
class FinanceViewModel {
    var selectedPeriod: TimePeriod = .month
    var selectedType: TransactionType? = nil
    
    enum TimePeriod: String, CaseIterable {
        case week = "Неделя"
        case month = "Месяц"
        case all = "Всё время"
    }
    
    func filteredTransactions(_ transactions: [Transaction]) -> [Transaction] {
        var result = transactions
        
        // Filter by period
        switch selectedPeriod {
        case .week:
            result = result.filter { $0.date.isThisWeek }
        case .month:
            result = result.filter { $0.date.isThisMonth }
        case .all:
            break
        }
        
        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        // Sort by date (newest first)
        result.sort { $0.date > $1.date }
        
        return result
    }
    
    func totalIncome(_ transactions: [Transaction]) -> Double {
        filteredTransactions(transactions)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    func totalExpenses(_ transactions: [Transaction]) -> Double {
        filteredTransactions(transactions)
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    func balance(_ transactions: [Transaction]) -> Double {
        totalIncome(transactions) - totalExpenses(transactions)
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
    
    /// Get expenses grouped by category
    func expensesByCategory(_ transactions: [Transaction]) -> [(category: String, amount: Double, percentage: Double)] {
        let expenses = filteredTransactions(transactions).filter { $0.type == .expense }
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
