import SwiftUI
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme: String = "dark"

    // API
    @State private var apiKey = ""
    @State private var showSavedAlert = false
    @State private var serperApiKey = ""
    @State private var showSerperSavedAlert = false

    // Bank notification parsing
    @State private var bankParsingEnabled = BankNotificationParser.shared.isEnabled
    @State private var autoSaveEnabled = BankNotificationParser.shared.isAutoSaveEnabled
    @State private var showAutomationGuide = false

    // Finance lock
    @AppStorage("financeLockEnabled") private var financeLockEnabled: Bool = true
    @State private var biometryAvailable: Bool = false
    @State private var biometryType: String = "Face ID"

    // Notification permission
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    // Evening summary
    @AppStorage(NotificationDefaults.eveningEnabled) private var eveningEnabled = true
    @State private var eveningTime = defaultDate(hour: 20)

    // Add task reminder
    @AppStorage(NotificationDefaults.addTaskEnabled) private var addTaskEnabled = true
    @State private var addTaskTime = defaultDate(hour: 9)

    // Finance check
    @AppStorage(NotificationDefaults.financeEnabled) private var financeEnabled = true
    @State private var financeTime = defaultDate(hour: 14)

    // Evening chat
    @AppStorage(NotificationDefaults.chatEnabled) private var chatEnabled = true
    @State private var chatTime = defaultDate(hour: 21)

    private let geminiService = GeminiService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: — API Key
                        SettingsSection(icon: "key.fill", title: "Gemini API", gradient: AppGradients.purple) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Получи ключ на aistudio.google.com")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                                SecureField("API ключ", text: $apiKey)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(14)
                                    .background(AppColors.textPrimary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(geminiService.hasApiKey ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                                        .frame(width: 8, height: 8)
                                    Text(geminiService.hasApiKey ? "Ключ настроен" : "Ключ не настроен")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                }

                                Button {
                                    geminiService.setApiKey(apiKey)
                                    showSavedAlert = true
                                } label: {
                                    Text("Сохранить ключ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .background(
                                            LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(apiKey.isEmpty)
                            }
                        }

                        // MARK: — Serper API (Web Search)
                        SettingsSection(icon: "magnifyingglass", title: "Poиск в интернете", gradient: [Color(hex: "11998e"), Color(hex: "38ef7d")]) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Serper.dev — Google-поиск для AI. Бесплатно 2500 запросов.\nПолучи ключ: serper.dev")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                                SecureField("Serper API ключ", text: $serperApiKey)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(14)
                                    .background(AppColors.textPrimary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(WebSearchService.shared.hasSerperKey ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                                        .frame(width: 8, height: 8)
                                    Text(WebSearchService.shared.hasSerperKey
                                         ? "Ключ настроен — поиск активен 🌐"
                                         : "Без ключа: Wikipedia + погода + валюты")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                }

                                Button {
                                    WebSearchService.shared.serperApiKey = serperApiKey
                                    showSerperSavedAlert = true
                                } label: {
                                    Text("Сохранить ключ")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .background(
                                            LinearGradient(colors: [Color(hex: "11998e"), Color(hex: "38ef7d")], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(serperApiKey.isEmpty)
                            }
                        }
                        .alert("Ключ Serper сохранён ✅", isPresented: $showSerperSavedAlert) { Button("OK") {} }

                        // MARK: — Notifications
                        SettingsSection(icon: "bell.fill", title: "Уведомления", gradient: AppGradients.orange) {
                            VStack(spacing: 0) {
                                // Permission banner
                                if authStatus == .denied {
                                    HStack(spacing: 10) {
                                        Image(systemName: "bell.slash.fill")
                                            .foregroundStyle(Color(hex: "fa709a"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Уведомления отключены")
                                                .font(.caption).fontWeight(.semibold)
                                                .foregroundStyle(AppColors.textPrimary)
                                            Text("Включи в Настройки → Уведомления → Friday")
                                                .font(.caption2)
                                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                        }
                                        Spacer()
                                        Button("Открыть") {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(Color(hex: "667eea"))
                                    }
                                    .padding(12)
                                    .background(Color(hex: "fa709a").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.bottom, 12)
                                } else if authStatus == .notDetermined {
                                    Button {
                                        NotificationService.shared.requestPermission { _ in
                                            refreshAuthStatus()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "bell.badge")
                                            Text("Разрешить уведомления")
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(LinearGradient(colors: AppGradients.orange, startPoint: .leading, endPoint: .trailing))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .padding(.bottom, 12)
                                }

                                // Rows
                                NotifRow(
                                    icon: "moon.stars.fill",
                                    iconColor: Color(hex: "764ba2"),
                                    title: "Вечерняя сводка",
                                    subtitle: "Итоги дня: задачи и финансы",
                                    enabled: $eveningEnabled,
                                    time: $eveningTime
                                )
                                Divider().padding(.vertical, 10)
                                NotifRow(
                                    icon: "checklist",
                                    iconColor: Color(hex: "4facfe"),
                                    title: "Добавь задачи",
                                    subtitle: "Напоминание записать дела",
                                    enabled: $addTaskEnabled,
                                    time: $addTaskTime
                                )
                                Divider().padding(.vertical, 10)
                                NotifRow(
                                    icon: "creditcard.fill",
                                    iconColor: Color(hex: "43e97b"),
                                    title: "Проверь финансы",
                                    subtitle: "Внеси расходы за сегодня",
                                    enabled: $financeEnabled,
                                    time: $financeTime
                                )
                                Divider().padding(.vertical, 10)
                                NotifRow(
                                    icon: "sparkles",
                                    iconColor: Color(hex: "667eea"),
                                    title: "Поговори с Friday",
                                    subtitle: "Вечерний чат — советы и поддержка",
                                    enabled: $chatEnabled,
                                    time: $chatTime
                                )

                                Button {
                                    saveNotifications()
                                    showSavedAlert = true
                                } label: {
                                    Text("Применить")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(14)
                                        .background(
                                            LinearGradient(colors: AppGradients.orange, startPoint: .leading, endPoint: .trailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .padding(.top, 12)
                            }
                        }

                        // MARK: — iCloud Sync
                        SettingsSection(icon: "icloud.fill", title: "iCloud Синхронизация", gradient: [Color(hex: "4facfe"), Color(hex: "00f2fe")]) {
                            iCloudSyncView()
                        }

                        // MARK: — Theme
                        SettingsSection(icon: "paintpalette.fill", title: "Внешний вид", gradient: AppGradients.blue) {
                            Picker("Тема", selection: $appTheme) {
                                Text("🌙 Тёмная").tag("dark")
                                Text("☀️ Светлая").tag("light")
                            }
                            .pickerStyle(.segmented)
                        }

                        // MARK: — Bank Notification Parsing
                        SettingsSection(
                            icon: "bell.badge.fill",
                            title: "Авто-распознавание банков",
                            gradient: [Color(hex: "fa709a"), Color(hex: "fee140")]
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $bankParsingEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Распознавать уведомления банков")
                                            .font(.subheadline).fontWeight(.medium)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text("Kaspi, Halyk, Forte, Jysan и другие")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                                    }
                                }
                                .tint(Color(hex: "667eea"))
                                .onChange(of: bankParsingEnabled) {
                                    BankNotificationParser.shared.isEnabled = bankParsingEnabled
                                }

                                // Apple Wallet info row
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(hex: "1c1c1e"))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "wallet.pass.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Apple Wallet & СМС банков")
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text("Распознавание Apple Pay, Kaspi, Halyk и др.")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "43e97b"))
                                        .font(.system(size: 16))
                                }
                                .padding(10)
                                .background(Color(hex: "43e97b").opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // Auto-Save toggle
                                Toggle(isOn: $autoSaveEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Авто-сохранение в расходы")
                                            .font(.subheadline).fontWeight(.medium)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text("Записывать сразу без ожидания подтверждения")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                                    }
                                }
                                .tint(Color(hex: "43e97b"))
                                .onChange(of: autoSaveEnabled) {
                                    BankNotificationParser.shared.isAutoSaveEnabled = autoSaveEnabled
                                }

                                // Open Automation Guide Button
                                Button {
                                    showAutomationGuide = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bolt.badge.automatic.fill")
                                            .font(.system(size: 14))
                                        Text("Инструкция по настройке автоматизации")
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .opacity(0.6)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Text("При включённой опции уведомления от банков и Apple Wallet анализируются и предлагаются для добавления в расходы/доходы. Данные не покидают устройство.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                                HStack(spacing: 6) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "43e97b"))
                                    Text("Полностью офлайн · Без отправки данных")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                }
                            }
                        }

                        // MARK: — Finance Lock
                        SettingsSection(
                            icon: "lock.shield.fill",
                            title: "Блокировка финансов",
                            gradient: [Color(hex: "667eea"), Color(hex: "764ba2")]
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                // Main toggle
                                Toggle(isOn: $financeLockEnabled) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(financeLockEnabled
                                                      ? Color(hex: "667eea").opacity(0.15)
                                                      : AppColors.textPrimary.opacity(0.08))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: financeLockEnabled ? "lock.fill" : "lock.open.fill")
                                                .font(.system(size: 15))
                                                .foregroundStyle(financeLockEnabled
                                                                 ? Color(hex: "667eea")
                                                                 : AppColors.textPrimary.opacity(0.4))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(financeLockEnabled ? "Защита включена" : "Защита выключена")
                                                .font(.subheadline).fontWeight(.medium)
                                                .foregroundStyle(AppColors.textPrimary)
                                            Text(financeLockEnabled
                                                 ? "Суммы скрыты до \(biometryType) / пароля"
                                                 : "Суммы видны без разблокировки")
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                                        }
                                    }
                                }
                                .tint(Color(hex: "667eea"))

                                if financeLockEnabled {
                                    // Biometry status pill
                                    HStack(spacing: 8) {
                                        Image(systemName: biometryAvailable
                                              ? (biometryType == "Face ID" ? "faceid" : "touchid")
                                              : "lock.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(biometryAvailable
                                                             ? Color(hex: "43e97b")
                                                             : Color(hex: "fee140"))
                                        Text(biometryAvailable
                                             ? "\(biometryType) — будет использован при разблокировке"
                                             : "Биометрия недоступна — используется пароль устройства")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                                    }
                                    .padding(10)
                                    .background(biometryAvailable
                                                ? Color(hex: "43e97b").opacity(0.07)
                                                : Color(hex: "fee140").opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                    // Test unlock button
                                    Button {
                                        testFinanceLock()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: biometryAvailable
                                                  ? (biometryType == "Face ID" ? "faceid" : "touchid")
                                                  : "lock.fill")
                                            Text("Проверить разблокировку")
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: "667eea"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Color(hex: "667eea").opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }

                                Text("Когда защита включена, баланс и суммы транзакций скрыты — открыть можно через \(biometryType) или пароль устройства.")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                            }
                        }

                        // MARK: — About
                        SettingsSection(icon: "info.circle.fill", title: "О приложении", gradient: AppGradients.green) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Friday — персональный AI-ассистент")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                                Text("Версия 1.0.0 · Gemini 2.5 Flash")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.35))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
            .alert("Сохранено ✅", isPresented: $showSavedAlert) {
                Button("ОК") {}
            } message: {
                Text("Разблокировка работает корректно!")
            }
            .sheet(isPresented: $showAutomationGuide) {
                BankAutomationGuideView()
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
                loadTimes()
                refreshAuthStatus()
                detectBiometry()
            }
        }
    }

    // MARK: - Helpers

    private func refreshAuthStatus() {
        NotificationService.shared.checkAuthorizationStatus { status in
            authStatus = status
        }
    }

    private func detectBiometry() {
        let context = LAContext()
        var error: NSError?
        biometryAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID:    biometryType = "Face ID"
        case .touchID:   biometryType = "Touch ID"
        case .opticID:   biometryType = "Optic ID"
        default:         biometryType = "пароль"
        }
    }

    private func testFinanceLock() {
        let context = LAContext()
        var error: NSError?
        let reason = "Проверка разблокировки раздела «Финансы»"
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    showSavedAlert = success
                }
            }
        }
    }

    private func loadTimes() {
        let ud = UserDefaults.standard
        eveningTime  = makeDate(hour: ud.integer(forKey: NotificationDefaults.eveningHour).nonZero(or: 20),
                                minute: ud.integer(forKey: NotificationDefaults.eveningMinute))
        addTaskTime  = makeDate(hour: ud.integer(forKey: NotificationDefaults.addTaskHour).nonZero(or: 9),
                                minute: ud.integer(forKey: NotificationDefaults.addTaskMinute))
        financeTime  = makeDate(hour: ud.integer(forKey: NotificationDefaults.financeHour).nonZero(or: 14),
                                minute: ud.integer(forKey: NotificationDefaults.financeMinute))
        chatTime     = makeDate(hour: ud.integer(forKey: NotificationDefaults.chatHour).nonZero(or: 21),
                                minute: ud.integer(forKey: NotificationDefaults.chatMinute))
    }

    private func saveNotifications() {
        let ud = UserDefaults.standard
        let cal = Calendar.current

        func save(date: Date, hourKey: String, minuteKey: String) {
            ud.set(cal.component(.hour,   from: date), forKey: hourKey)
            ud.set(cal.component(.minute, from: date), forKey: minuteKey)
        }

        save(date: eveningTime,  hourKey: NotificationDefaults.eveningHour,  minuteKey: NotificationDefaults.eveningMinute)
        save(date: addTaskTime,  hourKey: NotificationDefaults.addTaskHour,  minuteKey: NotificationDefaults.addTaskMinute)
        save(date: financeTime,  hourKey: NotificationDefaults.financeHour,  minuteKey: NotificationDefaults.financeMinute)
        save(date: chatTime,     hourKey: NotificationDefaults.chatHour,     minuteKey: NotificationDefaults.chatMinute)

        NotificationService.shared.rescheduleAll()
    }
}

// MARK: - Helpers

private func defaultDate(hour: Int) -> Date {
    makeDate(hour: hour, minute: 0)
}

private func makeDate(hour: Int, minute: Int) -> Date {
    var c = DateComponents()
    c.hour = hour; c.minute = minute
    return Calendar.current.date(from: c) ?? Date()
}

private extension Int {
    func nonZero(or fallback: Int) -> Int { self == 0 ? fallback : self }
}

// MARK: - SettingsSection

private struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let gradient: [Color]
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            content()
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - NotifRow

private struct NotifRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var enabled: Bool
    @Binding var time: Date

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
            }

            Spacer()

            if enabled {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(iconColor)
            }

            Toggle("", isOn: $enabled)
                .labelsHidden()
                .tint(iconColor)
        }
    }
}
