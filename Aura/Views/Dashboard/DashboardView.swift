import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var tasks: [TaskItem]
    @Query private var transactions: [Transaction]
    @State private var showSettings = false
    @State private var greeting = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header greeting
                    headerSection
                    
                    // Quick stats
                    statsGrid
                    
                    // Today's tasks
                    todayTasksSection
                    
                    // Financial summary
                    financeSummarySection
                    
                    // Spending chart
                    spendingChartSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(AppColors.appBackground)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .onAppear {
            updateGreeting()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.title3)
                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
            
            Text("Вот твоя сводка")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            
            Text(Date().fullFormatted)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCard(
                title: "Задачи",
                value: "\(pendingTaskCount)",
                subtitle: "незавершённых",
                icon: "checkmark.circle.fill",
                gradient: AppGradients.purple
            )
            
            StatCard(
                title: "Выполнено",
                value: "\(Int(completionRate * 100))%",
                subtitle: "за всё время",
                icon: "chart.pie.fill",
                gradient: AppGradients.blue
            )
            
            StatCard(
                title: "Расходы сегодня",
                value: todayExpenseFormatted,
                subtitle: "потрачено",
                icon: "arrow.up.right",
                gradient: AppGradients.pink
            )
            
            StatCard(
                title: "Баланс",
                value: balanceFormatted,
                subtitle: "за месяц",
                icon: "banknote.fill",
                gradient: AppGradients.green
            )
        }
    }
    
    // MARK: - Today's Tasks
    
    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Задачи на сегодня")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                
                Spacer()
                
                Text("\(todayTasks.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "667eea").opacity(0.5))
                    .clipShape(Capsule())
            }
            
            if todayTasks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    Text("Нет задач на сегодня")
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.textPrimary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(todayTasks.prefix(5), id: \.id) { task in
                    DashboardTaskRow(task: task)
                }
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Finance Summary
    
    private var financeSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Финансы за месяц")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            
            HStack(spacing: 12) {
                FinanceMiniCard(
                    title: "Доходы",
                    amount: monthIncome,
                    icon: "arrow.down.left",
                    color: Color(hex: "43e97b")
                )
                
                FinanceMiniCard(
                    title: "Расходы",
                    amount: monthExpenses,
                    icon: "arrow.up.right",
                    color: Color(hex: "fa709a")
                )
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Spending Chart
    
    private var spendingChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расходы за 7 дней")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(last7Days, id: \.date) { item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: AppGradients.purple,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(barHeight(for: item.amount), 4))
                        
                        Text(dayLabel(item.date))
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
            .padding(.top, 8)
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Computed Properties
    
    private var pendingTaskCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
    
    private var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }
    
    private var todayTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
            .sorted { priorityOrder($0.priority) > priorityOrder($1.priority) }
    }
    
    private var todayExpenseFormatted: String {
        let amount = transactions
            .filter { $0.type == .expense && $0.date.isToday }
            .reduce(0) { $0 + $1.amount }
        return amount.currencyFormatted
    }
    
    private var monthIncome: Double {
        transactions
            .filter { $0.type == .income && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var monthExpenses: Double {
        transactions
            .filter { $0.type == .expense && $0.date.isThisMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var balanceFormatted: String {
        (monthIncome - monthExpenses).currencyFormatted
    }
    
    private var last7Days: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!.startOfDay
            let amount = transactions
                .filter { $0.type == .expense && calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            return (date, amount)
        }
    }
    
    private func barHeight(for amount: Double) -> CGFloat {
        let maxAmount = last7Days.map(\.amount).max() ?? 1
        guard maxAmount > 0 else { return 4 }
        return CGFloat(amount / maxAmount) * 100
    }
    
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }
    
    private func priorityOrder(_ p: TaskPriority) -> Int {
        switch p { case .low: 0; case .medium: 1; case .high: 2; case .urgent: 3 }
    }
    
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greeting = "Доброе утро ☀️"
        case 12..<17: greeting = "Добрый день 🌤"
        case 17..<22: greeting = "Добрый вечер 🌙"
        default: greeting = "Доброй ночи 🌑"
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(AppColors.textPrimary.opacity(0.35))

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.28))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct DashboardTaskRow: View {
    let task: TaskItem
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: priorityColor))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                
                if let dueDate = task.dueDate {
                    Text(dueDate.shortFormatted)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
            }
            
            Spacer()
            
            Text(task.priority.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: priorityColor).opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
    }
    
    private var priorityColor: String {
        switch task.priority {
        case .low: return "43e97b"
        case .medium: return "4facfe"
        case .high: return "fa709a"
        case .urgent: return "f5576c"
        }
    }
}

struct FinanceMiniCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.6))
            }
            
            Text(amount.currencyFormatted)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [TaskItem.self, Transaction.self], inMemory: true)
}
