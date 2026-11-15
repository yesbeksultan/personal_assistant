import Foundation
import SwiftData
import SwiftUI

/// Service for handling deep links (`friday://` and `aura://`).
/// Enables iOS Shortcuts (Быстрые команды), Apple Pay automations, and external triggers
/// to parse and add bank transactions directly into Friday.
@Observable
final class DeepLinkParserService {
    static let shared = DeepLinkParserService()

    /// Banner message displayed to user upon processing deep link
    var statusMessage: String? = nil
    var showStatusBanner: Bool = false
    var isSuccessBanner: Bool = true

    private init() {}

    // MARK: - Main Router

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "friday" || scheme == "aura" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        switch host {
        case "parse", "parse-transaction":
            return handleParseText(queryItems: queryItems)

        case "transaction", "add-transaction":
            return handleStructuredTransaction(queryItems: queryItems)

        case "clipboard":
            return handleClipboard()

        case "finance", "open-finance":
            switchToFinanceTab()
            return true

        default:
            // Check path if host is empty (e.g. friday:///parse?text=...)
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            if path == "parse" {
                return handleParseText(queryItems: queryItems)
            } else if path == "transaction" {
                return handleStructuredTransaction(queryItems: queryItems)
            }
            return false
        }
    }

    // MARK: - Handlers

    /// Handles `friday://parse?text=...&bank=...`
    private func handleParseText(queryItems: [URLQueryItem]) -> Bool {
        guard let rawText = queryItems.first(where: { $0.name == "text" || $0.name == "body" || $0.name == "message" })?.value,
              !rawText.isEmpty else {
            postBanner(message: "⚠️ Текст уведомления не найден в ссылке", success: false)
            return false
        }

        // Try decoding base64 if parameter was encoded
        let decodedText: String
        if let data = Data(base64Encoded: rawText), let str = String(data: data, encoding: .utf8), !str.isEmpty {
            decodedText = str
        } else {
            decodedText = rawText
        }

        let bankHint = queryItems.first(where: { $0.name == "bank" || $0.name == "source" })?.value ?? ""

        guard let draft = BankNotificationParser.shared.tryParse(
            title: "",
            body: decodedText,
            bundleID: bankHint.lowercased()
        ) else {
            postBanner(message: "⚠️ Не удалось распознать сумму в тексте", success: false)
            switchToFinanceTab()
            return false
        }

        let saved = BankNotificationParser.shared.processDraft(draft)
        switchToFinanceTab()

        if saved {
            postBanner(message: "✅ Добавлен расход: \(draft.title) · \(draft.amount.formatted()) ₸", success: true)
        } else {
            postBanner(message: "📝 Черновик добавлен: \(draft.title) · \(draft.amount.formatted()) ₸ (подтверди в Финансах)", success: true)
        }
        return true
    }

    /// Handles `friday://transaction?amount=...&merchant=...&category=...&type=...&currency=...&bank=...`
    /// Ideal for Apple Pay / Wallet Shortcuts automation trigger.
    private func handleStructuredTransaction(queryItems: [URLQueryItem]) -> Bool {
        guard let amountStr = queryItems.first(where: { $0.name == "amount" || $0.name == "sum" })?.value,
              let amount = Double(amountStr.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")),
              amount > 0 else {
            postBanner(message: "⚠️ Сумма не указана или имеет неверный формат", success: false)
            return false
        }

        let merchant = queryItems.first(where: { $0.name == "merchant" || $0.name == "title" || $0.name == "name" })?.value ?? "Покупка"
        let bank = queryItems.first(where: { $0.name == "bank" || $0.name == "source" })?.value ?? "Apple Wallet"
        let typeStr = queryItems.first(where: { $0.name == "type" })?.value?.lowercased() ?? "expense"
        let type: TransactionType = (typeStr == "income" || typeStr == "доход") ? .income : .expense
        let currency = queryItems.first(where: { $0.name == "currency" })?.value ?? "₸"

        let categoryInput = queryItems.first(where: { $0.name == "category" })?.value ?? ""
        let category = categoryInput.isEmpty ? BankNotificationParser.shared.guessCategory(merchant: merchant, type: type) : categoryInput

        let note = "\(bank) · \(currency)"

        let draft = ParsedTransactionDraft(
            id: UUID(),
            title: merchant,
            amount: amount,
            type: type,
            category: category,
            date: Date(),
            note: note,
            bankSource: bank
        )

        let saved = BankNotificationParser.shared.processDraft(draft)
        switchToFinanceTab()

        if saved {
            postBanner(message: "✅ \(bank): \(merchant) · \(amount.formatted()) \(currency)", success: true)
        } else {
            postBanner(message: "📝 \(bank): черновик \(merchant) · \(amount.formatted()) \(currency)", success: true)
        }
        return true
    }

    /// Handles `friday://clipboard`
    private func handleClipboard() -> Bool {
        if let draft = ClipboardMonitorService.shared.readAndParseClipboard() {
            let saved = BankNotificationParser.shared.processDraft(draft)
            switchToFinanceTab()
            if saved {
                postBanner(message: "✅ Из буфера добавлен: \(draft.title) · \(draft.amount.formatted()) ₸", success: true)
            } else {
                postBanner(message: "📝 Из буфера добавлен черновик: \(draft.title)", success: true)
            }
            return true
        } else {
            postBanner(message: "ℹ️ В буфере обмена нет распознаваемых сумм", success: false)
            return false
        }
    }

    // MARK: - Navigation & Feedback

    func switchToFinanceTab() {
        DispatchQueue.main.async {
            // Ensure finance is in main tabs or set as active tab
            TabPreferences.shared.activeTabID = AppTab.finance.rawValue
        }
    }

    func postBanner(message: String, success: Bool) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.isSuccessBanner = success
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self.showStatusBanner = true
            }

            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.statusMessage == message {
                    withAnimation {
                        self.showStatusBanner = false
                    }
                }
            }
        }
    }

    // MARK: - Testing Helper

    /// Triggers a test transaction to verify deep links and processing
    func simulateTest(source: String) {
        if source == "Apple Wallet" {
            let url = URL(string: "friday://transaction?amount=1850&merchant=Starbucks%20Coffee&bank=Apple%20Wallet&currency=%E2%82%B8")!
            _ = handleURL(url)
        } else {
            let sampleText = "Kaspi.kz: Покупка 4 250 ₸ в Magnum Express. Доступно: 125 000 ₸."
            let encoded = sampleText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let url = URL(string: "friday://parse?text=\(encoded)&bank=Kaspi")!
            _ = handleURL(url)
        }
    }
}

