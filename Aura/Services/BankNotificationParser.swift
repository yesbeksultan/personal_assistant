import Foundation
import UserNotifications
import SwiftData

// MARK: - Parsed Transaction Draft

struct ParsedTransactionDraft: Identifiable {
    let id: UUID
    let title: String
    let amount: Double
    let type: TransactionType
    let category: String
    let date: Date
    let note: String         // raw notification text
    let bankSource: String   // "Kaspi", "Halyk", etc.
}

// MARK: - Bank Notification Parser

/// Parses push-notifications from Kazakh banks and produces transaction drafts.
/// Integrates with NotificationService to intercept incoming notifications.
final class BankNotificationParser {

    static let shared = BankNotificationParser()

    // Published via NotificationCenter so FinanceView can observe
    static let didParseDraftNotification = Notification.Name("BankNotificationParser.didParseDraft")

    // UserDefaults key
    static let enabledKey = "bankNotifParsing_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    private init() {}

    // MARK: - Entry point called from NotificationService delegate

    /// Returns a draft if the notification text looks like a bank transaction.
    func tryParse(title: String, body: String, bundleID: String) -> ParsedTransactionDraft? {
        guard isEnabled else { return nil }

        let combined = "\(title) \(body)"

        // 1. Detect bank
        let bank = detectBank(bundleID: bundleID, text: combined)

        // 2. Extract amount
        guard let (amount, type) = extractAmountAndType(from: combined) else { return nil }

        // 3. Extract merchant / description
        let merchant = extractMerchant(from: combined, bank: bank)

        // 4. Map to category
        let category = guessCategory(merchant: merchant, type: type)

        return ParsedTransactionDraft(
            id: UUID(),
            title: merchant.isEmpty ? (type == .expense ? "Расход" : "Доход") : merchant,
            amount: amount,
            type: type,
            category: category,
            date: Date(),
            note: body,
            bankSource: bank
        )
    }

    // MARK: - Bank detection

    private func detectBank(bundleID: String, text: String) -> String {
        let bundleLower = bundleID.lowercased()
        let textLower   = text.lowercased()

        if bundleLower.contains("kaspi")   || textLower.contains("kaspi")    { return "Kaspi" }
        if bundleLower.contains("halyk")   || textLower.contains("halyk")    { return "Halyk" }
        if bundleLower.contains("forte")   || textLower.contains("forte")    { return "Forte" }
        if bundleLower.contains("jysan")   || textLower.contains("jysan")    { return "Jysan" }
        if bundleLower.contains("bereke")  || textLower.contains("bereke")   { return "Bereke" }
        if bundleLower.contains("bcc")     || textLower.contains("bcc")      { return "BCC" }
        if bundleLower.contains("atf")     || textLower.contains("atfbank")  { return "ATF" }
        if bundleLower.contains("sber")    || textLower.contains("сбербанк") { return "Sber" }
        if bundleLower.contains("tinkoff") || textLower.contains("тинькофф") { return "Tinkoff" }
        return "Банк"
    }

    // MARK: - Amount & type extraction

