import SwiftUI
import SwiftData

struct TasksView: View {
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TaskViewModel()
    @State private var showAddTask = false
    @State private var showDatePicker = false
    @State private var editingTask: TaskItem?
    private let syncService = iCloudDataSyncService.shared
    
    private var isCustomDateSelected: Bool {
        if case .custom = viewModel.selectedDateFilter {
            return true
        }
        return false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                if tasks.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Задачи")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: isCustomDateSelected ? "calendar.badge.clock" : "calendar")
                            .font(.system(size: 16, weight: isCustomDateSelected ? .bold : .regular))
                            .foregroundStyle(isCustomDateSelected ? Color(hex: "4facfe") : AppColors.textPrimary.opacity(0.65))
                    }
                    
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Поиск задач...")
            .sheet(isPresented: $showAddTask) {
                AddTaskView(initialDueDate: viewModel.initialDueDateForNewTask)
            }
            .sheet(item: $editingTask) { task in
                AddTaskView(editingTask: task)
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .onChange(of: tasks.count) { exportToiCloud() }
            .onChange(of: tasks.map { $0.isCompleted }) { exportToiCloud() }
            .onReceive(NotificationCenter.default.publisher(for: .iCloudDataDidDownload)) { notification in
                importFromiCloud(notification.object as? SyncPayload)
            }
        }
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            Toggle("Показать выполненные", isOn: $viewModel.showCompleted)
            
            Divider()
            
            Menu("Категория: \(viewModel.selectedCategory)") {
                Button("Все") { viewModel.selectedCategory = "Все" }
                ForEach(taskCategories, id: \.self) { cat in
                    Button(cat) { viewModel.selectedCategory = cat }
                }
            }
            
