import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    
    @State private var store = FinanceCategoryStore.shared
    
    @State private var selectedType: TransactionType = .expense
    @State private var newCategoryName = ""
    @State private var renameSource: String? = nil
    @State private var renameTarget = ""
    @State private var showRenameSheet = false
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: String? = nil
    
    @State private var showSuggestionsSheet = false
    @State private var suggestionsTarget: String? = nil
    @State private var suggestionsText: String = ""
    
    private var categories: [String] {
        store.allCategories(for: selectedType)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    typePicker
                    
                    categoryList
                        .padding(12)
                        .background(AppColors.textPrimary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    addCategorySection
                }
                .padding()
            }
            .navigationTitle("Категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
            }
            .sheet(isPresented: $showRenameSheet) { renameSheet }
            .sheet(isPresented: $showSuggestionsSheet) { suggestionsSheet }
            .alert("Удалить категорию?", isPresented: $showDeleteAlert, presenting: categoryToDelete) { cat in
                Button("Удалить", role: .destructive) { deleteCategory(cat) }
                Button("Отмена", role: .cancel) { }
            } message: { cat in
                Text("Все транзакции с категорией \"\(cat)\" будут переназначены на \"Другое\".")
            }
        }
    }
    
    private var typePicker: some View {
        HStack(spacing: 4) {
            ForEach(TransactionType.allCases, id: \.self) { t in
                Button {
                    withAnimation { selectedType = t }
                } label: {
                    Text(t.rawValue).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedType == t ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.4))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(selectedType == t
                                   ? (t == .income ? Color(hex: "43e97b").opacity(0.3) : Color(hex: "fa709a").opacity(0.3))
                                   : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4).background(AppColors.textPrimary.opacity(0.05)).clipShape(Capsule())
    }
    
    private var categoryList: some View {
        List {
            ForEach(categories, id: \.self) { cat in
                HStack {
                    Text(cat)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    // Suggestions button
                    Button {
                        startEditSuggestions(cat)
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: "667eea"))
                    .padding(.trailing, 6)
                    
                    // Rename button
                    Button { startRename(cat) } label: { Image(systemName: "pencil") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(hex: "667eea"))
                    
                    // Delete button (custom-only)
                    if isCustom(cat) {
                        Button {
                            categoryToDelete = cat
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red.opacity(0.8))
                    }
                }
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if isCustom(cat) {
                        Button(role: .destructive) { categoryToDelete = cat; showDeleteAlert = true } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    Button { startRename(cat) } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }.tint(Color(hex: "667eea"))
                    Button { startEditSuggestions(cat) } label: {
                        Label("Подсказки", systemImage: "text.badge.plus")
                    }.tint(Color(hex: "667eea"))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var addCategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Новая категория").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
            HStack(spacing: 8) {
                TextField("Например: 🍿 Кино", text: $newCategoryName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(12)
                    .background(AppColors.textPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button {
                    addCategory()
                } label: {
                    Text("Добавить")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(hex: "667eea").opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private var renameSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Переименовать категорию")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Новое название", text: $renameTarget)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(12)
                        .background(AppColors.textPrimary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { showRenameSheet = false }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { performRename() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "667eea"))
                        .disabled(renameTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var suggestionsSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Подсказки для категории")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Подсказки через запятую", text: $suggestionsText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(12)
                        .background(AppColors.textPrimary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { showSuggestionsSheet = false }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { performSaveSuggestions() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
        }
    }
    
    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addCategory(name, type: selectedType)
        newCategoryName = ""
    }
    
    private func startRename(_ cat: String) {
        renameSource = cat
        renameTarget = cat
        showRenameSheet = true
    }
    
    private func performRename() {
        guard let source = renameSource else { return }
        let target = renameTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, target != source else { showRenameSheet = false; return }
        
        store.renameCategory(from: source, to: target, type: selectedType)
        // Bulk update transactions
        let affected = transactions.filter { $0.type == selectedType && $0.category == source }
        affected.forEach { $0.category = target }
        showRenameSheet = false
    }
    
    private func startEditSuggestions(_ cat: String) {
        suggestionsTarget = cat
        if let list = store.suggestions(for: cat) {
            suggestionsText = list.joined(separator: ", ")
        } else {
            suggestionsText = ""
        }
        showSuggestionsSheet = true
    }
    
    private func performSaveSuggestions() {
        guard let cat = suggestionsTarget else { showSuggestionsSheet = false; return }
        let list = suggestionsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        store.setSuggestions(list, for: cat)
        showSuggestionsSheet = false
    }
    
    private func deleteCategory(_ cat: String) {
        FinanceCategoryStore.shared.removeCategory(cat, type: selectedType)
        store.removeSuggestions(for: cat)
        // Reassign transactions to fallback
        let fallback: String
        let list = FinanceCategoryStore.shared.allCategories(for: selectedType)
        if selectedType == .expense {
            fallback = list.first ?? "📦 Другое"
        } else {
            fallback = list.first ?? "💵 Другое"
        }
        let affected = transactions.filter { $0.type == selectedType && $0.category == cat }
        affected.forEach { $0.category = fallback }
    }
    
    private func isCustom(_ cat: String) -> Bool {
        if selectedType == .expense {
            return store.customExpenseCategories.contains(cat)
        } else {
            return store.customIncomeCategories.contains(cat)
        }
    }
}

// MARK: - FinanceCategoryStore helpers
private extension FinanceCategoryStore {
    func removeCategory(_ name: String, type: TransactionType) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if type == .expense {
            if let idx = customExpenseCategories.firstIndex(of: trimmed) {
                customExpenseCategories.remove(at: idx)
                UserDefaults.standard.set(customExpenseCategories, forKey: "customExpenseCategories")
            }
        } else {
            if let idx = customIncomeCategories.firstIndex(of: trimmed) {
                customIncomeCategories.remove(at: idx)
                UserDefaults.standard.set(customIncomeCategories, forKey: "customIncomeCategories")
            }
        }
    }
    
    func renameCategory(from old: String, to new: String, type: TransactionType) {
        let oldT = old.trimmingCharacters(in: .whitespacesAndNewlines)
        let newT = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldT.isEmpty, !newT.isEmpty else { return }
        // Ensure new exists
        addCategory(newT, type: type)
        // Move suggestions if any
        if let s = customSuggestions[oldT] {
            customSuggestions[newT] = s
            customSuggestions.removeValue(forKey: oldT)
            UserDefaults.standard.set(customSuggestions, forKey: "customCategorySuggestions")
        }
        // Remove old if it was custom
        removeCategory(oldT, type: type)
    }
    
    func setSuggestions(_ suggestions: [String], for category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        customSuggestions[trimmed] = suggestions
        UserDefaults.standard.set(customSuggestions, forKey: "customCategorySuggestions")
    }

    func removeSuggestions(for category: String) {
        customSuggestions.removeValue(forKey: category)
        UserDefaults.standard.set(customSuggestions, forKey: "customCategorySuggestions")
    }
}

#Preview {
    ManageCategoriesView()
        .modelContainer(for: [Transaction.self], inMemory: true)
}
