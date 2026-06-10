import SwiftUI
import SwiftData
import LocalAuthentication

struct FinanceView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FinanceViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction? = nil
    @State private var isSensitiveUnlocked: Bool = false
    @State private var authError: String? = nil
    @State private var showManageCategories = false
    private let syncService = iCloudDataSyncService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        balanceCard
                        periodPicker
                        incomeExpenseRow
                        categoryBreakdown
                        transactionsList
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Финансы")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showManageCategories = true } label: {
                        Image(systemName: "tag")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) { AddTransactionView() }
            .sheet(
                isPresented: Binding(
                    get: { editingTransaction != nil },
                    set: { if !$0 { editingTransaction = nil } }
                )
            ) {
                if let tx = editingTransaction {
                    EditTransactionView(transaction: tx)
                }
            }
            .sheet(isPresented: $showManageCategories) {
                ManageCategoriesView()
            }
            .alert(
                "Ошибка аутентификации",
                isPresented: Binding(
                    get: { authError != nil },
                    set: { if !$0 { authError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authError ?? "")
            }
            .onAppear {
                isSensitiveUnlocked = false
            }
            .onChange(of: transactions.count) { exportToiCloud() }
            .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidDownload)) { notification in
                importTransactionsFromiCloud(notification.object as? SyncPayload)
            }
        }
    }
    
    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(spacing: 6) {
            Text("Баланс")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
            let bal = viewModel.balance(transactions)
            if isSensitiveUnlocked {
                Text(bal.currencyFormatted)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(bal >= 0 ? Color(hex: "43e97b") : Color(hex: "fa709a"))
            } else {
                Text("••••••")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                Button {
                    authenticate()
                } label: {
                    Label("Показать", systemImage: "faceid")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "667eea"))
            }
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - Period Picker
    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(FinanceViewModel.TimePeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.spring(response: 0.3)) { viewModel.selectedPeriod = period }
                } label: {
                    Text(period.rawValue).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewModel.selectedPeriod == period ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.4))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(viewModel.selectedPeriod == period ? Color(hex: "667eea").opacity(0.4) : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4).background(AppColors.textPrimary.opacity(0.05)).clipShape(Capsule())
    }
    
    // MARK: - Income/Expense Row
    private var incomeExpenseRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "arrow.down.left").font(.system(size: 12)).foregroundStyle(Color(hex: "43e97b"))
                    Text("Доходы").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.6))
                }
                if isSensitiveUnlocked {
                    Text(viewModel.totalIncome(transactions).currencyFormatted)
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppColors.textPrimary)
                } else {
                    Text("••••••")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color(hex: "43e97b").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Color(hex: "fa709a"))
                    Text("Расходы").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.6))
                }
                if isSensitiveUnlocked {
                    Text(viewModel.totalExpenses(transactions).currencyFormatted)
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppColors.textPrimary)
                } else {
                    Text("••••••")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color(hex: "fa709a").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Category Breakdown
    private var categoryBreakdown: some View {
        let categories = viewModel.expensesByCategory(transactions)
        return Group {
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("По категориям").font(.headline).foregroundStyle(AppColors.textPrimary)
                    ForEach(categories, id: \.category) { item in
                        HStack {
                            Text(item.category).font(.subheadline).foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            if isSensitiveUnlocked {
                                Text(item.amount.currencyFormatted).font(.subheadline).fontWeight(.medium).foregroundStyle(AppColors.textPrimary)
                                Text("\(Int(item.percentage * 100))%").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.4))
                            } else {
                                Text("••••••").font(.subheadline).fontWeight(.medium).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                                Text("—").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.3))
                            }
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing))
                                .frame(width: isSensitiveUnlocked ? geo.size.width * item.percentage : 0, height: 6)
                        }.frame(height: 6)
                    }
                }
                .padding(16).background(AppColors.textPrimary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
    
    // MARK: - Transactions List
    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Транзакции").font(.headline).foregroundStyle(AppColors.textPrimary)
            
            let filtered = viewModel.filteredTransactions(transactions)
            if filtered.isEmpty {
                Text("Нет транзакций").font(.subheadline).foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    .frame(maxWidth: .infinity).padding(20)
            } else {
                ForEach(filtered, id: \.id) { tx in
                    TransactionRow(transaction: tx, isSensitiveUnlocked: isSensitiveUnlocked)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = tx }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingTransaction = tx
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(Color(hex: "667eea"))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { modelContext.delete(tx) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                editingTransaction = tx
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                withAnimation { modelContext.delete(tx) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(16).background(AppColors.textPrimary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        let reason = "Показать баланс и суммы доходов/расходов"
        
        // Avoid Face ID crash if NSFaceIDUsageDescription is missing in Info.plist
        let hasFaceIDUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String != nil
        
        if hasFaceIDUsageDescription, context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        self.isSensitiveUnlocked = true
                    } else {
                        self.authError = (evalError as NSError?)?.localizedDescription ?? "Не удалось пройти аутентификацию"
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
                DispatchQueue.main.async {
                    if success {
                        self.isSensitiveUnlocked = true
                    } else {
                        self.authError = (evalError as NSError?)?.localizedDescription ?? "Не удалось пройти аутентификацию"
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.authError = error?.localizedDescription ?? "Face ID/Touch ID недоступен"
            }
        }
    }

    // MARK: - iCloud Sync Helpers

    private func exportToiCloud() {
        let descriptor = FetchDescriptor<TaskItem>()
        let allTasks = (try? modelContext.fetch(descriptor)) ?? []
        syncService.exportToiCloud(tasks: allTasks, transactions: transactions)
    }

    private func importTransactionsFromiCloud(_ payload: SyncPayload?) {
        guard let payload else { return }
        let existingIDs = Set(transactions.map { $0.id })

        for dto in payload.transactions {
            guard !existingIDs.contains(dto.id) else { continue }
            let tx = Transaction(
                title: dto.title,
                amount: dto.amount,
                type: TransactionType(rawValue: dto.type) ?? .expense,
                category: dto.category,
                date: dto.date,
                note: dto.note
            )
            tx.id = dto.id
            modelContext.insert(tx)
        }
        try? modelContext.save()
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let isSensitiveUnlocked: Bool
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(transaction.type == .income ? Color(hex: "43e97b").opacity(0.2) : Color(hex: "fa709a").opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transaction.type.icon).font(.system(size: 14))
                        .foregroundStyle(transaction.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title).font(.subheadline).fontWeight(.medium).foregroundStyle(AppColors.textPrimary)
                Text(transaction.category).font(.caption2).foregroundStyle(AppColors.textPrimary.opacity(0.4))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if isSensitiveUnlocked {
                    Text("\(transaction.type == .income ? "+" : "-")\(transaction.amount.currencyFormatted)")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(transaction.type == .income ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                } else {
                    Text("••••••")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
                Text(transaction.date.shortFormatted).font(.caption2).foregroundStyle(AppColors.textPrimary.opacity(0.3))
            }
        }
        .padding(.vertical, 6)
    }
}
