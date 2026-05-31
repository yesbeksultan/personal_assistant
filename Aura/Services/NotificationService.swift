import Foundation
import UserNotifications

/// Service for managing local notifications
class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Identifiers
    private enum ID {
        static let evening   = "notif_evening_summary"
        static let addTask   = "notif_add_task"
        static let finance   = "notif_check_finance"
        static let chat      = "notif_evening_chat"
    }

    // MARK: - Permission

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Schedule all active notifications

    func rescheduleAll() {
        let d = NotificationDefaults.self
        scheduleIfEnabled(
            enabled: UserDefaults.standard.bool(forKey: d.eveningEnabled),
            id: ID.evening,
            title: "🌙 Вечерняя сводка — Friday",
            body: "Пора подвести итоги дня! Посмотри задачи и финансы.",
            hour: UserDefaults.standard.integer(forKey: d.eveningHour).nonZero(or: 20),
            minute: UserDefaults.standard.integer(forKey: d.eveningMinute)
        )
        scheduleIfEnabled(
            enabled: UserDefaults.standard.bool(forKey: d.addTaskEnabled),
            id: ID.addTask,
            title: "📋 Не забудь записать задачи",
            body: "Добавь новые дела, чтобы ничего не упустить сегодня!",
            hour: UserDefaults.standard.integer(forKey: d.addTaskHour).nonZero(or: 9),
            minute: UserDefaults.standard.integer(forKey: d.addTaskMinute)
        )
        scheduleIfEnabled(
            enabled: UserDefaults.standard.bool(forKey: d.financeEnabled),
            id: ID.finance,
            title: "💰 Проверь финансы",
            body: "Добавь расходы и доходы за сегодня, чтобы держать бюджет под контролем.",
            hour: UserDefaults.standard.integer(forKey: d.financeHour).nonZero(or: 14),
            minute: UserDefaults.standard.integer(forKey: d.financeMinute)
        )
        scheduleIfEnabled(
            enabled: UserDefaults.standard.bool(forKey: d.chatEnabled),
            id: ID.chat,
            title: "✨ Поговори с Friday",
            body: "Хочешь обсудить прошедший день или получить совет? Я здесь!",
            hour: UserDefaults.standard.integer(forKey: d.chatHour).nonZero(or: 21),
            minute: UserDefaults.standard.integer(forKey: d.chatMinute)
        )
    }

    // MARK: - Task reminders

    func scheduleTaskReminder(for task: TaskItem) {
        guard let dueDate = task.dueDate else { return }
        let reminderDate = dueDate.addingTimeInterval(-3600)
        let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: reminderDate)

        let content = UNMutableNotificationContent()
        content.title = "⏰ Дедлайн задачи"
        content.body = task.title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "task_\(task.id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelTaskReminder(for task: TaskItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["task_\(task.id.uuidString)"])
    }

    // MARK: - Private helpers

    private func scheduleIfEnabled(enabled: Bool, id: String, title: String, body: String, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        )
        center.add(request)
    }
}

// MARK: - UserDefaults keys

enum NotificationDefaults {
    static let eveningEnabled  = "notif_evening_enabled"
    static let eveningHour     = "notif_evening_hour"
    static let eveningMinute   = "notif_evening_minute"

    static let addTaskEnabled  = "notif_addtask_enabled"
    static let addTaskHour     = "notif_addtask_hour"
    static let addTaskMinute   = "notif_addtask_minute"

    static let financeEnabled  = "notif_finance_enabled"
    static let financeHour     = "notif_finance_hour"
    static let financeMinute   = "notif_finance_minute"

    static let chatEnabled     = "notif_chat_enabled"
    static let chatHour        = "notif_chat_hour"
    static let chatMinute      = "notif_chat_minute"

    /// Записывает дефолты при первом запуске
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            eveningEnabled: true,  eveningHour: 20,  eveningMinute: 0,
            addTaskEnabled: true,  addTaskHour: 9,   addTaskMinute: 0,
            financeEnabled: true,  financeHour: 14,  financeMinute: 0,
            chatEnabled:    true,  chatHour:    21,  chatMinute:    0,
        ])
    }
}

private extension Int {
    func nonZero(or fallback: Int) -> Int { self == 0 ? fallback : self }
}
