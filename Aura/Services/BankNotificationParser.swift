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

        // 2. Extract amount (+ currency for Apple Wallet)
        guard let (amount, type, currency) = extractAmountTypeAndCurrency(from: combined) else { return nil }

        // 3. Extract merchant / description
        let merchant = extractMerchant(from: combined, bank: bank)

        // 4. Map to category
        let category = guessCategory(merchant: merchant, type: type)

        // 5. Build note — append currency for non-KZT Apple Wallet payments
        let currencyNote: String
        if bank == "Apple Wallet" && currency != "KZT" && currency != "₸" {
            currencyNote = "\(body) [валюта: \(currency)]"
        } else {
            currencyNote = body
        }

        return ParsedTransactionDraft(
            id: UUID(),
            title: merchant.isEmpty ? (type == .expense ? "Расход" : "Доход") : merchant,
            amount: amount,
            type: type,
            category: category,
            date: Date(),
            note: currencyNote,
            bankSource: bank
        )
    }

    // MARK: - Bank detection

    private func detectBank(bundleID: String, text: String) -> String {
        let bundleLower = bundleID.lowercased()
        let textLower   = text.lowercased()

        // Apple Wallet / Apple Pay — проверяем первым (bundle com.apple.Passbook)
        if bundleLower.contains("passbook") || bundleLower.contains("apple.wallet") ||
           textLower.contains("apple pay")  || textLower.contains("apple card") ||
           textLower.contains("apple wallet") { return "Apple Wallet" }

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

    // MARK: - Amount, type & currency extraction

    /// Extracts amount, transaction type, and currency symbol from notification text.
    private func extractAmountTypeAndCurrency(from text: String) -> (Double, TransactionType, String)? {
        let textLower = text.lowercased()

        // --- Apple Wallet / Apple Pay patterns (foreign currencies) ---
        // "You paid $12.99 at Starbucks", "Payment of €5.00", "charged $29.99"
        let applePatterns: [(pattern: String, currency: String)] = [
            (#"(?:you paid|payment of|charged|purchase of|paid)\s*\$\s*([\d\.,]+)"#, "USD"),
            (#"(?:you paid|payment of|charged|purchase of|paid)\s*€\s*([\d\.,]+)"#, "EUR"),
            (#"(?:you paid|payment of|charged|purchase of|paid)\s*£\s*([\d\.,]+)"#, "GBP"),
            (#"\$\s*([\d\.,]+)"#,  "USD"),
            (#"€\s*([\d\.,]+)"#,   "EUR"),
            (#"£\s*([\d\.,]+)"#,   "GBP"),
            (#"usd\s+([\d\.,]+)"#, "USD"),
            (#"eur\s+([\d\.,]+)"#, "EUR"),
            (#"gbp\s+([\d\.,]+)"#, "GBP"),
        ]

        for (pattern, currency) in applePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: textLower, range: NSRange(textLower.startIndex..., in: textLower)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: textLower) {
                let raw = String(textLower[range])
                    .replacingOccurrences(of: ",", with: ".")
                if let value = Double(raw), value > 0 {
                    return (value, .expense, currency)
                }
            }
        }

        // --- KZT / Tenge patterns ---
        let kztPatterns: [(String, TransactionType?)] = [
            // explicit debit keywords → expense
            (#"(?:списан[оа]?|покупка|оплат[аы]|расход|withdrawal|debit|spent)[^\d]*([+-]?[\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, .expense),
            // explicit credit keywords → income
            (#"(?:зачислен[оа]?|пополнен|получен|приход|deposit|credit|income)[^\d]*([+-]?[\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, .income),
            // sign-prefixed: -5000₸ or +5000₸
            (#"([+-][\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, nil),
            // bare amount before currency
            (#"([\d\s\.,]+)\s*(?:₸|тг|тенге|kzt)"#, nil),
        ]

        for (pattern, forcedType) in kztPatterns {
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
                txType = .expense
            }
            return (value, txType, "KZT")
        }
        return nil
    }

    // Legacy wrapper for backward compat (clipboard parser etc.)
    private func extractAmountAndType(from text: String) -> (Double, TransactionType)? {
        guard let (amount, type, _) = extractAmountTypeAndCurrency(from: text) else { return nil }
        return (amount, type)
    }

    // MARK: - Merchant extraction

    private func extractMerchant(from text: String, bank: String) -> String {
        let patterns = [
            // Apple Pay: "You paid $12.99 at Starbucks", "Payment at Amazon"
            #"(?:paid|payment|purchase)\s+(?:at|to|for)\s+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'.,-]{2,40})"#,
            // Apple Wallet generic: "at Merchant Name"
            #"\bat\s+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'.,-]{2,35})"#,
            // Kaspi / Halyk style
            #"(?:в магазине|в|у|merchant:?|store:?)\s+([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'-]{2,30})"#,
            #"(?:покупка|оплата)\s+(?:в\s+)?([A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9\s&'-]{2,30})"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .punctuationCharacters)
                if !name.isEmpty && name.count > 1 { return name }
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
            (["glovo","yandex.eda","wolt","choco","burger","kfc","mcdonalds","кафе","ресторан","coffee","кофе","пицца","суши","starbucks","dunkin"], "🍔 Еда"),
            (["яндекс.такси","yandex.taxi","uber","bolt","indriver","такси","bus","автобус","метро","бензин","shell","bp "], "🚗 Транспорт"),
            (["аренда","квартира","жильё","коммунал","utilities","electr","вода","газ","свет"], "🏠 Жильё"),
            // Apple subscriptions / App Store / digital services
            (["app store","apple.com/bill","apple subscription","itunes","apple one","icloud","icloud+"], "🍎 Apple"),
            (["netflix","spotify","steam","playstation","youtube premium","кино","concert","театр","развлечен","hulu","disney"], "🎮 Развлечения"),
            (["одежда","zara","h&m","adidas","nike","lamoda","обувь","uniqlo","shein"], "👕 Одежда"),
            (["аптека","pharmacy","doctor","медицина","клиника","здоровье"], "💊 Здоровье"),
            (["kaspi red","рассрочка","кредит","loan"], "📦 Другое"),
            (["билайн","kcell","activ","tele2","мобильн","связь"], "📱 Связь"),
            (["книга","курс","учеба","образован","udemy","coursera","skillbox"], "📚 Образование"),
            (["свет","газ","интернет","telecom","вода","отопление","коммунал"], "💡 Коммуналка"),
            (["amazon","aliexpress","wildberries","ozon","ebay","etsy"], "🛒 Шоппинг"),
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