    private func extractAmountAndType(from text: String) -> (Double, TransactionType)? {
        // Patterns to match amounts like:
        //   "5 000 ₸", "5000 тг", "500.00 KZT", "-1 200,50 ₸", "+10000 тг"
        //   "списано 3 500 тенге", "зачислено 50 000 ₸"
        //   "покупка на сумму 2 000 ₸", "оплата 1500₸"

        let patterns: [(String, TransactionType?)] = [
            // explicit debit keywords → expense
            (#"(?:списан[оа]?|покупка|оплат[аы]|расход|withdrawal|debit|spent)[^\d]*([+-]?[\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, .expense),
            // explicit credit keywords → income
            (#"(?:зачислен[оа]?|пополнен|получен|приход|deposit|credit|income)[^\d]*([+-]?[\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, .income),
            // sign-prefixed: -5000₸ or +5000₸
            (#"([+-][\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, nil),
            // bare amount before currency
            (#"([\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, nil),
        ]

        let textLower = text.lowercased()

        for (pattern, forcedType) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: textLower, range: NSRange(textLower.startIndex..., in: textLower)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: textLower) else { continue }

            let raw = String(textLower[range])
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")

            let isNegative = raw.hasPrefix("-")
            let digits = raw.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
            guard let value = Double(digits), value > 0 else { continue }

            let txType: TransactionType
            if let forced = forcedType {
                txType = forced
            } else if isNegative {
                txType = .expense
            } else if raw.hasPrefix("+") {
                txType = .income
            } else {
                // No sign — default to expense (most bank notifications are about spending)
                txType = .expense
            }

            return (value, txType)
        }
        return nil
    }

    // MARK: - Merchant extraction

    private func extractMerchant(from text: String, bank: String) -> String {
        // Try to find merchant name after keywords like "в ", "у ", "магазин", "merchants:"
        let patterns = [
            #"(?:в магазине|в|у|merchant:?|store:?)\s+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'-]{2,30})"#,
            #"(?:покупка|оплата)\s+(?:в\s+)?([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'-]{2,30})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }

        // Fallback: take the first capitalized word that isn't the bank name
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { w in
                w.count > 2 &&
                w.first?.isUppercase == true &&
                !w.lowercased().contains(bank.lowercased()) &&
                !["Оплата","Покупка","Списано","Зачислено","Перевод"].contains(w)
            }
        return words.first ?? ""
    }

    // MARK: - Category guessing

    private func guessCategory(merchant: String, type: TransactionType) -> String {
        if type == .income { return "💵 Другое" }

        let m = merchant.lowercased()

        let map: [(keywords: [String], category: String)] = [
            (["glovo","yandex.eda","wolt","choco","burger","kfc","mcdonalds","кафе","ресторан","coffee","кофе","пицца","суши"], "🍔 Еда"),
            (["яндекс.такси","yandex.taxi","uber","bolt","indriver","такси","bus","автобус","метро","бензин","shell","bp "], "🚗 Транспорт"),
            (["аренда","квартира","жильё","коммунал","utilities","electr","вода","газ","свет"], "🏠 Жильё"),
            (["netflix","spotify","apple","steam","playstation","кино","concert","театр","развлечен"], "🎮 Развлечения"),
            (["одежда","zara","h&m","adidas","nike","lamoda","обувь"], "👕 Одежда"),
            (["аптека","pharmacy","doctor","медицина","клиника","здоровье"], "💊 Здоровье"),
            (["kaspi red","рассрочка","кредит","loan"], "📦 Другое"),
            (["билайн","kcell","activ","tele2","мобильн","связь"], "📱 Связь"),
            (["книга","курс","учеба","образован","udemy","coursera"], "📚 Образование"),
            (["свет","газ","интернет","telecom","вода","отопление","коммунал"], "💡 Коммуналка"),
        ]

        for (keywords, category) in map {
            if keywords.contains(where: { m.contains($0) }) {
                return category
            }
        }
        return "📦 Другое"
    }
}

// MARK: - Pending Drafts Store

/// Thread-safe store for drafts that need user confirmation before saving.
@Observable
final class PendingTransactionDrafts {
    static let shared = PendingTransactionDrafts()

    var drafts: [ParsedTransactionDraft] = []

    private init() {}

    func add(_ draft: ParsedTransactionDraft) {
        DispatchQueue.main.async {
            // Deduplicate by amount+date proximity (within 30 s)
            let isDuplicate = self.drafts.contains {
                $0.amount == draft.amount &&
                abs($0.date.timeIntervalSince(draft.date)) < 30
            }
            if !isDuplicate {
                self.drafts.append(draft)
            }
        }
    }

    func remove(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    func removeAll() {
        drafts.removeAll()
    }
}
