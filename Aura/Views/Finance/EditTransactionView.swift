import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction
    
    @State private var amountText: String = ""
    @State private var showAddCategorySheet = false
    
    private var categories: [String] {
        FinanceCategoryStore.shared.allCategories(for: transaction.type)
    }
    
    private var suggestedTitles: [String] {
        if let custom = FinanceCategoryStore.shared.suggestions(for: transaction.category), !custom.isEmpty {
            return custom
        }
        // Fallback suggestions based on current type and category name
        let cleanCategory: String
        if let spaceIndex = transaction.category.firstIndex(of: " ") {
            cleanCategory = String(transaction.category[transaction.category.index(after: spaceIndex)...])
        } else {
            cleanCategory = transaction.category
        }
        if transaction.type == .income {
            return [cleanCategory, "Перевод", "Подарок", "Кэшбэк", "Поступление"]
        } else {
            return [cleanCategory, "Покупка", "Оплата", "Услуга", "Подписка"]
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
                                    withAnimation {
                                        transaction.type = t
                                        // Ensure category fits the new type
                                        let list = FinanceCategoryStore.shared.allCategories(for: t)
                                        if !list.contains(transaction.category) {
                                            transaction.category = list.first ?? transaction.category
                                        }
                                    }
                                } label: {
                                    Text(t.rawValue).font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(transaction.type == t ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.4))
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(transaction.type == t
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
                            TextField("Что это?", text: $transaction.title)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestedTitles, id: \.self) { suggestion in
                                        Button {
                                            transaction.title = suggestion
                                        } label: {
                                            Text(suggestion)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(transaction.title == suggestion ? Color(hex: "667eea") : AppColors.textPrimary.opacity(0.8))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(transaction.title == suggestion ? Color(hex: "667eea").opacity(0.2) : AppColors.textPrimary.opacity(0.1))
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
                                    Button { transaction.category = cat } label: {
                                        Text(cat).font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(transaction.category == cat ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.5))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(transaction.category == cat
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
                        DatePicker("Дата", selection: $transaction.date, displayedComponents: [.date])
                            .foregroundStyle(AppColors.textPrimary).colorScheme(.dark).tint(Color(hex: "667eea"))
                        
                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Заметка").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Необязательно...", text: $transaction.note)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Изменить транзакцию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { saveChanges() }
                        .fontWeight(.semibold).foregroundStyle(Color(hex: "667eea"))
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(type: transaction.type) { name, suggestions in
                    FinanceCategoryStore.shared.addCategory(name, type: transaction.type, suggestions: suggestions)
                    transaction.category = name
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                amountText = String(format: "%.2f", transaction.amount)
            }
        }
    }
    
    private var canSave: Bool {
        let trimmed = transaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) != nil
    }
    
    private func saveChanges() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized) else { return }
        transaction.amount = amount
        // Changes to @Bindable model will be persisted by SwiftData
        dismiss()
    }
}