            if viewModel.selectedDateFilter != .all || viewModel.selectedCategory != "Все" || !viewModel.searchText.isEmpty {
                Divider()
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.selectedDateFilter = .all
                        viewModel.selectedCategory = "Все"
                        viewModel.searchText = ""
                    }
                } label: {
                    Label("Сбросить фильтры", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: (viewModel.selectedCategory != "Все" || viewModel.showCompleted)
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .foregroundStyle(AppColors.textPrimary.opacity(0.75))
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                // Quick stats
                statsRow
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Date filter pills
                dateFilterBar
                
                // Banner if a custom date is chosen
                if case .custom(let date) = viewModel.selectedDateFilter {
                    customDateBanner(date: date)
                }
                
                // Task sections or empty state
                let sections = viewModel.groupedTasks(tasks)
                if sections.isEmpty {
                    filterEmptyState
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 18) {
                        ForEach(sections) { section in
                            taskSection(section)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Mini Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            MiniStat(label: "Всего", value: "\(tasks.count)", color: Color(hex: "667eea"))
            MiniStat(label: "Осталось", value: "\(viewModel.pendingCount(tasks))", color: Color(hex: "fa709a"))
            MiniStat(label: "Готово", value: "\(Int(viewModel.completionRate(tasks) * 100))%", color: Color(hex: "43e97b"))
        }
    }
    
    // MARK: - Date Filter Bar
    
    private var dateFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskDateFilter.standardFilters) { filter in
                    let count = viewModel.count(for: filter, in: tasks)
                    let isSelected = viewModel.selectedDateFilter == filter
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedDateFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(filter.title)
                                .font(.system(size: 13, weight: .medium))
                            
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        isSelected
                                            ? Color.white.opacity(0.25)
                                            : AppColors.textPrimary.opacity(0.1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : (filter == .overdue && count > 0 ? Color(hex: "f5576c") : AppColors.textPrimary.opacity(0.65))
                        )
                        .background(
                            Group {
                                if isSelected {
                                    LinearGradient(
                                        colors: filter == .overdue
                                            ? [Color(hex: "f5576c"), Color(hex: "f093fb")]
                                            : [Color(hex: "667eea"), Color(hex: "764ba2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    AppColors.textPrimary.opacity(0.06)
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? Color.white.opacity(0.2)
                                        : (filter == .overdue && count > 0 ? Color(hex: "f5576c").opacity(0.3) : Color.clear),
                                    lineWidth: 1
                                )
                        )
                    }
                }
                
                // Custom date pill or "Выбрать дату" button
                if case .custom(let date) = viewModel.selectedDateFilter {
                    let count = viewModel.count(for: .custom(date), in: tasks)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .semibold))
                        Text(date.shortFormatted)
                            .font(.system(size: 13, weight: .medium))
                        
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedDateFilter = .all
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(Color.white)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                } else {
                    Button {
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Выбрать дату")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                        .background(AppColors.textPrimary.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Custom Date Banner
    
    private func customDateBanner(date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "4facfe"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Задачи на выбранную дату")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                Text(date.fullFormatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.selectedDateFilter = .all
                }
            } label: {
                Text("Все даты")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "4facfe"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "4facfe").opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    // MARK: - Task Section
    
    private func taskSection(_ section: TaskTimeSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: section.colorHex))
                
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
                
                if let subtitle = section.subtitle {
                    Text("• \(subtitle)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                }
                
                Spacer()
                
                Text("\(section.tasks.count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: section.colorHex).opacity(0.15))
                    .foregroundStyle(Color(hex: section.colorHex))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // Task Items
            VStack(spacing: 8) {
                ForEach(section.tasks, id: \.id) { task in
                    TaskRow(task: task) {
                        withAnimation(.spring(response: 0.3)) {
                            task.isCompleted.toggle()
                            if task.isCompleted {
                                NotificationService.shared.cancelTaskReminder(for: task)
                            } else if let due = task.dueDate, due > Date() {
                                NotificationService.shared.scheduleTaskReminder(for: task)
                            }
                        }
                    }
                    .contextMenu {
                        Button { editingTask = task } label: { Label("Редактировать", systemImage: "pencil") }
                        Button(role: .destructive) {
                            withAnimation {
                                NotificationService.shared.cancelTaskReminder(for: task)
                                modelContext.delete(task)
                            }
                        } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
            }
        }
    }
    
    // MARK: - Filter Empty State
    
    private var filterEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.selectedDateFilter.icon)
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(AppColors.textPrimary.opacity(0.2))
                .padding(.top, 30)
            
            Text(emptyFilterTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
            
            Text(emptyFilterSubtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                .padding(.horizontal, 32)
            
            HStack(spacing: 12) {
                if viewModel.selectedDateFilter != .all || viewModel.selectedCategory != "Все" || !viewModel.searchText.isEmpty {
                    Button {
                        withAnimation {
                            viewModel.selectedDateFilter = .all
                            viewModel.selectedCategory = "Все"
                            viewModel.searchText = ""
                        }
                    } label: {
                        Text("Сбросить фильтры")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .overlay(Capsule().stroke(AppColors.textPrimary.opacity(0.18), lineWidth: 1))
                    }
                }
                
                Button {
                    showAddTask = true
                } label: {
                    Text("Создать задачу")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyFilterTitle: String {
        if !viewModel.searchText.isEmpty {
            return "Ничего не найдено"
        }
        switch viewModel.selectedDateFilter {
        case .all: return "Нет активных задач"
        case .today: return "На сегодня задач нет"
        case .tomorrow: return "На завтра планов нет"
        case .thisWeek: return "На этой неделе чисто"
        case .thisMonth: return "В этом месяце задач нет"
        case .overdue: return "Нет просроченных задач"
        case .noDate: return "Нет задач без даты"
        case .custom(let date):
            let f = DateFormatter()
            f.locale = Locale.autoupdatingCurrent
            f.dateFormat = "d MMMM"
            return "На \(f.string(from: date)) ничего нет"
        }
    }
    
    private var emptyFilterSubtitle: String {
        if !viewModel.searchText.isEmpty {
            return "Попробуйте изменить поисковый запрос"
        }
        switch viewModel.selectedDateFilter {
        case .all: return "Создайте новую задачу, нажав кнопку +"
        case .today: return "Отличный повод отдохнуть или запланировать новое дело!"
        case .tomorrow: return "Запланируйте дела на завтра заранее"
        case .thisWeek: return "Вся неделя свободна от запланированных дел"
        case .thisMonth: return "Планы на этот месяц еще не сформированы"
        case .overdue: return "Прекрасно! Все сроки соблюдены вовремя 👍"
        case .noDate: return "У всех ваших задач установлены дедлайны"
        case .custom: return "Нажмите кнопку ниже, чтобы добавить задачу на эту дату"
        }
    }
    
    // MARK: - Initial Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(AppColors.textPrimary.opacity(0.18))
            Text("Нет задач").font(.title2).fontWeight(.semibold).foregroundStyle(AppColors.textPrimary)
            Text("Нажми + чтобы добавить первую задачу").font(.subheadline).foregroundStyle(AppColors.textPrimary.opacity(0.4))
            Button { showAddTask = true } label: {
                Text("Создать задачу")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    .padding(.horizontal, 24).padding(.vertical, 11)
                    .overlay(Capsule().stroke(AppColors.textPrimary.opacity(0.18), lineWidth: 1))
            }
        }
    }
    
    // MARK: - DatePicker Sheet
    
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Выберите дату",
                    selection: $viewModel.selectedCustomDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(Color(hex: "667eea"))
                .padding()
                .background(AppColors.textPrimary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Quick date presets
                HStack(spacing: 8) {
                    Button("Сегодня") {
                        viewModel.selectedCustomDate = Date()
                        viewModel.selectedDateFilter = .today
                        showDatePicker = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Завтра") {
                        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                            viewModel.selectedCustomDate = tomorrow
                            viewModel.selectedDateFilter = .tomorrow
                            showDatePicker = false
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Через неделю") {
                        if let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) {
                            viewModel.selectedCustomDate = nextWeek
                            viewModel.selectedDateFilter = .custom(Calendar.current.startOfDay(for: nextWeek))
                            showDatePicker = false
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedDateFilter = .custom(Calendar.current.startOfDay(for: viewModel.selectedCustomDate))
                    }
                    showDatePicker = false
                } label: {
                    Text("Показать задачи на эту дату")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                if case .custom = viewModel.selectedDateFilter {
                    Button("Сбросить фильтр даты") {
                        withAnimation {
                            viewModel.selectedDateFilter = .all
                        }
                        showDatePicker = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "f5576c"))
                }
            }
            .padding()
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationTitle("Фильтр по дате")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { showDatePicker = false }
                        .foregroundStyle(Color(hex: "667eea"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - iCloud Sync Helpers

    private func exportToiCloud() {
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = (try? modelContext.fetch(descriptor)) ?? []
        syncService.exportToiCloud(tasks: tasks, transactions: allTransactions)
    }

    private func importFromiCloud(_ payload: SyncPayload?) {
        guard let payload else { return }

        let existingIDs = Set(tasks.map { $0.id })

        for dto in payload.tasks {
            if let existing = tasks.first(where: { $0.id == dto.id }) {
                dto.apply(to: existing)
            } else if !existingIDs.contains(dto.id) {
                let newTask = TaskItem(
                    title: dto.title,
                    taskDescription: dto.taskDescription,
                    category: dto.category,
                    priority: TaskPriority(rawValue: dto.priority) ?? .medium,
                    isCompleted: dto.isCompleted,
                    dueDate: dto.dueDate
                )
                newTask.id = dto.id
                newTask.createdAt = dto.createdAt
                modelContext.insert(newTask)
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Task Row View

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    
    private var priorityColor: String {
        switch task.priority {
        case .low: return "43e97b"
        case .medium: return "4facfe"
        case .high: return "fa709a"
        case .urgent: return "f5576c"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: priorityColor), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if task.isCompleted {
                        Circle()
                            .fill(Color(hex: priorityColor))
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(task.isCompleted ? AppColors.textPrimary.opacity(0.4) : AppColors.textPrimary)
                    .strikethrough(task.isCompleted)
                
                HStack(spacing: 8) {
                    Text(task.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.textPrimary.opacity(0.06))
                        .clipShape(Capsule())
                    
                    if let d = task.dueDate {
                        let isOverdue = d < Date() && !task.isCompleted
                        HStack(spacing: 3) {
                            Image(systemName: isOverdue ? "exclamationmark.circle" : "clock")
                                .font(.system(size: 9))
                            Text(d.smartDueFormatted)
                                .font(.system(size: 10, weight: isOverdue ? .semibold : .regular))
                        }
                        .foregroundStyle(isOverdue ? Color(hex: "f5576c") : AppColors.textPrimary.opacity(0.45))
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: task.priority.icon).font(.system(size: 9))
                Text(task.priority.rawValue).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color(hex: priorityColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: priorityColor).opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(14)
        .background(AppColors.textPrimary.opacity(task.isCompleted ? 0.02 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Mini Stat

struct MiniStat: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
