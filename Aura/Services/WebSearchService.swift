import Foundation

// MARK: - Search Result Model

struct WebSearchResult {
    let title: String
    let snippet: String
    let url: String
    let source: String // "serper" | "wikipedia" | "weather" | "currency"
}

// MARK: - Web Search Service

/// Многоуровневый сервис поиска в интернете для AI-агента Friday.
///
/// Уровни (в порядке приоритета):
///   1. Serper.dev — полный Google-поиск, 2500 бесплатных запросов (нужен ключ из serper.dev)
///   2. Wikipedia REST API — факты/биографии/определения (без ключа)
///   3. wttr.in — погода (без ключа)
///   4. open.er-api.com — курсы валют (без ключа)
final class WebSearchService {
    static let shared = WebSearchService()
    private init() {}

    // MARK: - API Keys (сохраняются в UserDefaults)

    var serperApiKey: String {
        get { UserDefaults.standard.string(forKey: "serper_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "serper_api_key") }
    }

    var hasSerperKey: Bool { !serperApiKey.isEmpty }

    // MARK: - Public

    /// Умный поиск: выбирает нужный источник в зависимости от запроса.
    /// - Returns: отформатированная строка с результатами для вставки в промпт Gemini
    func search(query: String, intent: SearchIntent = .general) async throws -> String {
        // Маршрутизация по типу запроса
        switch intent {
        case .weather(let city):
            return try await searchWeather(city: city)
        case .currency(let from, let to):
            return try await searchCurrency(from: from, to: to)
        case .general:
            // Пробуем Serper если есть ключ, иначе Wikipedia
            if hasSerperKey {
                return try await searchSerper(query: query)
            } else {
                return try await searchWikipedia(query: query)
            }
        }
    }

    // MARK: - 1. Serper.dev (Google Search JSON API)

    private func searchSerper(query: String) async throws -> String {
        guard let url = URL(string: "https://google.serper.dev/search") else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serperApiKey, forHTTPHeaderField: "X-API-KEY")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "q": query,
            "num": 5,
            "hl": "ru"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WebSearchError.networkError("Serper: non-200 response")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WebSearchError.parsingError
        }

        var output = "🌐 Результаты Google-поиска по «\(query)»:\n\n"

        // Answer Box (прямой ответ)
        if let answerBox = json["answerBox"] as? [String: Any] {
            let answer = (answerBox["answer"] as? String)
                ?? (answerBox["snippet"] as? String)
                ?? ""
            if !answer.isEmpty {
                output += "✅ **Прямой ответ:** \(answer)\n\n"
            }
        }

        // Knowledge Graph
        if let kg = json["knowledgeGraph"] as? [String: Any],
           let desc = kg["description"] as? String {
            let title = kg["title"] as? String ?? ""
            output += "📖 **\(title):** \(desc)\n\n"
        }

        // Organic results
        if let organic = json["organic"] as? [[String: Any]] {
            for (i, result) in organic.prefix(5).enumerated() {
                let title = result["title"] as? String ?? ""
                let snippet = result["snippet"] as? String ?? ""
                let link = result["link"] as? String ?? ""
                output += "\(i + 1). **\(title)**\n   \(snippet)\n   🔗 \(link)\n\n"
            }
        }

        return output.isEmpty ? "🔍 По запросу «\(query)» ничего не найдено." : output
    }

    // MARK: - 2. Wikipedia REST API (без ключа)

