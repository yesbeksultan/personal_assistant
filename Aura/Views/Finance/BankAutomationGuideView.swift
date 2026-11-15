import SwiftUI
import UIKit

// MARK: - Bank Automation Guide View

struct BankAutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var bankParsingEnabled = BankNotificationParser.shared.isEnabled
    @State private var autoSaveEnabled = BankNotificationParser.shared.isAutoSaveEnabled
    @State private var clipboardEnabled = ClipboardMonitorService.shared.isEnabled

    @State private var selectedGuideTab: GuideTab = .applePay
    @State private var copiedAlert = false
    @State private var copiedText = ""

    enum GuideTab: String, CaseIterable, Identifiable {
        case applePay = "Apple Pay"
        case bankSMS  = "СМС банков"
        case clipboard = "Буфер обмена"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .applePay:  return "wallet.pass.fill"
            case .bankSMS:   return "message.fill"
            case .clipboard: return "doc.on.clipboard.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        settingsCard
                        segmentedPicker
                        guideContentCard
                        actionButtonsSection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Автоматизация банков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
            .alert("Скопировано в буфер ✅", isPresented: $copiedAlert) {
                Button("ОК") {}
            } message: {
                Text(copiedText)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                Image(systemName: "bolt.badge.automatic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            Text("Авто-учёт покупок")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)

            Text("Благодаря Apple Командам (Shortcuts) каждая оплата через Apple Pay или СМС от банка мгновенно заносится в ваш бюджет.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Параметры распознавания")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                .textCase(.uppercase)

            Toggle(isOn: $bankParsingEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Распознавание включено")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Анализировать суммы, валюту и магазины")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                }
            }
            .tint(Color(hex: "667eea"))
            .onChange(of: bankParsingEnabled) {
                BankNotificationParser.shared.isEnabled = bankParsingEnabled
            }

            Divider()

            Toggle(isOn: $autoSaveEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Авто-сохранение без подтверждения")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(autoSaveEnabled
                         ? "Транзакции записываются сразу в расходы"
                         : "Помещать в черновики для проверки вверху Финансов")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                }
            }
            .tint(Color(hex: "43e97b"))
            .onChange(of: autoSaveEnabled) {
                BankNotificationParser.shared.isAutoSaveEnabled = autoSaveEnabled
            }

            Divider()

            Toggle(isOn: $clipboardEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Подсказка при копировании")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Предлагать добавление, если в буфере текст чека")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                }
            }
            .tint(Color(hex: "4facfe"))
            .onChange(of: clipboardEnabled) {
                ClipboardMonitorService.shared.isEnabled = clipboardEnabled
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        HStack(spacing: 8) {
            ForEach(GuideTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedGuideTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selectedGuideTab == tab ? .white : AppColors.textPrimary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedGuideTab == tab
                            ? LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppColors.textPrimary.opacity(0.06), AppColors.textPrimary.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Guide Content Card

    @ViewBuilder
    private var guideContentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch selectedGuideTab {
            case .applePay:
                applePayGuideView
            case .bankSMS:
                bankSMSGuideView
            case .clipboard:
                clipboardGuideView
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "667eea").opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Sub-guides

    private var applePayGuideView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "4facfe"))
                Text("Настройка Apple Pay (Транзакции)")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text("Каждый раз при оплате картой через iPhone или Apple Watch срабатывает встроенная системная автоматизация iOS.")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))

            stepRow(number: "1", title: "Открой приложение «Команды»", detail: "Штатное приложение Apple на iPhone (Shortcuts).")
            stepRow(number: "2", title: "Вкладка «Автоматизация» → «+»", detail: "Нажми «Создать персональную автоматизацию».")
            stepRow(number: "3", title: "Выбери «Транзакция»", detail: "Карта: любая. Категория: любая. Включи «Выполнять немедленно».")
            stepRow(number: "4", title: "Выбери действие Friday", detail: "Найди Friday → «Оплата Apple Pay» (передай Сумму и Продавца), либо действие «Открыть URL».")
        }
    }

    private var bankSMSGuideView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "message.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "43e97b"))
                Text("Настройка СМС от банков")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text("Kaspi, Halyk, Forte, Jysan, BCC, Сбер, Tinkoff и любые другие банки.")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))

            stepRow(number: "1", title: "В «Командах» открой «Автоматизация»", detail: "Нажми «+» в правом верхнем углу.")
            stepRow(number: "2", title: "Выбери «Сообщение» (Message)", detail: "Триггер при получении нового СМС.")
            stepRow(number: "3", title: "Задай фильтр банка", detail: "Отправитель: Kaspi / 1414 / Halyk, либо Содержит: «покупка», «списано» или «₸». Режим: «Выполнять немедленно».")
            stepRow(number: "4", title: "Действие Friday", detail: "Выбери «Распознать банковское уведомление» и передай параметр «Входящее сообщение».")
        }
    }

    private var clipboardGuideView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "fa709a"))
                Text("Буфер обмена (без настроек)")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text("Самый простой способ — работает сразу без автоматизаций:")
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))

            stepRow(number: "1", title: "Скопируй текст чека или СМС", detail: "В банковском приложении зажми текст операции → «Скопировать».")
            stepRow(number: "2", title: "Открой Friday → «Финансы»", detail: "Сверху сразу появится плашка «В буфере — текст банка».")
            stepRow(number: "3", title: "Нажми «Добавить»", detail: "Friday сам заполнит сумму, категорию и магазин.")
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.18))
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "667eea"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            // Open Shortcuts App
            Button {
                if let url = URL(string: "shortcuts://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Открыть приложение «Команды»")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Copy Deep Link Template
            Button {
                copyTemplateURL()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("Скопировать ссылку для команды")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "667eea"))
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(hex: "667eea").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Test Buttons Row
            HStack(spacing: 10) {
                Button {
                    DeepLinkParserService.shared.simulateTest(source: "Apple Wallet")
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wallet.pass.fill")
                        Text("Тест Apple Pay")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "4facfe"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "4facfe").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    DeepLinkParserService.shared.simulateTest(source: "Kaspi")
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                        Text("Тест Kaspi СМС")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "43e97b"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "43e97b").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func copyTemplateURL() {
        let textToCopy: String
        switch selectedGuideTab {
        case .applePay:
            textToCopy = "friday://transaction?amount=[Сумма]&merchant=[Продавец]&bank=Apple%20Wallet"
        case .bankSMS:
            textToCopy = "friday://parse?text=[Входящее сообщение]&bank=Kaspi"
        case .clipboard:
            textToCopy = "friday://clipboard"
        }
        UIPasteboard.general.string = textToCopy
        copiedText = textToCopy
        copiedAlert = true
    }
}

