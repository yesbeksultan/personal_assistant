import Foundation
import SwiftData
import SwiftUI

@Observable
class ChatViewModel {
    var messageText = ""
    var isLoading = false
    var errorMessage: String? = nil
    var session: ChatSession?
    
    private let geminiService = GeminiService.shared
    
    @MainActor
    func sendMessage(context: ModelContext, messages: [ChatMessage], tasks: [TaskItem] = [], transactions: [Transaction] = []) async {
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
        
        do {
            let response = try await geminiService.sendMessage(text, context: messages, tasks: tasks, transactions: transactions)
            let aiMessage = ChatMessage(content: response, isFromUser: false, session: session)
            context.insert(aiMessage)
        } catch {
            errorMessage = error.localizedDescription
            let errorMsg = ChatMessage(content: "❌ Ошибка: \(error.localizedDescription)", isFromUser: false, session: session)
            context.insert(errorMsg)
        }
        
        isLoading = false
    }
    
    @MainActor
    func generateDailySummary(context: ModelContext, tasks: [TaskItem], transactions: [Transaction]) async {
        isLoading = true
        
        let summaryRequest = ChatMessage(content: "📊 Запрос вечерней сводки...", isFromUser: true, session: session)
        context.insert(summaryRequest)
        
        do {
            let summary = try await geminiService.generateDailySummary(tasks: tasks, transactions: transactions)
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
}
