import SwiftUI
import SwiftData
import UIKit

// MARK: - Pending Drafts Banner

struct PendingDraftsBanner: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store = PendingTransactionDrafts.shared

    var body: some View {
        if !store.drafts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color(hex: "fa709a"))
                    Text("Из уведомлений банков")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button {
                        withAnimation { store.removeAll() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    }
                }

                Text("Подтверди или отклони каждую транзакцию.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))

                ForEach(store.drafts) { draft in
                    DraftRow(draft: draft) {
                        acceptDraft(draft)
                    } onReject: {
                        withAnimation { store.remove(id: draft.id) }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "fa709a").opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "fa709a").opacity(0.2), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func acceptDraft(_ draft: ParsedTransactionDraft) {
        let tx = Transaction(
            title: draft.title,
            amount: draft.amount,
            type: draft.type,
            category: draft.category,
            date: draft.date,
            note: draft.note.isEmpty ? draft.bankSource : "\(draft.bankSource) · \(draft.note)"
        )
        modelContext.insert(tx)
        withAnimation { store.remove(id: draft.id) }
    }
}

// MARK: - Clipboard Detected Banner

/// Shows a subtle hint when clipboard likely contains bank transaction text.
/// Tapping "Распознать" reads the clipboard and adds a draft.
struct ClipboardDetectedBanner: View {
    @Environment(\.modelContext) private var modelContext
    @State private var monitor = ClipboardMonitorService.shared
    @State private var store   = PendingTransactionDrafts.shared
    @State private var showSheet = false

    var body: some View {
        if monitor.hasPendingClipboardText {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "667eea").opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "667eea"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("В буфере — текст банка")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Похоже на уведомление с суммой")
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }

                Spacer()

                Button("Добавить") {
                    parseClipboardNow()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())

                Button {
                    withAnimation { monitor.clear() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
            }
            .padding(12)
            .background(Color(hex: "667eea").opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "667eea").opacity(0.15), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func parseClipboardNow() {
        guard let draft = monitor.readAndParseClipboard() else {
            // Couldn't parse — open manual sheet
            withAnimation { monitor.clear() }
            return
        }
        store.add(draft)
        withAnimation { monitor.clear() }
    }
}

// MARK: - Draft Row

struct DraftRow: View {
    let draft: ParsedTransactionDraft
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(draft.type == .income
                      ? Color(hex: "43e97b").opacity(0.2)
                      : Color(hex: "fa709a").opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: draft.type == .income ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 13))
                        .foregroundStyle(draft.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(draft.bankSource)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    Text(draft.category)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
            }

            Spacer()

            Text("\(draft.type == .income ? "+" : "-")\(draft.amount.currencyFormatted)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(draft.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))

            HStack(spacing: 6) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "43e97b"))
                }
                Button(action: onReject) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "fa709a").opacity(0.6))
                }
            }
        }
        .padding(10)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Manual Notification Parse View

