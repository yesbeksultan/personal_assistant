import Combine
import Foundation

public enum FinancePeriod: String, CaseIterable, Equatable {
    case day = "День"
    case week = "Неделя"
    case month = "Месяц"
    case year = "Год"
}

/// Service for communicating with Google Gemini API
final class GeminiService: ObservableObject {
    static let shared = GeminiService()
        
        // MARK: - Configuration
        // ВНИМАНИЕ: Для продакшена перенесите хранение ключа в Keychain!
        private var apiKey: String {
            UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        }
        
        private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        
        private var systemPrompt: String {
            let now = Date()
            let cal = Calendar.current

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ru_RU")
            dateFormatter.dateFormat = "d MMMM yyyy"
            let dateStr = dateFormatter.string(from: now)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeStr = timeFormatter.string(from: now)

            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: "ru_RU")
            weekdayFormatter.dateFormat = "EEEE"
            let weekdayStr = weekdayFormatter.string(from: now).capitalized

            let hour = cal.component(.hour, from: now)
            let timeOfDay: String
            switch hour {
            case 5..<12:  timeOfDay = "утро"
            case 12..<17: timeOfDay = "день"
            case 17..<22: timeOfDay = "вечер"
            default:      timeOfDay = "ночь"
            }

            let tzName = TimeZone.current.localizedName(for: .standard, locale: Locale(identifier: "ru_RU")) ?? TimeZone.current.identifier

