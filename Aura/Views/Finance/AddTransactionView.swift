import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var category = "🍔 Еда"
    @State private var date = Date()
    @State private var note = ""
    @State private var showAddCategorySheet = false
    
    var categories: [String] {
        FinanceCategoryStore.shared.allCategories(for: type)
    }
    
    private var suggestedTitles: [String] {
        switch category {
        case "🍔 Еда": return ["Продукты", "Ресторан", "Кофе", "Фастфуд", "Доставка"]
        case "🚗 Транспорт": return ["Такси", "Бензин", "Автобус", "Метро", "Парковка"]
        case "🏠 Жильё": return ["Аренда", "Ремонт", "Мебель", "Хозтовары"]
        case "🎮 Развлечения": return ["Кино", "Игры", "Подписки", "Концерт"]
        case "👕 Одежда": return ["Футболка", "Обувь", "Куртка", "Джинсы"]
        case "💊 Здоровье": return ["Аптека", "Врач", "Анализы", "Витамины"]
        case "💡 Коммуналка": return ["Свет", "Вода", "Интернет", "Отопление"]
        case "📱 Связь": return ["Мобильная связь", "Баланс", "Роуминг"]
        case "💼 Зарплата": return ["Зарплата", "Аванс", "Премия", "Остаток"]
        case "💰 Фриланс": return ["Проект", "Консультация", "Дизайн"]
        case "📈 Инвестиции": return ["Акции", "Крипта", "Дивиденды"]
        case "🎁 Подарки": return ["День рождения", "Свадьба", "Праздник"]
        default:
            // Custom category suggestions from store
            if let custom = FinanceCategoryStore.shared.suggestions(for: category), !custom.isEmpty {
                return custom
            }
            
            // Default fallback based on type (income/expense)
            let cleanCategory: String
            if let spaceIndex = category.firstIndex(of: " ") {
                cleanCategory = String(category[category.index(after: spaceIndex)...])
            } else {
                cleanCategory = category
            }
            
            if type == .income {
                return [cleanCategory, "Перевод", "Подарок", "Кэшбэк", "Поступление"]
            } else {
                return [cleanCategory, "Покупка", "Оплата", "Услуга", "Подписка"]
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Type picker
                        HStack(spacing: 4) {
                            ForEach(TransactionType.allCases, id: \.self) { t in
                                Button {
                                    withAnimation { type = t; category = categories.first ?? "" }
                                } label: {
                                    Text(t.rawValue).font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(type == t ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.4))
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(type == t
                                            ? (t == .income ? Color(hex: "43e97b").opacity(0.3) : Color(hex: "fa709a").opacity(0.3))
                                            : Color.clear)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(4).background(AppColors.textPrimary.opacity(0.05)).clipShape(Capsule())
                        
                        // Amount
                        VStack(spacing: 8) {
                            Text("Сумма").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                TextField("0", text: $amountText)
                                    .keyboardType(.decimalPad).textFieldStyle(.plain)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary).multilineTextAlignment(.center)
                                Text("₸").font(.system(size: 28, weight: .medium)).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(20).background(AppColors.textPrimary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Название").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Что это?", text: $title)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestedTitles, id: \.self) { suggestion in
                                        Button {
                                            title = suggestion
                                        } label: {
                                            Text(suggestion)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(title == suggestion ? Color(hex: "667eea") : AppColors.textPrimary.opacity(0.8))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(title == suggestion ? Color(hex: "667eea").opacity(0.2) : AppColors.textPrimary.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категория").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(categories, id: \.self) { cat in
                                    Button { category = cat } label: {
                                        Text(cat).font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(category == cat ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.5))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(category == cat
                                                ? Color(hex: "667eea").opacity(0.4) : AppColors.textPrimary.opacity(0.05))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Button {
                                    showAddCategorySheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Создать")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "667eea"))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(hex: "667eea").opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        
                        // Date
                        DatePicker("Дата", selection: $date, displayedComponents: [.date])
                            .foregroundStyle(AppColors.textPrimary).colorScheme(.dark).tint(Color(hex: "667eea"))
                        
                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Заметка").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Необязательно...", text: $note)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Новая транзакция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить") { saveTransaction() }
                        .fontWeight(.semibold).foregroundStyle(Color(hex: "667eea"))
                        .disabled(title.isEmpty || amountText.isEmpty)
                }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(type: type) { name, suggestions in
                    FinanceCategoryStore.shared.addCategory(name, type: type, suggestions: suggestions)
                    category = name
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private func saveTransaction() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) else { return }
        let tx = Transaction(title: title, amount: amount, type: type, category: category, date: date, note: note)
        modelContext.insert(tx)
        dismiss()
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let type: TransactionType
    let onAdd: (String, [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var suggestionsText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название категории").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        TextField("Например: 🍿 Кино или 🛠️ Ремонт", text: $name)
                            .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                            .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Подсказки для названий (через запятую)").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        TextField("Например: Билеты, Попкорн, Напитки", text: $suggestionsText)
                            .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                            .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Новая категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить") {
                        let nameTrimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let list = suggestionsText
                            .components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        onAdd(nameTrimmed, list)
                        dismiss()
                    }
                    .fontWeight(.semibold).foregroundStyle(Color(hex: "667eea"))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
