import AppIntents
import Foundation
import SwiftData

// MARK: - Parse Bank Text Intent (For SMS / Push Automations)

struct ParseBankNotificationIntent: AppIntent {
    static var title: LocalizedStringResource = "Распознать банковское уведомление"
    static var description = IntentDescription("Анализирует текст СМС или пуша (Kaspi, Halyk, Apple Wallet) и записывает расход или доход в Friday")

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Текст СМС / уведомления",
        description: "Текст сообщения от банка (например, «Kaspi.kz: Покупка 3 500 ₸ в Sulpak»)",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    @Parameter(
        title: "Банк (необязательно)",
        description: "Название банка для более точного определения",
        default: ""
    )
    var bankHint: String

    static var parameterSummary: some ParameterSummary {
        Summary("Распознать банковский текст \(\.$text)") {
            \.$bankHint
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(dialog: "Текст сообщения пуст")
        }

        let context = ModelContext(AppStorageContainer.shared)
        let (draftOpt, autoSaved) = BankNotificationParser.shared.processText(text, bankHint: bankHint, context: context)

        guard let draft = draftOpt else {
            return .result(dialog: "Не удалось распознать сумму в тексте. Убедитесь, что текст содержит сумму (₸, KZT, $, €).")
        }

        if autoSaved {
            return .result(dialog: "✅ Friday: добавлен \(draft.type == .income ? "доход" : "расход") \(draft.amount.formatted()) ₸: \(draft.title)")
        } else {
            return .result(dialog: "📝 Friday: добавлен черновик: \(draft.title) на \(draft.amount.formatted()) ₸. Подтвердите в приложении.")
        }
    }
}

// MARK: - Add Wallet Transaction Intent (For Apple Pay Shortcuts Automations)

struct AddWalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Оплата Apple Pay / Wallet"
    static var description = IntentDescription("Записывает транзакцию из Apple Wallet / Apple Pay напрямую в Friday")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Сумма", description: "Сумма транзакции")
    var amount: Double

    @Parameter(title: "Магазин / Продавец", default: "Apple Pay")
    var merchant: String

    @Parameter(title: "Категория", default: "")
    var category: String

    @Parameter(title: "Валюта", default: "₸")
    var currency: String

    static var parameterSummary: some ParameterSummary {
        Summary("Добавить покупку Apple Pay: \(\.$amount) \(\.$currency) в \(\.$merchant)") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Сумма должна быть больше нуля")
        }

        let cleanMerchant = merchant.isEmpty ? "Apple Pay" : merchant
        let cat = category.isEmpty ? BankNotificationParser.shared.guessCategory(merchant: cleanMerchant, type: .expense) : category
        let note = "Apple Wallet · \(currency)"

        let draft = ParsedTransactionDraft(
            id: UUID(),
            title: cleanMerchant,
            amount: amount,
            type: .expense,
            category: cat,
            date: Date(),
            note: note,
            bankSource: "Apple Wallet"
        )

        let context = ModelContext(AppStorageContainer.shared)
        let saved = BankNotificationParser.shared.processDraft(draft, context: context)

        if saved {
            return .result(dialog: "✅ Apple Pay: записан расход \(amount.formatted()) \(currency) в \(cleanMerchant)")
        } else {
            return .result(dialog: "📝 Apple Pay: добавлен черновик \(cleanMerchant) на \(amount.formatted()) \(currency)")
        }
    }
}

// MARK: - App Shortcuts Provider

struct FridayAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ParseBankNotificationIntent(),
            phrases: [
                "Распознать чек в \(.applicationName)",
                "Записать банковское уведомление в \(.applicationName)",
                "Распознать СМС банка в \(.applicationName)"
            ],
            shortTitle: "Распознать банк",
            systemImageName: "creditcard.and.123"
        )

        AppShortcut(
            intent: AddWalletTransactionIntent(),
            phrases: [
                "Записать Apple Pay в \(.applicationName)",
                "Добавить оплату картой в \(.applicationName)"
            ],
            shortTitle: "Оплата Apple Pay",
            systemImageName: "wallet.pass.fill"
        )
    }
}