            return """
            Ты — Friday, персональный AI-ассистент. Ты помогаешь пользователю с:
            1. Управлением задачами — помогаешь планировать день, расставлять приоритеты.
            2. Финансами — даёшь советы по бюджету, анализируешь расходы.
            3. Общими вопросами — отвечаешь на любые вопросы.

            Отвечай кратко, дружелюбно и по делу. Используй эмодзи для наглядности.
            Язык общения — русский.

            ТЕКУЩЕЕ ВРЕМЯ И ДАТА:
            - Дата: \(dateStr) (\(weekdayStr))
            - Время: \(timeStr) (\(timeOfDay))
            - Часовой пояс: \(tzName)

            Всегда используй эти данные при ответах на вопросы о времени, дате, дне недели и т.п.
            Никогда не говори что не знаешь текущую дату или время.
            """
        }
        
        @Published var isLoading = false
        
        // MARK: - Formatters (Optimized)
        private static let shortDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "dd.MM.yyyy"
            return df
        }()
        
        private static let timeDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ru_RU")
            df.dateFormat = "d MMMM, HH:mm"
            return df
        }()
        
        // MARK: - Public Methods
        
        func sendMessage(
            _ message: String,
            period: FinancePeriod? = nil,
            context: [ChatMessage] = [],
            tasks: [TaskItem] = [],
            transactions: [Transaction] = [],
            calendarEvents: [CalendarEvent] = []
        ) async throws -> String {
            guard !apiKey.isEmpty else {
                return "⚠️ API ключ не настроен. Перейди в Настройки → введи свой Gemini API ключ.\n\nПолучить ключ: https://aistudio.google.com/"
            }
            
            // Включаем индикатор загрузки и гарантируем его отключение при выходе
            isLoading = true
            defer { isLoading = false }
            
            let url = URL(string: "\(baseURL)?key=\(apiKey)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 1. Формируем динамические системные инструкции (Контекст)
            var dynamicPrompt = systemPrompt
            
            let txForContext: [Transaction] = period != nil ? filter(transactions: transactions, by: period!) : transactions
            
            if !tasks.isEmpty || !txForContext.isEmpty || !calendarEvents.isEmpty {
                dynamicPrompt += "\n\nТЕКУЩИЙ КОНТЕКСТ ПОЛЬЗОВАТЕЛЯ:\n"
                
                // Задачи
                let pendingTasks = tasks.filter { !$0.isCompleted }
                dynamicPrompt += "Незавершённых задач: \(pendingTasks.count). "
                if !pendingTasks.isEmpty {
                    dynamicPrompt += "Приоритетные: " + pendingTasks.prefix(3).map { $0.title }.joined(separator: ", ") + ".\n"
                }
                
                // Финансы
                if let period = period {
                    let income = txForContext.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
                    let expense = txForContext.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
                    dynamicPrompt += "Финансы за период (\(period.rawValue)): доход: \(Int(income)) ₸, расход: \(Int(expense)) ₸.\n"
                    
                    if !txForContext.isEmpty {
                        // Ограничиваем список транзакций, чтобы не превысить лимит токенов API
                        let limitedTx = txForContext.prefix(50)
                        dynamicPrompt += "Последние транзакции (\(limitedTx.count) шт.):\n"
                        for tx in limitedTx {
                            let sign = tx.type == .income ? "+" : "-"
                            let line = "- \(Self.shortDateFormatter.string(from: tx.date)) [\(tx.type.rawValue)] \(tx.title) — \(sign)\(Int(tx.amount)) ₸ (\(tx.category))"
                            dynamicPrompt += line + "\n"
                        }
                    }
                }
                
                // Календарь
                if !calendarEvents.isEmpty {
                    dynamicPrompt += "\nПредстоящие события (\(calendarEvents.count) шт.):\n"
                    for event in calendarEvents {
                        let timeStr = event.isAllDay ? "весь день" : Self.timeDateFormatter.string(from: event.startDate)
                        var line = "- \(timeStr): \(event.title)"
                        if let loc = event.location, !loc.isEmpty { line += " [\(loc)]" }
                        dynamicPrompt += line + "\n"
                    }
                }
            }
            
            // 2. Собираем историю диалога
            var contents: [[String: Any]] = []
            let recentContext = context.suffix(10) // Ограничиваем историю 10 сообщениями
            
            for msg in recentContext {
                contents.append([
                    "role": msg.isFromUser ? "user" : "model",
                    "parts": [["text": msg.content]]
                ])
            }
            
            // Добавляем текущее сообщение пользователя
            contents.append([
                "role": "user",
                "parts": [["text": message]]
            ])
            
            // 3. Формируем итоговый JSON (используем нативный systemInstruction)
            let body: [String: Any] = [
                "systemInstruction": [
                    "parts": [["text": dynamicPrompt]]
                ],
                "contents": contents,
                "generationConfig": [
                    "temperature": 0.7,
                    "topP": 0.95,
                    "topK": 40,
                    "maxOutputTokens": 1024
                ]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            // 4. Выполняем сетевой запрос
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GeminiError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                throw GeminiError.parsingError
            }
            
            return text
        }
    
    /// Generate daily summary using AI
    func generateDailySummary(tasks: [TaskItem], transactions: [Transaction]) async throws -> String {
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let todayTransactions = transactions.filter { Calendar.current.isDateInToday($0.date) }
        
        var prompt = "Составь краткую вечернюю сводку дня:\n\n"
        
        prompt += "📋 Незавершённые задачи (\(pendingTasks.count)):\n"
        for task in pendingTasks.prefix(10) {
            prompt += "- \(task.title) [\(task.priority.rawValue)]\n"
        }
        
        let todayExpenses = todayTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        let todayIncome = todayTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        prompt += "\n💰 Финансы за сегодня:\n"
        prompt += "- Доходы: \(Int(todayIncome)) ₸\n"
        prompt += "- Расходы: \(Int(todayExpenses)) ₸\n"
        
        prompt += "\nДай краткие рекомендации на вечер и на завтра."
        
        return try await sendMessage(prompt)
    }
    
    func setApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "gemini_api_key")
    }
    
    var hasApiKey: Bool {
        !apiKey.isEmpty
    }
    
    private func filter(transactions: [Transaction], by period: FinancePeriod) -> [Transaction] {
        let cal = Calendar.current
        return transactions.filter { tx in
            switch period {
            case .day:
                return cal.isDateInToday(tx.date)
            case .week:
                return cal.isDate(tx.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(tx.date, equalTo: Date(), toGranularity: .month)
            case .year:
                return cal.isDate(tx.date, equalTo: Date(), toGranularity: .year)
            }
        }
    }
}

enum GeminiError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .apiError(let message):
            return "Ошибка API: \(message)"
        case .parsingError:
            return "Ошибка обработки ответа"
        }
    }
}
