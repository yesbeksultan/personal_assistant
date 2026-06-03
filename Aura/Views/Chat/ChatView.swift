import SwiftUI
import SwiftData

// MARK: - Chat List

struct ChatView: View {
    @Query(sort: \ChatSession.createdAt, order: .reverse) private var sessions: [ChatSession]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSession: ChatSession? = nil
    @State private var newSession: ChatSession? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyChatState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Friday AI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNewSession) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                    }
                }
            }
            .navigationDestination(item: $selectedSession) { session in
                ChatDetailView(session: session, isNew: false)
            }
            .navigationDestination(item: $newSession) { session in
                ChatDetailView(session: session, isNew: true)
            }
        }
    }

    // MARK: - Empty State

    private var emptyChatState: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "message")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(AppColors.textPrimary.opacity(0.18))

            VStack(spacing: 8) {
                Text("Привет! Я Friday")
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Начни новый чат и я помогу\nс задачами, финансами и не только")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            Button(action: createNewSession) {
                Text("Новый чат")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .overlay(
                        Capsule()
                            .stroke(AppColors.textPrimary.opacity(0.18), lineWidth: 1)
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Session List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sessions) { session in
                    SessionCard(session: session) {
                        newSession = nil
                        selectedSession = session
                    } onDelete: {
                        withAnimation(.spring(response: 0.4)) {
                            modelContext.delete(session)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 80)
        }
        .animation(.easeInOut(duration: 0.3), value: sessions.count)
    }

    private func createNewSession() {
        let s = ChatSession(title: "Новый чат")
        modelContext.insert(s)
        newSession = s
    }
}

// MARK: - Session Card

private struct SessionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.textPrimary.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.textPrimary.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

private struct SessionCard: View {
    let session: ChatSession
    let onTap: () -> Void
    let onDelete: () -> Void

    private var messageCount: Int { session.messages?.count ?? 0 }

