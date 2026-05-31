import Combine
import Foundation

/// Service for communicating with Google Gemini API
final class GeminiService: ObservableObject {
    static let shared = GeminiService()
    
    // MARK: - Configuration
    // Replace with your actual Gemini API key from https://aistudio.google.com/
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    }
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
    
    private let systemPrompt = """
    Ты — Friday, персональный AI-ассистент. Ты помогаешь пользователю с:
    1. Управлением задачами — помогаешь планировать день, расставлять приоритеты
    2. Финансами — даёшь советы по бюджету, анализируешь расходы
    3. Общими вопросами — отвечаешь на любые вопросы
    
    Отвечай кратко, дружелюбно и по делу. Используй эмодзи для наглядности.
    Язык общения — русский.
    """
    
    @Published var isLoading = false
    
    // MARK: - Public Methods
    
    func sendMessage(_ message: String, context: [ChatMessage] = [], tasks: [TaskItem] = [], transactions: [Transaction] = []) async throws -> String {
        guard !apiKey.isEmpty else {
            return "⚠️ API ключ не настроен. Перейди в Настройки → введи свой Gemini API ключ.\n\nПолучить ключ: https://aistudio.google.com/"
        }
        
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build conversation history
        var contents: [[String: Any]] = []
        
        // Add system instruction
        var dynamicPrompt = systemPrompt
        if !tasks.isEmpty || !transactions.isEmpty {
            dynamicPrompt += "\n\nТекущий контекст пользователя:\n"
            let pendingTasks = tasks.filter { !$0.isCompleted }
            dynamicPrompt += "Незавершённых задач: \(pendingTasks.count). "
            if !pendingTasks.isEmpty {
                dynamicPrompt += "Некоторые из них: " + pendingTasks.prefix(3).map { $0.title }.joined(separator: ", ") + ".\n"
            }
            let monthTransactions = transactions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            let monthIncome = monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let monthExpense = monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            dynamicPrompt += "В этом месяце доход: \(monthIncome) ₸, расход: \(monthExpense) ₸."
        }
        
        let systemInstruction: [String: Any] = [
            "role": "user",
            "parts": [["text": dynamicPrompt]]
        ]
        contents.append(systemInstruction)
        contents.append([
            "role": "model",
            "parts": [["text": "Привет! Я Friday, твой персональный ассистент 🌟 Чем могу помочь?"]]
        ])
        
        // Add recent context (last 10 messages)
        let recentContext = context.suffix(10)
        for msg in recentContext {
            contents.append([
                "role": msg.isFromUser ? "user" : "model",
                "parts": [["text": msg.content]]
            ])
        }
        
        // Add current message
        contents.append([
            "role": "user",
            "parts": [["text": message]]
        ])
        
        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.95,
                "topK": 40,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
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
