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
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    }
    
    // Используется одна фиксированная модель
    private let modelName = "gemini-3.1-flash-lite"
    
    private var systemPrompt: String {
        let now = Date()
        let cal = Calendar.autoupdatingCurrent
        let locale = Locale.autoupdatingCurrent

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateFormat = "d MMMM yyyy"
        let dateStr = dateFormatter.string(from: now)

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: now)

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = locale
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

        let tzName = TimeZone.autoupdatingCurrent.localizedName(for: .standard, locale: locale) ?? TimeZone.autoupdatingCurrent.identifier

        return """
        Ты — Friday, персональный AI-ассистент. Ты помогаешь пользователю с:
        1. Управлением задачами — помогаешь планировать день, расставлять приоритеты.
        2. Финансами — даёшь советы по бюджету, анализируешь расходы.
        3. Общими вопросами — отвечаешь на любые вопросы, даёшь полезные советы.

        Отвечай кратко, ёмко, дружелюбно и по делу. Используй эмодзи для наглядности.
        Язык общения — русский (или язык запроса пользователя).

        ТЕКУЩЕЕ ВРЕМЯ И РЕГИОН:
        - Дата: \(dateStr) (\(weekdayStr))
        - Время: \(timeStr) (\(timeOfDay))
        - Часовой пояс: \(tzName)
        - Регион устройства: \(locale.region?.identifier ?? "KZ")

        Всегда используй эти данные при ответах на вопросы о времени, дате и дне недели.
        
        ДЕЙСТВИЯ (ACTIONS):
        Ты умеешь напрямую создавать задачи и записывать расходы/доходы в приложение!
        Когда пользователь просит СОЗДАТЬ, ЗАПЛАНИРОВАТЬ, НАПОМНИТЬ задачу или ЗАПИСАТЬ расход/доход, в самом конце своего ответа обязательно добавь соответствующий тег:

        1. Создание задачи:
        <<<ACTION_TASK:{"title": "Название задачи", "dueDate": "YYYY-MM-DDTHH:mm:ss", "priority": "low|medium|high|urgent", "category": "Общее|Работа|Учёба|Здоровье|Дом|Личное"}>>>
        * Если дата/время не указаны пользователем, поле dueDate опусти или оставь null.
        * Всегда вычисляй точную дату от текущей (\(dateStr) \(timeStr)) в формате yyyy-MM-dd'T'HH:mm:ss.

        2. Запись дохода или расхода:
        <<<ACTION_TRANSACTION:{"title": "Название", "amount": 2500, "type": "expense|income", "category": "Категория"}>>>
        * Категории расходов: 🍔 Еда, 🚗 Транспорт, 🏠 Жильё, 🎮 Развлечения, 👕 Одежда, 💊 Здоровье, 📚 Образование, 💡 Коммуналка, 📱 Связь, 🎁 Подарки, ✈️ Путешествия, 📦 Другое.
        * Категории доходов: 💼 Зарплата, 💰 Фриланс, 📈 Инвестиции, 🎁 Подарки, 💵 Другое.

        Правило: добавляй тег ТОЛЬКО когда пользователь явно просит добавить, записать, напомнить или создать. При обычных вопросах или советах тег НЕ добавляй.
        """
    }
    
    @Published var isLoading = false
    
    // MARK: - Formatters
    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.dateFormat = "dd.MM"
        return df
    }()
    
    private static let timeDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.autoupdatingCurrent
        df.dateFormat = "d MMM, HH:mm"
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
            return "⚠️ API ключ не настроен. Перейди в Настройки → введи свой Gemini API ключ.\n\nПолучить ключ бесплатно: https://aistudio.google.com/"
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // 1. Формируем компактные системные инструкции
        var dynamicPrompt = systemPrompt
        
        // Быстрый справочник погоды или валюты (локально, без расхода токенов)
        if let detection = WebSearchDetector.detect(from: message) {
            switch detection.intent {
            case .weather, .currency:
                if let directInfo = try? await WebSearchService.shared.search(query: detection.query, intent: detection.intent) {
                    dynamicPrompt += "\n\nДАННЫЕ СПРАВОЧНИКА:\n\(directInfo)\n"
                }
            case .general:
                break
            }
        }
        
        // Включаем контекст только по необходимости, чтобы не раздувать токены
        var contextLines: [String] = []
        
        // Задачи: только если есть активные, кратко
        let pendingTasks = tasks.filter { !$0.isCompleted }
        if !pendingTasks.isEmpty {
            let topTasks = pendingTasks.prefix(3).map { $0.title }.joined(separator: ", ")
            contextLines.append("Задачи (\(pendingTasks.count) шт.): приоритетные: \(topTasks)")
        }
        
        // Финансы: включаем подробности только если явно выбран финансовый режим или вопрос про деньги
        let mentionsFinance = message.lowercased().contains("расход") ||
                              message.lowercased().contains("доход") ||
                              message.lowercased().contains("трат") ||
                              message.lowercased().contains("баланс") ||
                              message.lowercased().contains("бюджет") ||
                              period != nil
        
        if mentionsFinance && !transactions.isEmpty {
            let txFiltered = period != nil ? filter(transactions: transactions, by: period!) : transactions
            let income = txFiltered.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expense = txFiltered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            contextLines.append("Финансы: доход \(Int(income)) ₸, расход \(Int(expense)) ₸ (баланс: \(Int(income - expense)) ₸)")
            
            // Последние 5 операций
            let recentTx = txFiltered.prefix(5)
            if !recentTx.isEmpty {
                let txList = recentTx.map { tx in
                    let sign = tx.type == .income ? "+" : "-"
                    return "\(Self.shortDateFormatter.string(from: tx.date)) \(tx.title) (\(sign)\(Int(tx.amount)) ₸)"
                }.joined(separator: "; ")
                contextLines.append("Последние операции: \(txList)")
            }
        }
        
        // Календарь: только если переданы события
        if !calendarEvents.isEmpty {
            let topEvents = calendarEvents.prefix(3).map { event in
                let timeStr = event.isAllDay ? "весь день" : Self.timeDateFormatter.string(from: event.startDate)
                return "\(timeStr): \(event.title)"
            }.joined(separator: "; ")
            contextLines.append("События: \(topEvents)")
        }
        
        if !contextLines.isEmpty {
            dynamicPrompt += "\n\nКОНТЕКСТ:\n" + contextLines.joined(separator: "\n")
        }
        
        // 2. Компактная история диалога (последние 5 сообщений)
        var contents: [[String: Any]] = []
        let recentContext = context.suffix(5)
        
        for msg in recentContext {
            contents.append([
                "role": msg.isFromUser ? "user" : "model",
                "parts": [["text": msg.content]]
            ])
        }
        
        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])
        
        // 3. Выполняем прямой сетевой запрос к одной модели
        return try await performGenerateRequest(systemInstruction: dynamicPrompt, contents: contents)
    }
    
    // MARK: - Direct Request Execution
    
    private func performGenerateRequest(
        systemInstruction: String,
        contents: [[String: Any]]
    ) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.95,
                "topK": 40,
                "maxOutputTokens": 800
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw GeminiError.rateLimited
            }
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
        let todayTransactions = transactions.filter { Calendar.autoupdatingCurrent.isDateInToday($0.date) }
        
        var prompt = "Составь краткую вечернюю сводку дня:\n\n"
        
        prompt += "📋 Незавершённые задачи (\(pendingTasks.count)):\n"
        for task in pendingTasks.prefix(6) {
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
        let cal = Calendar.autoupdatingCurrent
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
    case rateLimited
    case apiError(String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .rateLimited:
            return "⏳ Лимит запросов Gemini исчерпан (429). Подожди 10 секунд и отправь запрос снова."
        case .apiError(let message):
            return "Ошибка API: \(message)"
        case .parsingError:
            return "Ошибка обработки ответа"
        }
    }
}