    private func searchWikipedia(query: String) async throws -> String {
        // Шаг 1: поиск статей
        var searchComponents = URLComponents(string: "https://ru.wikipedia.org/w/rest.php/v1/search/page")!
        searchComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "3")
        ]

        guard let searchURL = searchComponents.url else { throw WebSearchError.invalidURL }

        var searchRequest = URLRequest(url: searchURL)
        searchRequest.setValue("friday-ai-app/1.0 (personal assistant)", forHTTPHeaderField: "User-Agent")
        searchRequest.timeoutInterval = 10

        let (searchData, _) = try await URLSession.shared.data(for: searchRequest)
        guard let searchJson = try JSONSerialization.jsonObject(with: searchData) as? [String: Any],
              let pages = searchJson["pages"] as? [[String: Any]],
              let firstPage = pages.first,
              let pageTitle = firstPage["title"] as? String else {
            return "🔍 Wikipedia: по запросу «\(query)» ничего не найдено."
        }

        // Шаг 2: получаем summary первой статьи
        let encodedTitle = pageTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pageTitle
        guard let summaryURL = URL(string: "https://ru.wikipedia.org/w/rest.php/v1/page/\(encodedTitle)/summary") else {
            throw WebSearchError.invalidURL
        }

        var summaryRequest = URLRequest(url: summaryURL)
        summaryRequest.setValue("friday-ai-app/1.0 (personal assistant)", forHTTPHeaderField: "User-Agent")
        summaryRequest.timeoutInterval = 10

        let (summaryData, _) = try await URLSession.shared.data(for: summaryRequest)
        guard let summaryJson = try JSONSerialization.jsonObject(with: summaryData) as? [String: Any] else {
            throw WebSearchError.parsingError
        }

        let extract = summaryJson["extract"] as? String ?? ""
        let contentURL = (summaryJson["content_urls"] as? [String: Any])?["desktop"] as? [String: Any]
        let articleURL = contentURL?["page"] as? String ?? ""

        var output = "📖 Из Wikipedia по запросу «\(query)»:\n\n"
        output += "**\(pageTitle)**\n"
        if !extract.isEmpty {
            // Берём первые 600 символов чтобы не раздувать промпт
            let excerpt = String(extract.prefix(600))
            output += "\(excerpt)...\n"
        }
        if !articleURL.isEmpty {
            output += "\n🔗 Источник: \(articleURL)\n"
        }

        // Другие страницы из поиска
        if pages.count > 1 {
            output += "\nСвязанные статьи: "
            output += pages.dropFirst().prefix(2).compactMap { $0["title"] as? String }.joined(separator: ", ")
            output += "\n"
        }

        return output
    }

    // MARK: - 3. wttr.in (погода, без ключа)

    private func searchWeather(city: String) async throws -> String {
        let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? city
        guard let url = URL(string: "https://wttr.in/\(encodedCity)?format=j1&lang=ru") else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("friday-ai-app/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = (json["current_condition"] as? [[String: Any]])?.first else {
            throw WebSearchError.networkError("wttr.in недоступен")
        }

        let tempC = current["temp_C"] as? String ?? "?"
        let feelsLike = current["FeelsLikeC"] as? String ?? "?"
        let humidity = current["humidity"] as? String ?? "?"
        let windKmph = current["windspeedKmph"] as? String ?? "?"
        let desc = (current["lang_ru"] as? [[String: Any]])?.first?["value"] as? String
            ?? (current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String
            ?? "?"

        var output = "🌤 Погода в \(city) (данные wttr.in):\n\n"
        output += "🌡 Температура: **\(tempC)°C** (ощущается как \(feelsLike)°C)\n"
        output += "💧 Влажность: \(humidity)%\n"
        output += "💨 Ветер: \(windKmph) км/ч\n"
        output += "☁️ Условия: \(desc)\n"

        // Прогноз на 3 дня
        if let weather = json["weather"] as? [[String: Any]] {
            output += "\n📅 Прогноз:\n"
            for day in weather.prefix(3) {
                let date = day["date"] as? String ?? ""
                let maxT = day["maxtempC"] as? String ?? "?"
                let minT = day["mintempC"] as? String ?? "?"
                let dayDesc = ((day["hourly"] as? [[String: Any]])?.first?["lang_ru"] as? [[String: Any]])?.first?["value"] as? String ?? ""
                output += "  • \(date): \(minT)°C — \(maxT)°C \(dayDesc)\n"
            }
        }

        return output
    }

    // MARK: - 4. open.er-api.com (курсы валют, без ключа)

    private func searchCurrency(from: String, to: String) async throws -> String {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(from.uppercased())") else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Double] else {
            throw WebSearchError.parsingError
        }

        let toUpper = to.uppercased()
        guard let rate = rates[toUpper] else {
            return "💱 Не удалось найти курс \(from)/\(to)"
        }

        let updateTime = json["time_last_update_utc"] as? String ?? ""
        var output = "💱 Курс валют (open.er-api.com):\n\n"
        output += "**1 \(from.uppercased()) = \(String(format: "%.4f", rate)) \(toUpper)**\n"

        // Популярные пары
        let popular = ["USD", "EUR", "RUB", "KZT", "GBP", "CNY"]
        output += "\nПопулярные курсы к \(from.uppercased()):\n"
        for currency in popular {
            if currency != from.uppercased(), let r = rates[currency] {
                output += "  • \(currency): \(String(format: "%.2f", r))\n"
            }
        }

        if !updateTime.isEmpty {
            output += "\n_Обновлено: \(updateTime)_\n"
        }

        return output
    }
}

