import SwiftUI
import SwiftData

struct ExprToken: Identifiable, Equatable {
    let id = UUID()
    let value: String
    let cardIndex: Int? // 0-3 for numbers, nil for operators/brackets
}

struct Game24View: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameRecord.date, order: .reverse) private var records: [GameRecord]
    
    // Game State
    @State private var currentProblem: Game24Problem? = nil
    @State private var selectedDifficulty: GameDifficulty = .easy
    @State private var exprTokens: [ExprToken] = []
    @State private var usedCardIndices: Set<Int> = []
    
    // UI Feedback State
    @State private var showSolutionAlert = false
    @State private var showSuccessOverlay = false
    @State private var evaluationResult: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String = ""
    
    // Derived stats
    private var solvedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let dayRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        return dayRecords.reduce(0) { $0 + $1.solvedCount }
    }

    private var currentStreak: Int {
        // Count consecutive days (including today) with at least one solved puzzle
        var streak = 0
        var day = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        while true {
            let hasSolved = records.contains { calendar.isDate($0.date, inSameDayAs: day) && $0.solvedCount > 0 }
            if hasSolved {
                streak += 1
                if let prev = calendar.date(byAdding: .day, value: -1, to: day) {
                    day = prev
                } else { break }
            } else {
                break
            }
        }
        return streak
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Stats Card
                        statsHeaderCard
                        
                        // Difficulty Picker
                        difficultyPicker
                        
                        // Solved Puzzles Bar Chart
                        solvedProgressChart
                        
                        if let problem = currentProblem {
                            // Number Cards Display
                            VStack(spacing: 12) {
                                Text("Составьте 24, используя каждое число ровно один раз:")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    ForEach(0..<4, id: \.self) { index in
                                        let num = problem.numbers[index]
                                        let isUsed = usedCardIndices.contains(index)
                                        
                                        Button {
                                            useNumber(num, at: index)
                                        } label: {
                                            Text("\(num)")
                                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                                .foregroundStyle(AppColors.textPrimary)
                                                .frame(width: 70, height: 70)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(isUsed ? AppColors.textPrimary.opacity(0.1) : Color(hex: "667eea").opacity(0.2))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .stroke(isUsed ? Color.clear : Color(hex: "667eea").opacity(0.4), lineWidth: 1.5)
                                                        )
                                                )
                                                .opacity(isUsed ? 0.3 : 1.0)
                                                .scaleEffect(isUsed ? 0.9 : 1.0)
                                        }
                                        .disabled(isUsed)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .padding()
                            .background(AppColors.textPrimary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1))
                            
                            // Expression Workspace
                            expressionWorkspace
                            
                            // Game Controls (Operators & Action Buttons)
                            gameKeyboard
                            
                        } else {
                            // Loading state
                            ProgressView("Генерация головоломки...")
                                .padding(.top, 50)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                
                // Win Success Overlay
                if showSuccessOverlay {
                    successOverlay
                }
            }
            .navigationTitle("Игра 24")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSolutionAlert = true
                    } label: {
                        Label("Решение", systemImage: "lightbulb")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "667eea"))
                    }
                }
            }
            .alert(
                "Подсказка решения",
                isPresented: $showSolutionAlert
            ) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(currentProblem?.solution ?? "Решений не найдено")
            }
            .onAppear {
                if currentProblem == nil {
                    loadNewProblem()
                }
            }
            .onChange(of: selectedDifficulty) {
                loadNewProblem()
            }
        }
    }
    
    // MARK: - Game Logic Helpers
    
    private func loadNewProblem() {
        withAnimation {
            currentProblem = Game24Service.shared.generateProblem(difficulty: selectedDifficulty)
            clearExpression()
            errorMessage = nil
            evaluationResult = ""
        }
    }
    
    private func useNumber(_ num: Int, at index: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            exprTokens.append(ExprToken(value: String(num), cardIndex: index))
            usedCardIndices.insert(index)
            evaluateCurrentExpression()
        }
    }
    
    private func appendOperator(_ op: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            exprTokens.append(ExprToken(value: op, cardIndex: nil))
            evaluateCurrentExpression()
        }
    }
    
    private func undoLastToken() {
        guard !exprTokens.isEmpty else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            let last = exprTokens.removeLast()
            if let idx = last.cardIndex {
                usedCardIndices.remove(idx)
            }
            evaluateCurrentExpression()
        }
    }
    
    private func clearExpression() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            exprTokens.removeAll()
            usedCardIndices.removeAll()
            evaluationResult = ""
            errorMessage = nil
        }
    }
    
    private func evaluateCurrentExpression() {
        errorMessage = nil
        
        let expressionString = exprTokens.map { $0.value }.joined(separator: " ")
        if expressionString.isEmpty {
            evaluationResult = ""
            return
        }
        
        // Form string replacing N with N.0 for floating-point calculation in NSExpression
        var evalString = ""
        for token in exprTokens {
            if token.cardIndex != nil {
                evalString += "\(token.value).0"
            } else {
                evalString += token.value
            }
        }
        
        let expression = NSExpression(format: evalString)
        let context = NSMutableDictionary()
        
        do {
            if let result = try expression.expressionValue(with: nil, context: context) as? Double {
                if result.isNaN || result.isInfinite {
                    evaluationResult = "= Ошибка"
                } else if abs(result - Double(Int(result))) < 0.001 {
                    evaluationResult = "= \(Int(result))"
                } else {
                    evaluationResult = "= \(String(format: "%.2f", result))"
                }
            } else {
                evaluationResult = ""
            }
        } catch {
            evaluationResult = ""
        }
    }
    
    private func submitExpression() {
        guard let problem = currentProblem else { return }
        
        let userFormula = exprTokens.map { $0.value }.joined(separator: " ")
        let validation = Game24Service.shared.verifyUserSolution(expr: userFormula, problemNumbers: problem.numbers)
        
        if validation.isValid {
            // Success! Save record
            recordSolvedGame()
            withAnimation(.spring()) {
                successMessage = "Вы решили задачу! Получилось ровно 24."
                showSuccessOverlay = true
            }
        } else {
            withAnimation {
                errorMessage = validation.message
            }
        }
    }
    
    private func recordSolvedGame() {
        let today = Calendar.current.startOfDay(for: Date())
        let diffStr = selectedDifficulty.rawValue
        
        // Find existing record
        let descriptor = FetchDescriptor<GameRecord>()
        let allRecords = (try? modelContext.fetch(descriptor)) ?? []
        
        if let existing = allRecords.first(where: { $0.date == today && $0.difficulty == diffStr }) {
            existing.solvedCount += 1
        } else {
            let newRecord = GameRecord(date: today, difficulty: diffStr, solvedCount: 1)
            modelContext.insert(newRecord)
        }
        
        try? modelContext.save()
    }
    
    // MARK: - View Components
    
    private var statsHeaderCard: some View {
        HStack(spacing: 16) {
            // Solved Today
            VStack(alignment: .leading, spacing: 4) {
                Text("Решено сегодня")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(solvedToday)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "4facfe"))
                    Text("задач")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider().frame(height: 40)
            
            // Daily Streak
            VStack(alignment: .leading, spacing: 4) {
                Text("Ударный режим")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    Text("\(currentStreak) \(currentStreak.dayWord)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1))
    }
    
    private var difficultyPicker: some View {
        HStack(spacing: 6) {
            ForEach(GameDifficulty.allCases) { diff in
                Button {
                    withAnimation { selectedDifficulty = diff }
                } label: {
                    Text(diff.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedDifficulty == diff ? .black : AppColors.textPrimary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedDifficulty == diff ? Color(hex: diff.colorHex) : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(AppColors.textPrimary.opacity(0.05))
        .clipShape(Capsule())
    }
    
    private var solvedProgressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Прогресс за неделю")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
            
            let last7Days = (0..<7).map { i in
                Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            }.reversed()
            
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(last7Days, id: \.self) { day in
                    let dayRecords = records.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                    let count = dayRecords.reduce(0) { $0 + $1.solvedCount }
                    
                    VStack(spacing: 6) {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(count > 0 ? Color(hex: "43e97b") : AppColors.textPrimary.opacity(0.3))
                        
                        // Rounded Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(count > 0 ? LinearGradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [AppColors.textPrimary.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .frame(height: CGFloat(max(4, min(count * 8, 80))))
                        
                        Text(day.weekdayLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(AppColors.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1))
    }
    
    private var expressionWorkspace: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Ваше выражение:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                Spacer()
                if !evaluationResult.isEmpty {
                    Text(evaluationResult)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(evaluationResult.contains("24") ? Color(hex: "43e97b") : AppColors.textPrimary.opacity(0.6))
                }
            }
            .padding(.horizontal, 4)
            
            // Formula display panel
            HStack {
                if exprTokens.isEmpty {
                    Text("Нажимайте числа и знаки ниже...")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.25))
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(exprTokens) { token in
                                Text(token.value)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(token.cardIndex != nil ? Color(hex: "4facfe") : AppColors.textPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(token.cardIndex != nil ? Color(hex: "4facfe").opacity(0.1) : AppColors.textPrimary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .frame(height: 64)
            .background(AppColors.textPrimary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.textPrimary.opacity(0.08), lineWidth: 1))
            
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "fa709a"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
    
    private var gameKeyboard: some View {
        VStack(spacing: 12) {
            // Row 1: Main operators
            HStack(spacing: 12) {
                ForEach(["+", "-", "*", "/"], id: \.self) { op in
                    Button {
                        appendOperator(op)
                    } label: {
                        Text(op == "*" ? "×" : (op == "/" ? "÷" : op))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.textPrimary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Row 2: Brackets, Undo, Clear
            HStack(spacing: 12) {
                ForEach(["(", ")"], id: \.self) { br in
                    Button {
                        appendOperator(br)
                    } label: {
                        Text(br)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColors.textPrimary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                // Undo
                Button {
                    undoLastToken()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "f5d061").opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Clear
                Button {
                    clearExpression()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "fa709a").opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Row 3: Submit & Next
            HStack(spacing: 12) {
                // Next / Skip Problem
                Button {
                    loadNewProblem()
                } label: {
                    Text("Другие числа")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColors.textPrimary.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.textPrimary.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Submit
                Button {
                    submitExpression()
                } label: {
                    Text("Готово")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(exprTokens.isEmpty)
                .opacity(exprTokens.isEmpty ? 0.5 : 1.0)
            }
        }
    }
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "43e97b"), Color(hex: "38f9d7")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 90, height: 90)
                        .shadow(color: Color(hex: "43e97b").opacity(0.4), radius: 10, x: 0, y: 5)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.black)
                }
                
                VStack(spacing: 8) {
                    Text("Поздравляем!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(successMessage)
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button {
                    withAnimation {
                        showSuccessOverlay = false
                        loadNewProblem()
                    }
                } label: {
                    Text("Следующая задача")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(hex: "43e97b"))
                        .clipShape(Capsule())
                }
            }
            .padding(30)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(AppColors.textPrimary.opacity(0.1), lineWidth: 1))
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Format Extensions

extension Date {
    var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: self).capitalized
    }
}

extension Int {
    var dayWord: String {
        let lastDigit = self % 10
        let lastTwoDigits = self % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 19 {
            return "дней"
        }
        
        switch lastDigit {
        case 1:
            return "день"
        case 2, 3, 4:
            return "дня"
        default:
            return "дней"
        }
    }
}

#Preview {
    Game24View()
        .modelContainer(for: [GameRecord.self], inMemory: true)
}

