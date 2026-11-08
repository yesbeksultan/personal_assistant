import Foundation
import SwiftData
import SwiftUI

enum ChatFunction: String, CaseIterable, Identifiable {
    case finance  = "Финансы"
    case calendar = "Календарь"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .finance:  return "chart.bar.fill"
        case .calendar: return "calendar"
        }
    }
    var emoji: String {
        switch self {
        case .finance:  return "💰"
        case .calendar: return "📅"
        }
    }
    var description: String {
        switch self {
        case .finance:  return "Передаёт список транзакций"
        case .calendar: return "Передаёт события календаря"
        }
    }
}

@Observable
class ChatViewModel {
    var messageText = ""
    var isLoading = false
    var errorMessage: String? = nil
    var session: ChatSession?
    
    // Active function context
    var activeFunction: ChatFunction? = nil
    var selectedPeriod: FinancePeriod? = nil
    
    private let geminiService = GeminiService.shared
    
    @MainActor
    func sendMessage(
        context: ModelContext,
        messages: [ChatMessage],
        tasks: [TaskItem]? = nil,
        transactions: [Transaction]? = nil,
        events: [CalendarEvent] = []
    ) async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        if let session = session, session.title == "Новый чат", text.lowercased() != "привет" {
            let prefix = String(text.prefix(30))
            session.title = prefix + (text.count > 30 ? "..." : "")
        }
        
        // Add user message
        let userMessage = ChatMessage(content: text, isFromUser: true, session: session)
        context.insert(userMessage)
        messageText = ""
        isLoading = true
        errorMessage = nil
        
        // Fetch context on-demand only when needed
        let resolvedTasks = tasks ?? fetchRecentTasks(context: context)
        let resolvedTransactions = transactions ?? fetchRecentTransactions(context: context)
        
        do {
            let period = (activeFunction == .finance) ? selectedPeriod : nil
            let calEvents = (activeFunction == .calendar) ? events : []
            let response = try await geminiService.sendMessage(
                text,
                period: period,
                context: messages,
                tasks: resolvedTasks,
                transactions: resolvedTransactions,
                calendarEvents: calEvents
            )

            // Execute any extracted direct actions (creating tasks, logging expenses/income)
            let (_, actions) = AIActionService.extractActions(from: response)
            if !actions.isEmpty {
                AIActionService.execute(actions: actions, in: context)
            }

            let aiMessage = ChatMessage(content: response, isFromUser: false, session: session)
            context.insert(aiMessage)
            try? context.save()
        } catch {
            errorMessage = error.localizedDescription
            let errorMsg = ChatMessage(content: "❌ Ошибка: \(error.localizedDescription)", isFromUser: false, session: session)
            context.insert(errorMsg)
        }
        
        isLoading = false
    }
    
    func clearActiveFunction() {
        activeFunction = nil
        selectedPeriod = nil
    }
    
    @MainActor
    func generateDailySummary(
        context: ModelContext,
        tasks: [TaskItem]? = nil,
        transactions: [Transaction]? = nil
    ) async {
        isLoading = true
        
        let summaryRequest = ChatMessage(content: "📊 Запрос вечерней сводки...", isFromUser: true, session: session)
        context.insert(summaryRequest)
        
        let resolvedTasks = tasks ?? fetchRecentTasks(context: context)
        let resolvedTransactions = transactions ?? fetchRecentTransactions(context: context)
        
        do {
            let summary = try await geminiService.generateDailySummary(tasks: resolvedTasks, transactions: resolvedTransactions)
            let aiMessage = ChatMessage(content: summary, isFromUser: false, session: session)
            context.insert(aiMessage)
        } catch {
            let errorMsg = ChatMessage(content: "❌ Не удалось создать сводку: \(error.localizedDescription)", isFromUser: false, session: session)
            context.insert(errorMsg)
        }
        
        isLoading = false
    }
    
    func clearHistory(context: ModelContext, messages: [ChatMessage]) {
        for message in messages {
            context.delete(message)
        }
    }
    
    // MARK: - Private On-Demand Context Fetching (Zero overhead when not chatting)
    
    private func fetchRecentTasks(context: ModelContext) -> [TaskItem] {
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        descriptor.fetchLimit = 25
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchRecentTransactions(context: ModelContext) -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 25
        return (try? context.fetch(descriptor)) ?? []
    }
}