// MARK: - Search Intent

/// Намерение поискового запроса — определяется в WebSearchDetector
enum SearchIntent {
    case general
    case weather(city: String)
    case currency(from: String, to: String)
}

// MARK: - Errors

enum WebSearchError: LocalizedError {
    case invalidURL
    case networkError(String)
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Некорректный URL"
        case .networkError(let m): return "Ошибка сети: \(m)"
        case .parsingError:     return "Ошибка разбора ответа"
        }
    }
}

// MARK: - Query Detector

/// Анализирует сообщение пользователя и решает нужен ли поиск и какого типа.
struct WebSearchDetector {

    struct DetectionResult {
        let query: String
        let intent: SearchIntent
    }

    // MARK: Triggers

    private static let weatherCities = [
        "алматы", "астана", "москва", "нур-султан", "шымкент", "бишкек",
        "ташкент", "минск", "киев", "алма-ата", "актау", "атырау",
        "london", "new york", "dubai", "berlin", "paris", "tokyo"
    ]

    private static let currencyKeywords = [
        "курс доллара", "курс евро", "курс рубля", "курс тенге",
        "курс валют", "usd", "eur", "rub", "kzt", "btc", "биткоин",
        "доллар к тенге", "евро к тенге", "доллар к рублю"
    ]

    private static let weatherKeywords = [
        "погода", "температура", "прогноз погоды", "weather", "дождь", "снег"
    ]

    private static let generalSearchTriggers = [
        "найди", "найти", "поищи", "поиск", "погугли", "search", "google",
        "последние новости", "свежие новости", "новости сегодня",
        "кто такой", "что такое", "расскажи о ", "биография",
        "где находится", "когда был основан", "сколько стоит",
        "вышел ли", "вышла ли", "обновление", "релиз", "анонс",
        "последняя версия", "что случилось", "что происходит"
    ]

    /// Возвращает DetectionResult если поиск нужен, иначе nil
    static func detect(from message: String) -> DetectionResult? {
        let lower = message.lowercased()

        // 1. Погода
        if weatherKeywords.contains(where: { lower.contains($0) }) {
            let city = extractCity(from: lower) ?? "Алматы"
            let query = "погода \(city)"
            return DetectionResult(query: query, intent: .weather(city: city))
        }

        // 2. Курсы валют
        if currencyKeywords.contains(where: { lower.contains($0) }) {
            let (from, to) = extractCurrencyPair(from: lower)
            return DetectionResult(query: "курс \(from) к \(to)", intent: .currency(from: from, to: to))
        }

        // 3. Общий поиск
        if generalSearchTriggers.contains(where: { lower.contains($0) }) {
            let query = cleanQuery(message)
            return DetectionResult(query: query, intent: .general)
        }

        return nil
    }

    // MARK: Helpers

    private static func extractCity(from text: String) -> String? {
        for city in weatherCities {
            if text.contains(city) {
                return city.capitalized
            }
        }
        // Пробуем найти "погода в X"
        if let range = text.range(of: "погода в ") {
            let after = String(text[range.upperBound...]).components(separatedBy: " ").first ?? ""
            if !after.isEmpty { return after.capitalized }
        }
        return nil
    }

    private static func extractCurrencyPair(from text: String) -> (String, String) {
        // Пары по умолчанию
        if text.contains("доллар") || text.contains("usd") {
            if text.contains("тенге") || text.contains("kzt") { return ("USD", "KZT") }
            if text.contains("рубл")  || text.contains("rub") { return ("USD", "RUB") }
            return ("USD", "KZT")
        }
        if text.contains("евро") || text.contains("eur") {
            if text.contains("тенге") { return ("EUR", "KZT") }
            return ("EUR", "KZT")
        }
        if text.contains("биткоин") || text.contains("btc") { return ("BTC", "USD") }
        return ("USD", "KZT")
    }

    private static func cleanQuery(_ message: String) -> String {
        var q = message
        let removePrefixes = ["найди ", "поищи ", "найти ", "погугли ", "поиск ", "search "]
        let lower = message.lowercased()
        for prefix in removePrefixes {
            if lower.hasPrefix(prefix) {
                q = String(message.dropFirst(prefix.count))
                break
            }
        }
        return q.trimmingCharacters(in: .whitespaces)
    }
}
