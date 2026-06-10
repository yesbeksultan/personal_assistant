import SwiftUI
import SwiftData
import Combine

// MARK: - AppTab Definition

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case tasks    = "tasks"
    case chat     = "chat"
    case finance  = "finance"
    case calendar = "calendar"
    case markdown = "markdown"
    case notes    = "notes"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:    return "Задачи"
        case .chat:     return "Friday AI"
        case .finance:  return "Финансы"
        case .calendar: return "Календарь"
        case .markdown: return "Markdown"
        case .notes:    return "Заметки"
        }
    }

    var icon: String {
        switch self {
        case .tasks:    return "checkmark.circle"
        case .chat:     return "sparkles"
        case .finance:  return "creditcard"
        case .calendar: return "calendar"
        case .markdown: return "doc.richtext"
        case .notes:    return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .tasks:    return Color(hex: "667eea")
        case .chat:     return Color(hex: "f093fb")
        case .finance:  return Color(hex: "4facfe")
        case .calendar: return Color(hex: "5ee7df")
        case .markdown: return Color(hex: "43e97b")
        case .notes:    return Color(hex: "fa709a")
        }
    }

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .tasks:    TasksView()
        case .chat:     ChatView()
        case .finance:  FinanceView()
        case .calendar: CalendarView()
        case .markdown: MarkdownListView()
        case .notes:    NotesView()
        }
    }
}

// MARK: - Tab Preferences

class TabPreferences: ObservableObject {
    static let shared = TabPreferences()

    private let key = "mainTabIDs"
    private let defaultIDs = ["tasks", "chat", "finance"]
    private let maxMain = 3

    @Published var mainTabs: [AppTab] {
        didSet { save() }
    }

    var extraTabs: [AppTab] {
        AppTab.allCases.filter { !mainTabs.contains($0) }
    }

    private init() {
        mainTabs = Self.loadTabs(key: key, defaults: defaultIDs)

        // Наблюдаем изменения с других устройств
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange),
            name: .iCloudKVStoreDidChange,
            object: nil
        )
    }

    @objc private func kvStoreDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let freshTabs = Self.loadTabs(key: self.key, defaults: self.defaultIDs)
            if freshTabs != self.mainTabs {
                self.mainTabs = freshTabs
            }
        }
    }

    private static func loadTabs(key: String, defaults: [String]) -> [AppTab] {
        // Сначала пробуем iCloud KV Store
        let kvStore = NSUbiquitousKeyValueStore.default
        if let ids = kvStore.array(forKey: key) as? [String], !ids.isEmpty {
            let tabs = ids.compactMap { AppTab(rawValue: $0) }
            if !tabs.isEmpty { return tabs }
        }
        // Фолбек на UserDefaults (миграция старых данных)
        if let data = UserDefaults.standard.data(forKey: key),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            let tabs = ids.compactMap { AppTab(rawValue: $0) }
            if !tabs.isEmpty { return tabs }
        }
        return defaults.compactMap { AppTab(rawValue: $0) }
    }

    func isInMain(_ tab: AppTab) -> Bool { mainTabs.contains(tab) }
    var canAddMore: Bool { mainTabs.count < maxMain }

    func addToMain(_ tab: AppTab) {
        guard !isInMain(tab), canAddMore else { return }
        mainTabs.append(tab)
    }

    func removeFromMain(_ tab: AppTab) {
        mainTabs.removeAll { $0 == tab }
    }

    func move(from source: IndexSet, to destination: Int) {
        mainTabs.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let ids = mainTabs.map(\.rawValue)
        // Сохраняем в iCloud KV Store (синхронизируется на все устройства)
        let kvStore = NSUbiquitousKeyValueStore.default
        kvStore.set(ids, forKey: key)
        kvStore.synchronize()
        // Также в UserDefaults как резервная копия
        UserDefaults.standard.set(try? JSONEncoder().encode(ids), forKey: key)
        iCloudService.shared.markSynced()
    }
}
