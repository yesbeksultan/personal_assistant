import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var editingTask: TaskItem?
    
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var category = "Общее"
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    var isEditing: Bool { editingTask != nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Название").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Что нужно сделать?", text: $title)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Описание").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            TextField("Подробности...", text: $taskDescription, axis: .vertical)
                                .textFieldStyle(.plain).foregroundStyle(AppColors.textPrimary).lineLimit(3...6).padding(14)
                                .background(AppColors.textPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категория").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(taskCategories, id: \.self) { cat in
                                        Button { category = cat } label: {
                                            Text(cat).font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(category == cat ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.5))
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(category == cat
                                                    ? LinearGradient(colors: AppGradients.purple, startPoint: .leading, endPoint: .trailing)
                                                    : LinearGradient(colors: [AppColors.textPrimary.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Приоритет").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            HStack(spacing: 8) {
                                ForEach(TaskPriority.allCases, id: \.self) { p in
                                    Button { priority = p } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: p.icon).font(.system(size: 14))
                                            Text(p.rawValue).font(.system(size: 10))
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .foregroundStyle(priority == p ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.4))
                                        .background(priority == p ? Color(hex: priorityHex(p)).opacity(0.3) : AppColors.textPrimary.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                        
                        // Due date
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate) {
                                Text("Дедлайн").font(.caption).foregroundStyle(AppColors.textPrimary.opacity(0.5))
                            }.tint(Color(hex: "667eea"))
                            
                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical).colorScheme(.dark).tint(Color(hex: "667eea"))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Редактировать" : "Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Сохранить" : "Создать") { saveTask() }
                        .fontWeight(.semibold).foregroundStyle(Color(hex: "667eea")).disabled(title.isEmpty)
                }
            }
            .onAppear { loadEditingTask() }
        }
    }
    
    private func priorityHex(_ p: TaskPriority) -> String {
        switch p { case .low: "43e97b"; case .medium: "4facfe"; case .high: "fa709a"; case .urgent: "f5576c" }
    }
    
    private func loadEditingTask() {
        guard let task = editingTask else { return }
        title = task.title; taskDescription = task.taskDescription
        category = task.category; priority = task.priority
        if let d = task.dueDate { hasDueDate = true; dueDate = d }
    }
    
    private func saveTask() {
        if let task = editingTask {
            task.title = title; task.taskDescription = taskDescription
            task.category = category; task.priority = priority
            task.dueDate = hasDueDate ? dueDate : nil
        } else {
            let task = TaskItem(title: title, taskDescription: taskDescription, category: category, priority: priority, dueDate: hasDueDate ? dueDate : nil)
            modelContext.insert(task)
            if hasDueDate { NotificationService.shared.scheduleTaskReminder(for: task) }
        }
        dismiss()
    }
}