struct ManualNotificationParseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pastedText  = ""
    @State private var bankName    = ""
    @State private var parsed: ParsedTransactionDraft?
    @State private var savedAlert  = false
    @State private var editedTitle = ""
    @State private var editedCategory = ""

    private var allCategories: [String] { expenseCategories + incomeCategories }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        pasteHintCard
                        bankNameField
                        textInputArea
                        if let draft = parsed {
                            resultSection(draft)
                        } else if !pastedText.isEmpty {
                            noResultCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Распознать уведомление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Вставить", systemImage: "doc.on.clipboard")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "667eea"))
                }
            }
            .alert("Транзакция добавлена ✅", isPresented: $savedAlert) {
                Button("OK") { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private var pasteHintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color(hex: "fee140"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Как это работает")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                Text("Скопируй текст СМС или уведомления от банка (долгое нажатие → Копировать), затем нажми «Вставить» или вставь вручную.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color(hex: "fee140").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bankNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Банк (необязательно)")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            HStack(spacing: 8) {
                ForEach(["Kaspi", "Halyk", "Forte", "Jysan"], id: \.self) { bank in
                    Button {
                        bankName = (bankName == bank) ? "" : bank
                        parseText()
                    } label: {
                        Text(bank)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(bankName == bank ? Color(hex: "667eea") : AppColors.textPrimary.opacity(0.6))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(bankName == bank ? Color(hex: "667eea").opacity(0.2) : AppColors.textPrimary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Текст уведомления / СМС")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                Spacer()
                if !pastedText.isEmpty {
                    Button("Очистить") {
                        pastedText = ""
                        parsed = nil
                    }
                    .font(.caption)
                    .foregroundStyle(Color(hex: "fa709a"))
                }
            }

            ZStack(alignment: .topLeading) {
                if pastedText.isEmpty {
                    Text("Например: «Kaspi.kz: Покупка 3 500 ₸ в Sulpak»")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.25))
                        .padding(14)
                }
                TextEditor(text: $pastedText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(AppColors.textPrimary)
                    .font(.system(size: 14))
                    .padding(10)
                    .frame(minHeight: 110)
                    .onChange(of: pastedText) { parseText() }
            }
            .background(AppColors.textPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Quick paste button
            Button {
                pasteFromClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                    Text("Вставить из буфера обмена")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "667eea"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "667eea").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var noResultCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "fa709a"))
            Text("Не удалось найти сумму. Убедись, что в тексте есть сумма в ₸, тг или KZT.")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
        }
        .padding(12)
        .background(Color(hex: "fa709a").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func resultSection(_ draft: ParsedTransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Результат распознавания")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))

            ParsedPreviewCard(draft: draft)

            // Editable title
            VStack(alignment: .leading, spacing: 6) {
                Text("Название (можно изменить)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                TextField("Название транзакции", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(12)
                    .background(AppColors.textPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Editable category
            VStack(alignment: .leading, spacing: 6) {
                Text("Категория")
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let cats = draft.type == .expense ? expenseCategories : incomeCategories
                        ForEach(cats, id: \.self) { cat in
                            Button { editedCategory = cat } label: {
                                Text(cat)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(editedCategory == cat
                                                     ? AppColors.textPrimary
                                                     : AppColors.textPrimary.opacity(0.5))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(editedCategory == cat
                                                ? Color(hex: "667eea").opacity(0.4)
                                                : AppColors.textPrimary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Button {
                saveDraft(draft)
            } label: {
                Label("Добавить транзакцию", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .onAppear {
            editedTitle    = draft.title
            editedCategory = draft.category
        }
        .onChange(of: draft.title)    { editedTitle    = draft.title }
        .onChange(of: draft.category) { editedCategory = draft.category }
    }

    // MARK: - Logic

    private func pasteFromClipboard() {
        let text = UIPasteboard.general.string ?? ""
        if !text.isEmpty {
            pastedText = text
            parseText()
        }
    }

    private func parseText() {
        let bank = bankName.isEmpty ? "Банк" : bankName
        parsed = BankNotificationParser.shared.tryParse(
            title: "",
            body: pastedText,
            bundleID: bank.lowercased()
        )
        if let p = parsed {
            editedTitle    = p.title
            editedCategory = p.category
        }
    }

    private func saveDraft(_ draft: ParsedTransactionDraft) {
        let tx = Transaction(
            title: editedTitle.isEmpty ? draft.title : editedTitle,
            amount: draft.amount,
            type: draft.type,
            category: editedCategory.isEmpty ? draft.category : editedCategory,
            date: draft.date,
            note: "\(draft.bankSource) · \(draft.note)"
        )
        modelContext.insert(tx)
        savedAlert = true
    }
}

// MARK: - Parsed Preview Card

struct ParsedPreviewCard: View {
    let draft: ParsedTransactionDraft

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(draft.type == .income
                      ? Color(hex: "43e97b").opacity(0.15)
                      : Color(hex: "fa709a").opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: draft.type == .income ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 18))
                        .foregroundStyle(draft.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(draft.category)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                HStack(spacing: 4) {
                    Image(systemName: "building.columns.fill")
                        .font(.caption2)
                    Text(draft.bankSource)
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.textPrimary.opacity(0.35))
            }

            Spacer()

            Text("\(draft.type == .income ? "+" : "-")\(draft.amount.currencyFormatted)")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(draft.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))
        }
        .padding(14)
        .background(AppColors.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
