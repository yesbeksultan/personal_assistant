import SwiftUI
import SwiftData
import Combine

// MARK: - AppTab Definition

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case tasks    = "tasks"
    case chat     = "chat"
    case finance  = "finance"
    case markdown = "markdown"
    case notes    = "notes"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:    return "Задачи"
        case .chat:     return "Friday AI"
        case .finance:  return "Финансы"
        case .markdown: return "Markdown"
        case .notes:    return "Заметки"
        }
    }

    var icon: String {
        switch self {
        case .tasks:    return "checkmark.circle"
        case .chat:     return "sparkles"
        case .finance:  return "creditcard"
        case .markdown: return "doc.richtext"
        case .notes:    return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .tasks:    return Color(hex: "667eea")
        case .chat:     return Color(hex: "f093fb")
        case .finance:  return Color(hex: "4facfe")
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
        if let data = UserDefaults.standard.data(forKey: "mainTabIDs"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            mainTabs = ids.compactMap { AppTab(rawValue: $0) }
        } else {
            mainTabs = defaultIDs.compactMap { AppTab(rawValue: $0) }
        }
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
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
