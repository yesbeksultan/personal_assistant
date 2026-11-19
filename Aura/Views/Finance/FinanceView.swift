import SwiftUI
import SwiftData
import LocalAuthentication
import UniformTypeIdentifiers

struct FinanceView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FinanceViewModel()
    @State private var showAddTransaction = false
    @State private var addTransactionType: TransactionType = .expense
    @State private var editingTransaction: Transaction? = nil
    @State private var isSensitiveUnlocked: Bool = false
    @State private var authError: String? = nil
    @State private var showManageCategories = false
    @State private var showManualParser = false
    @State private var showAutomationGuide = false
    private let syncService = iCloudDataSyncService.shared

    // Finance lock setting — if false, data is always visible
    @AppStorage("financeLockEnabled") private var financeLockEnabled: Bool = true
    
    // Import/Export State
    @State private var showJSONExporter = false
    @State private var showCSVExporter = false
    @State private var showJSONImporter = false
    @State private var showCSVImporter = false
    @State private var jsonExportDocument = FinanceJSONDocument(data: Data())
    @State private var csvExportDocument = FinanceCSVDocument(text: "")
    @State private var importResultAlert: String? = nil
    @State private var showImportResult = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        PendingDraftsBanner()
                        ClipboardDetectedBanner()
                        sectionPicker
                        periodPicker
                        heroCardSection
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
                    Menu {
                        Button {
                            showManageCategories = true
                        } label: {
                            Label("Категории", systemImage: "tag")
                        }

                        Button {
                            showManualParser = true
                        } label: {
                            Label("Распознать СМС / уведомление", systemImage: "bell.badge")
                        }

                        Button {
                            showAutomationGuide = true
                        } label: {
                            Label("Автоматизация Apple Pay и СМС", systemImage: "bolt.badge.automatic")
                        }
                        
                        Divider()
                        
                        Button {
                            exportJSON()
                        } label: {
                            Label("Экспорт в JSON", systemImage: "arrow.down.doc")
                        }
                        
                        Button {
                            exportCSV()
                        } label: {
                            Label("Экспорт в CSV", systemImage: "tablecells")
                        }
                        
                        Button {
                            showJSONImporter = true
                        } label: {
                            Label("Импорт из JSON", systemImage: "arrow.up.doc")
                        }
                        
                        Button {
                            showCSVImporter = true
                        } label: {
                            Label("Импорт из CSV (Excel)", systemImage: "tablecells.badge.ellipsis")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addTransactionType = (viewModel.selectedSection == .income) ? .income : .expense
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(initialType: addTransactionType)
            }
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
            .sheet(isPresented: $showManualParser) {
                ManualNotificationParseView()
            }
            .sheet(isPresented: $showAutomationGuide) {
                BankAutomationGuideView()
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
                // If lock is disabled — always show data
                isSensitiveUnlocked = !financeLockEnabled
            }
            .onChange(of: transactions.count) { exportToiCloud() }
            .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidDownload)) { notification in
                importTransactionsFromiCloud(notification.object as? SyncPayload)
            }
            .background {
                Color.clear
                    .fileExporter(
                        isPresented: $showJSONExporter,
                        document: jsonExportDocument,
                        contentType: .json,
                        defaultFilename: "aura_finances_backup"
                    ) { result in
                        switch result {
                        case .success:
                            importResultAlert = "Данные успешно экспортированы в JSON!"
                            showImportResult = true
                        case .failure(let error):
                            importResultAlert = "Ошибка экспорта JSON: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
            }
            .background {
                Color.clear
                    .fileExporter(
                        isPresented: $showCSVExporter,
                        document: csvExportDocument,
                        contentType: .commaSeparatedText,
                        defaultFilename: "aura_finances"
                    ) { result in
                        switch result {
                        case .success:
                            importResultAlert = "Данные успешно экспортированы в CSV!"
                            showImportResult = true
                        case .failure(let error):
                            importResultAlert = "Ошибка экспорта CSV: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
            }
            .background {
                Color.clear
                    .fileImporter(
                        isPresented: $showJSONImporter,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            performImport(from: url)
                        case .failure(let error):
                            importResultAlert = "Ошибка выбора файла: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
            }
            .background {
                Color.clear
                    .fileImporter(
                        isPresented: $showCSVImporter,
                        allowedContentTypes: [.commaSeparatedText, .text],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            performCSVImport(from: url)
                        case .failure(let error):
                            importResultAlert = "Ошибка выбора файла: \(error.localizedDescription)"
                            showImportResult = true
                        }
                    }
            }
            .background {
                Color.clear
                    .alert(
                        "Импорт / Экспорт",
                        isPresented: $showImportResult
                    ) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(importResultAlert ?? "")
                    }
            }
        }
    }
    
    // MARK: - Section Picker (Расходы / Доходы / Обзор)
    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(FinanceViewModel.FinanceSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.selectedSection == section ? .white : AppColors.textPrimary.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if viewModel.selectedSection == section {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(section.accentColor)
                                    .shadow(color: section.accentColor.opacity(0.35), radius: 6, y: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppColors.textPrimary.opacity(0.04))
                            }
                        }
                    )
                }
            }
        }
        .padding(4)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Hero Card Section
    @ViewBuilder
    private var heroCardSection: some View {
        switch viewModel.selectedSection {
        case .income:
            incomeHeroCard
        case .expenses:
            expenseHeroCard
        case .all:
            overviewBalanceCard
        }
    }
    
    // MARK: - Income Hero Card
    private var incomeHeroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "43e97b"))
                        Text("Доходы (\(viewModel.selectedPeriod.rawValue.lowercased()))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                    }
                    
                    let income = viewModel.totalIncome(transactions)
                    if isSensitiveUnlocked {
                        Text(income.currencyFormatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "43e97b"))
                    } else {
                        lockedAmountView
                    }
                }
                
                Spacer()
                
                Button {
                    addTransactionType = .income
                    showAddTransaction = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Доход")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "43e97b"))
                    .clipShape(Capsule())
                }
            }
            
            Divider().opacity(0.4)
            
            // Sub-stats (Total all-time, month, today)
            HStack(spacing: 8) {
                statBox(
                    title: "За всё время",
                    amount: viewModel.totalIncomeAllTime(transactions),
                    color: Color(hex: "43e97b"),
                    icon: "sparkles"
                )
                statBox(
                    title: "В этом месяце",
                    amount: viewModel.monthIncome(transactions),
                    color: Color(hex: "43e97b"),
                    icon: "calendar"
                )
                statBox(
                    title: "Сегодня",
                    amount: viewModel.todayIncome(transactions),
                    color: Color(hex: "43e97b"),
                    icon: "sun.max.fill"
                )
            }
        }
        .padding(18)
        .background(Color(hex: "43e97b").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "43e97b").opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Expense Hero Card
    private var expenseHeroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "fa709a"))
                        Text("Расходы (\(viewModel.selectedPeriod.rawValue.lowercased()))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                    }
                    
                    let expense = viewModel.totalExpenses(transactions)
                    if isSensitiveUnlocked {
                        Text(expense.currencyFormatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "fa709a"))
                    } else {
                        lockedAmountView
                    }
                }
                
                Spacer()
                
                Button {
                    addTransactionType = .expense
                    showAddTransaction = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Расход")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "fa709a"))
                    .clipShape(Capsule())
                }
            }
            
            Divider().opacity(0.4)
            
            // Sub-stats (Total all-time, month, today)
            HStack(spacing: 8) {
                statBox(
                    title: "За всё время",
                    amount: viewModel.totalExpensesAllTime(transactions),
                    color: Color(hex: "fa709a"),
                    icon: "sparkles"
                )
                statBox(
                    title: "В этом месяце",
                    amount: viewModel.monthExpenses(transactions),
                    color: Color(hex: "fa709a"),
                    icon: "calendar"
                )
                statBox(
                    title: "Сегодня",
                    amount: viewModel.todayExpenses(transactions),
                    color: Color(hex: "fa709a"),
                    icon: "sun.max.fill"
                )
            }
        }
        .padding(18)
        .background(Color(hex: "fa709a").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "fa709a").opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Overview Balance Card
    private var overviewBalanceCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Баланс за период (\(viewModel.selectedPeriod.rawValue.lowercased()))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                let bal = viewModel.balance(transactions)
                if isSensitiveUnlocked {
                    Text(bal.currencyFormatted)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(bal >= 0 ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                } else {
                    lockedAmountView
                }
            }
            
            Divider().opacity(0.4)
            
            HStack(spacing: 12) {
                // Clickable Income chip
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedSection = .income
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "43e97b"))
                            Text("Доходы")
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                        }
                        if isSensitiveUnlocked {
                            Text(viewModel.totalIncome(transactions).currencyFormatted)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "43e97b"))
                        } else {
                            Text("••••••")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "43e97b").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                // Clickable Expense chip
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedSection = .expenses
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "fa709a"))
                            Text("Расходы")
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                        }
                        if isSensitiveUnlocked {
                            Text(viewModel.totalExpenses(transactions).currencyFormatted)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "fa709a"))
                        } else {
                            Text("••••••")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "fa709a").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            
            // All-time summary line (User can see both all-time totals directly!)
            HStack {
                HStack(spacing: 4) {
                    Text("Всего доходов:")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                    Text(isSensitiveUnlocked ? viewModel.totalIncomeAllTime(transactions).currencyFormatted : "••••")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "43e97b"))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Всего трат:")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                    Text(isSensitiveUnlocked ? viewModel.totalExpensesAllTime(transactions).currencyFormatted : "••••")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "fa709a"))
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity).padding(20)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - Stat Box Helper
    private func statBox(title: String, amount: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(AppColors.textPrimary.opacity(0.45))
            
            if isSensitiveUnlocked {
                Text(amount.currencyFormatted)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Text("••••")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppColors.textPrimary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Locked Amount View
    private var lockedAmountView: some View {
        HStack(spacing: 8) {
            Text("••••••")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            Button {
                authenticate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: biometricIcon)
                    Text("Показать")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "667eea").opacity(0.15))
                .clipShape(Capsule())
            }
            .foregroundStyle(Color(hex: "667eea"))
        }
    }

    /// Returns the appropriate biometric icon name for the device
    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "lock.fill"
        }
        return context.biometryType == .faceID ? "faceid" : "touchid"
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
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(viewModel.selectedPeriod == period ? Color(hex: "667eea").opacity(0.4) : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4).background(AppColors.textPrimary.opacity(0.05)).clipShape(Capsule())
    }
    
    // MARK: - Category Breakdown
    private var categoryBreakdown: some View {
        let categories: [(category: String, amount: Double, percentage: Double)]
        let breakdownTitle: String
        let barGradient: [Color]
        
        switch viewModel.selectedSection {
        case .income:
            categories = viewModel.incomeByCategory(transactions)
            breakdownTitle = "Доходы по категориям"
            barGradient = [Color(hex: "43e97b"), Color(hex: "38f9d7")]
        case .expenses:
            categories = viewModel.expensesByCategory(transactions)
            breakdownTitle = "Расходы по категориям"
            barGradient = [Color(hex: "fa709a"), Color(hex: "fee140")]
        case .all:
            categories = viewModel.expensesByCategory(transactions)
            breakdownTitle = "Расходы по категориям"
            barGradient = AppGradients.purple
        }
        
        return Group {
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(breakdownTitle).font(.headline).foregroundStyle(AppColors.textPrimary)
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
                                .fill(LinearGradient(colors: barGradient, startPoint: .leading, endPoint: .trailing))
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
            HStack {
                Text(listTitle).font(.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                let filtered = viewModel.filteredTransactions(transactions)
                Text("\(filtered.count)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(viewModel.selectedSection.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(viewModel.selectedSection.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            let filtered = viewModel.filteredTransactions(transactions)
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.selectedSection == .income ? "tray" : "cart")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.2))
                    Text(emptyListMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
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
            
            // In-section quick add button
            if viewModel.selectedSection != .all {
                Button {
                    addTransactionType = (viewModel.selectedSection == .income) ? .income : .expense
                    showAddTransaction = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(viewModel.selectedSection == .income ? "Добавить доход" : "Добавить расход")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(viewModel.selectedSection.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(viewModel.selectedSection.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
        }
        .padding(16).background(AppColors.textPrimary.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var listTitle: String {
        switch viewModel.selectedSection {
        case .income:   return "История доходов"
        case .expenses: return "История расходов"
        case .all:      return "Все транзакции"
        }
    }
    
    private var emptyListMessage: String {
        switch viewModel.selectedSection {
        case .income:   return "Нет доходов за этот период"
        case .expenses: return "Нет расходов за этот период"
        case .all:      return "Нет транзакций за этот период"
        }
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
    
    // MARK: - Manual Import/Export Helpers
    
    private func exportJSON() {
        do {
            let data = try FinanceImportExportService.shared.exportToJSON(transactions: transactions)
            jsonExportDocument = FinanceJSONDocument(data: data)
            showJSONExporter = true
        } catch {
            importResultAlert = "Ошибка подготовки JSON: \(error.localizedDescription)"
            showImportResult = true
        }
    }
    
    private func exportCSV() {
        let csvText = FinanceImportExportService.shared.exportToCSV(transactions: transactions)
        csvExportDocument = FinanceCSVDocument(text: csvText)
        showCSVExporter = true
    }
    
    private func performImport(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResultAlert = "Нет прав доступа к выбранному файлу."
            showImportResult = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let dtos = try FinanceImportExportService.shared.importFromJSON(data: data)
            let existingIDs = Set(transactions.map { $0.id })
            var importCount = 0
            
            for dto in dtos {
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
                importCount += 1
            }
            
            if importCount > 0 {
                try modelContext.save()
                exportToiCloud() // Sync to iCloud
            }
            
            importResultAlert = "Импорт завершен успешно! Добавлено \(importCount) транзакций."
            showImportResult = true
        } catch {
            importResultAlert = "Ошибка импорта: \(error.localizedDescription)"
            showImportResult = true
        }
    }
    
    private func performCSVImport(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importResultAlert = "Нет прав доступа к выбранному файлу."
            showImportResult = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            guard let csvText = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadUnknownStringEncoding)
            }
            
            let dtos = try FinanceImportExportService.shared.importFromCSV(text: csvText)
            let existingIDs = Set(transactions.map { $0.id })
            var importCount = 0
            
            for dto in dtos {
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
                importCount += 1
            }
            
            if importCount > 0 {
                try modelContext.save()
                exportToiCloud() // Sync to iCloud
            }
            
            importResultAlert = "Импорт завершен успешно! Добавлено \(importCount) транзакций из CSV."
            showImportResult = true
        } catch {
            importResultAlert = "Ошибка импорта CSV: \(error.localizedDescription)"
            showImportResult = true
        }
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
