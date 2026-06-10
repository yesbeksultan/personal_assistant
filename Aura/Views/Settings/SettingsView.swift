import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme: String = "dark"

    // API
    @State private var apiKey = ""
    @State private var showSavedAlert = false

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

                        // MARK: — About
                        SettingsSection(icon: "info.circle.fill", title: "О приложении", gradient: AppGradients.green) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Friday — персональный AI-ассистент")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                                Text("Версия 1.0.0 · Gemini 3.1 Flash Lite")
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
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
                loadTimes()
                refreshAuthStatus()
            }
        }
    }

    // MARK: - Helpers

    private func refreshAuthStatus() {
        NotificationService.shared.checkAuthorizationStatus { status in
            authStatus = status
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