    private var sessionInitial: String {
        String(session.title.prefix(1)).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Аватар чата
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(AppColors.textPrimary.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Text(sessionInitial)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if messageCount > 0 {
                            Text("\(messageCount) сообщ.")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        } else {
                            Text("Нет сообщений")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                        }
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                        Text(session.createdAt.chatFormatted)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.2))
            }
        }
        .buttonStyle(SessionCardButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить чат", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Chat Detail

struct ChatDetailView: View {
    let session: ChatSession
    let isNew: Bool
    @Query private var messages: [ChatMessage]
    @Query private var tasks: [TaskItem]
    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var calendarService = CalendarService.shared
    @FocusState private var isInputFocused: Bool
    @State private var showRenameAlert = false
    @State private var newChatTitle = ""
    @State private var showFunctionPicker = false

    init(session: ChatSession, isNew: Bool = false) {
        self.session = session
        self.isNew = isNew
        let sessionID = session.id
        self._messages = Query(
            filter: #Predicate<ChatMessage> { $0.session?.id == sessionID },
            sort: \.timestamp
        )
    }

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if messages.isEmpty {
                    welcomeView
                } else {
                    messagesList
                }
                inputBar
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newChatTitle = session.title
                        showRenameAlert = true
                    } label: { Label("Переименовать", systemImage: "pencil") }

                    Button {
                        Task {
                            await viewModel.generateDailySummary(
                                context: modelContext, tasks: tasks, transactions: transactions
                            )
                        }
                    } label: { Label("Вечерняя сводка", systemImage: "moon.stars") }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.clearHistory(context: modelContext, messages: messages)
                    } label: {
                        Label("Очистить сообщения", systemImage: "eraser")
                    }

                    Button(role: .destructive) {
                        modelContext.delete(session)
                        dismiss()
                    } label: {
                        Label("Удалить чат", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                }
            }
        }
        .onAppear {
            viewModel.session = session
            newChatTitle = session.title
        }
        .onDisappear {
            // Если чат новый и пустой — удаляем без сохранения
            if isNew && messages.isEmpty {
                modelContext.delete(session)
            }
        }
        .alert("Переименовать чат", isPresented: $showRenameAlert) {
            TextField("Название", text: $newChatTitle)
            Button("Отмена", role: .cancel) { }
            Button("Сохранить") {
                let t = newChatTitle.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { session.title = t }
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 30)

                // AI Avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.2))

                VStack(spacing: 8) {
                    Text("Привет! Я Friday")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Твой персональный AI-ассистент.\nСпроси что угодно!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                // Quick actions
                VStack(spacing: 10) {
                    ForEach(quickActions, id: \.self) { action in
                        QuickActionButton(text: action) {
                            viewModel.messageText = action
                            Task {
                                await viewModel.sendMessage(
                                    context: modelContext,
                                    messages: messages,
                                    tasks: tasks,
                                    transactions: transactions,
                                    events: calendarService.upcomingEvents
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
            .padding(.bottom, 100)
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
    }

    private var quickActions: [String] {
        [
            "Какие задачи мне стоит сделать сегодня?",
            "Дай совет по экономии денег",
            "Подведи итоги моего дня",
            "Помоги составить план на завтра"
        ]
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages, id: \.id) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: message.isFromUser ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isLoading {
                        TypingIndicator()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture { isInputFocused = false }
            .onAppear {
                if let last = messages.last {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.4)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.4)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1)

            // Active function chip
            if let fn = viewModel.activeFunction {
                activeFunctionChip(fn)
            }

            // Period picker row (when finance active)
            if viewModel.activeFunction == .finance {
                periodPickerRow
            }

            HStack(spacing: 8) {
                // Function picker button
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        if viewModel.activeFunction != nil {
                            viewModel.clearActiveFunction()
                            showFunctionPicker = false
                        } else {
                            showFunctionPicker.toggle()
                            isInputFocused = false
                        }
                    }
                } label: {
                    let isActive = viewModel.activeFunction != nil
                    ZStack {
                        Circle()
                            .fill(isActive
                                ? AppColors.textPrimary.opacity(0.18)
                                : AppColors.textPrimary.opacity(0.07))
                            .frame(width: 36, height: 36)
                        Image(systemName: isActive ? "xmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isActive
                                ? AppColors.textPrimary.opacity(0.8)
                                : AppColors.textPrimary.opacity(0.45))
                            .rotationEffect(.degrees(showFunctionPicker && !isActive ? 45 : 0))
                    }
                }
                .animation(.spring(response: 0.3), value: viewModel.activeFunction != nil)

                TextField("Спроси Friday...", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1...5)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(AppColors.textPrimary.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppColors.textPrimary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .focused($isInputFocused)

                // Send button
                Button {
                    Task {
                        await viewModel.sendMessage(
                            context: modelContext,
                            messages: messages,
                            tasks: tasks,
                            transactions: transactions,
                            events: calendarService.upcomingEvents
                        )
                    }
                    isInputFocused = false
                } label: {
                    let active = !viewModel.messageText.isEmpty && !viewModel.isLoading
                    Circle()
                        .fill(active ? AppColors.textPrimary.opacity(0.14) : AppColors.textPrimary.opacity(0.06))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(active ? AppColors.textPrimary.opacity(0.8) : AppColors.textPrimary.opacity(0.25))
                        )
                }
                .disabled(viewModel.messageText.isEmpty || viewModel.isLoading)
                .animation(.spring(response: 0.3), value: viewModel.messageText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.appBackground)

            // Function picker popup
            if showFunctionPicker && viewModel.activeFunction == nil {
                functionPickerPopup
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Active Function Chip

    private func activeFunctionChip(_ fn: ChatFunction) -> some View {
        HStack(spacing: 6) {
            Text(fn.emoji)
                .font(.system(size: 13))
            Text(fn.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.75))
            if let period = viewModel.selectedPeriod {
                Text("· \(period.rawValue)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textPrimary.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.textPrimary.opacity(0.07))
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Period Picker Row

    private var periodPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FinancePeriod.allCases, id: \.self) { period in
                    let isSelected = viewModel.selectedPeriod == period
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectedPeriod = isSelected ? nil : period
                        }
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected
                                ? AppColors.textPrimary
                                : AppColors.textPrimary.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected
                                        ? AppColors.textPrimary.opacity(0.14)
                                        : AppColors.textPrimary.opacity(0.06))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected
                                        ? AppColors.textPrimary.opacity(0.25)
                                        : Color.clear, lineWidth: 1)
                            )
                    }
                    .animation(.spring(response: 0.25), value: isSelected)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Function Picker Popup

    private var functionPickerPopup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Контекст для ассистента")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(ChatFunction.allCases) { fn in
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        viewModel.activeFunction = fn
                        showFunctionPicker = false
                        // default to week
                        viewModel.selectedPeriod = .week
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(AppColors.textPrimary.opacity(0.08))
                                .frame(width: 34, height: 34)
                            Image(systemName: fn.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fn.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(fn.description)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
            }

            Spacer(minLength: 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.appBackground)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.textPrimary.opacity(configuration.isPressed ? 0.1 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

private struct QuickActionButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.3))
            }
        }
        .buttonStyle(QuickActionButtonStyle())
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.textPrimary.opacity(0.1))
                .clipShape(BubbleShape(isFromUser: true))
                .textSelection(.enabled)

            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
        }
    }

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar dot
            Circle()
                .fill(AppColors.textPrimary.opacity(0.07))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("F")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(parseMarkdown(message.content))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        AppColors.textPrimary.opacity(0.08)
                    )
                    .clipShape(BubbleShape(isFromUser: false))
                    .textSelection(.enabled)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Скопировать", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.3))
            }
        }
    }

    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return AttributedString(text)
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(AppColors.textPrimary.opacity(0.07))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("F")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                )

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppColors.textPrimary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.textPrimary.opacity(0.08))
            .clipShape(BubbleShape(isFromUser: false))
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

// MARK: - Bubble Shape
// Аккуратные скруглённые углы: один угол «острее» — имитация хвостика мессенджера

private struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18   // основной радиус
        let rt: CGFloat = 4   // радиус «хвостикового» угла

        // Углы: topLeft, topRight, bottomRight, bottomLeft
        let tl: CGFloat = isFromUser ? r  : rt
        let tr: CGFloat = isFromUser ? rt : r
        let br: CGFloat = isFromUser ? r  : r
        let bl: CGFloat = isFromUser ? r  : r

        return Path { p in
            p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                     radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                     radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                     radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
            p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                     radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var chatFormatted: String {
        if Calendar.current.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        } else if Calendar.current.isDateInYesterday(self) {
            return "Вчера"
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }
}
