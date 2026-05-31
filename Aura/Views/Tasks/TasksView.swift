import SwiftUI
import SwiftData

struct TasksView: View {
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TaskViewModel()
    @State private var showAddTask = false
    @State private var editingTask: TaskItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                if tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("Задачи")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Показать выполненные", isOn: $viewModel.showCompleted)
                        Divider()
                        Menu("Категория") {
                            Button("Все") { viewModel.selectedCategory = "Все" }
                            ForEach(taskCategories, id: \.self) { cat in
                                Button(cat) { viewModel.selectedCategory = cat }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Поиск задач...")
            .sheet(isPresented: $showAddTask) { AddTaskView() }
            .sheet(item: $editingTask) { task in AddTaskView(editingTask: task) }
        }
    }
    
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
    
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack(spacing: 12) {
                    MiniStat(label: "Всего", value: "\(tasks.count)", color: Color(hex: "667eea"))
                    MiniStat(label: "Осталось", value: "\(viewModel.pendingCount(tasks))", color: Color(hex: "fa709a"))
                    MiniStat(label: "Готово", value: "\(Int(viewModel.completionRate(tasks) * 100))%", color: Color(hex: "43e97b"))
                }
                .padding(.horizontal).padding(.top, 8)
                
                ForEach(viewModel.filteredTasks(tasks), id: \.id) { task in
                    TaskRow(task: task) { withAnimation(.spring(response: 0.3)) { task.isCompleted.toggle() } }
                        .contextMenu {
                            Button { editingTask = task } label: { Label("Редактировать", systemImage: "pencil") }
                            Button(role: .destructive) { withAnimation { modelContext.delete(task) } } label: { Label("Удалить", systemImage: "trash") }
                        }
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 100)
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    
    private var priorityColor: String {
        switch task.priority {
        case .low: "43e97b"; case .medium: "4facfe"; case .high: "fa709a"; case .urgent: "f5576c"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle().stroke(Color(hex: priorityColor), lineWidth: 2).frame(width: 26, height: 26)
                    if task.isCompleted {
                        Circle().fill(Color(hex: priorityColor)).frame(width: 26, height: 26)
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(task.isCompleted ? AppColors.textPrimary.opacity(0.4) : AppColors.textPrimary).strikethrough(task.isCompleted)
                HStack(spacing: 8) {
                    Text(task.category).font(.system(size: 10)).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                    if let d = task.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "clock").font(.system(size: 9))
                            Text(d.shortFormatted).font(.system(size: 10))
                        }.foregroundStyle(d < Date() && !task.isCompleted ? Color(hex: "f5576c") : AppColors.textPrimary.opacity(0.4))
                    }
                }
            }
            Spacer()
            HStack(spacing: 3) { Image(systemName: task.priority.icon).font(.system(size: 9)) }
                .foregroundStyle(Color(hex: priorityColor))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(hex: priorityColor).opacity(0.15)).clipShape(Capsule())
        }
        .padding(14).background(AppColors.textPrimary.opacity(task.isCompleted ? 0.02 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MiniStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(AppColors.textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
