import SwiftUI
import SwiftData

// MARK: - Message Chunks & High-Performance Parser

enum MessageChunk: Identifiable, Hashable {
    case text(id: String, content: String)
    case code(id: String, language: String?, code: String)
    
    var id: String {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _, _): return id
        }
    }
}

private final class MessageChunkWrapper: NSObject {
    let chunk: MessageChunk
    init(_ chunk: MessageChunk) {
        self.chunk = chunk
    }
}

final class AIMessageParser {
    static let shared = AIMessageParser()
    private let cache = NSCache<NSString, NSArray>()
    
    private init() {
        cache.countLimit = 400
    }
    
    func chunks(from raw: String) -> [MessageChunk] {
        let key = raw as NSString
        if let cached = cache.object(forKey: key) as? [MessageChunkWrapper] {
            return cached.map { $0.chunk }
        }
        
        let parsed = parse(raw)
        let wrapped = parsed.map { MessageChunkWrapper($0) } as NSArray
        cache.setObject(wrapped, forKey: key)
        return parsed
    }
    
    private func parse(_ raw: String) -> [MessageChunk] {
        let parts = raw.components(separatedBy: "```")
        if parts.count == 1 {
            return [.text(id: "0", content: raw)]
        }
        
        var chunks: [MessageChunk] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chunks.append(.text(id: "t_\(index)", content: trimmed))
                }
            } else {
                var lines = part.components(separatedBy: .newlines)
                var lang: String? = nil
                if let first = lines.first?.trimmingCharacters(in: .whitespaces), !first.isEmpty, !first.contains(" ") {
                    lang = first
                    lines.removeFirst()
                }
                let code = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
                chunks.append(.code(id: "c_\(index)", language: lang, code: code))
            }
        }
        return chunks
    }
}

// MARK: - Performance Cache for Parsed Markdown

final class MarkdownCache {
    static let shared = MarkdownCache()
    private let cache = NSCache<NSString, NSAttributedString>()
    
    private init() {
        cache.countLimit = 500
    }
    
    func attributed(from text: String) -> AttributedString {
        let key = text as NSString
        if let cached = cache.object(forKey: key) {
            return AttributedString(cached)
        }
        
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            options.failurePolicy = .returnPartiallyParsedIfPossible
            
            let parsed = try AttributedString(markdown: text, options: options)
            cache.setObject(NSAttributedString(parsed), forKey: key)
            return parsed
        } catch {
            let fallback = AttributedString(text)
            cache.setObject(NSAttributedString(fallback), forKey: key)
            return fallback
        }
    }
}

// MARK: - Fast Time Formatter

private enum ChatTimeFormatters {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    static func format(_ date: Date) -> String {
        shortTime.string(from: date)
    }
}

// MARK: - Chat Sessions List View

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
                            .font(.system(size: 15, weight: .regular))
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

    // MARK: - Minimalist Empty State

    private var emptyChatState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(hex: "667eea"))
            }

            VStack(spacing: 6) {
                Text("Привет! Я Friday")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Твой персональный AI-ассистент.\nПомогу спланировать день, рассчитать бюджет\nи ответить на любые вопросы.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                    .multilineTextAlignment(.center)
            }

            Button(action: createNewSession) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Начать диалог")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(sessions) { session in
                    SessionCard(session: session) {
                        newSession = nil
                        selectedSession = session
                    } onDelete: {
                        withAnimation(.spring(response: 0.35)) {
                            modelContext.delete(session)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 80)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func createNewSession() {
        let s = ChatSession(title: "Новый чат")
        modelContext.insert(s)
        newSession = s
    }
}

// MARK: - Minimalist Session Card

private struct SessionCard: View, Equatable {
    let session: ChatSession
    let onTap: () -> Void
    let onDelete: () -> Void

    static func == (lhs: SessionCard, rhs: SessionCard) -> Bool {
        lhs.session.id == rhs.session.id &&
        lhs.session.title == rhs.session.title &&
        lhs.session.createdAt == rhs.session.createdAt &&
        (lhs.session.messages?.count ?? 0) == (rhs.session.messages?.count ?? 0)
    }

    private var messageCount: Int { session.messages?.count ?? 0 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "667eea").opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(hex: "667eea").opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if messageCount > 0 {
                            Text("\(messageCount) сообщ.")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.45))
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
                            .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.18))
            }
            .padding(12)
            .background(AppColors.textPrimary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Chat Detail View

struct ChatDetailView: View {
    let session: ChatSession
    let isNew: Bool
    
    @Query private var messages: [ChatMessage]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @State private var calendarService = CalendarService.shared
    @FocusState private var isInputFocused: Bool
    @State private var showRenameAlert = false
    @State private var newChatTitle = ""

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
                messagesScrollView
                inputBar
            }
        }
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
                            await viewModel.generateDailySummary(context: modelContext)
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
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                }
            }
        }
        .onAppear {
            viewModel.session = session
            newChatTitle = session.title
        }
        .onDisappear {
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

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        welcomeSection
                    } else {
                        ForEach(messages, id: \.id) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                                .id("typingIndicator")
                                .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let last = messages.last {
                    DispatchQueue.main.async {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                withAnimation(.easeOut(duration: 0.2)) {
                    if loading {
                        proxy.scrollTo("typingIndicator", anchor: .bottom)
                    } else if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused, let last = messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Minimalist Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(Color(hex: "667eea").opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text("Привет! Я Friday")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Твой персональный AI-ассистент.\nПомогу с задачами, финансами и расписанием.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))
                    .multilineTextAlignment(.center)
            }

            // Suggestions Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                suggestionCard(
                    icon: "calendar",
                    color: "4facfe",
                    title: "План на день",
                    prompt: "Какие задачи и события у меня запланированы на сегодня?"
                )

                suggestionCard(
                    icon: "chart.bar.fill",
                    color: "43e97b",
                    title: "Анализ финансов",
                    prompt: "Проанализируй мои расходы за последнее время и дай полезные советы."
                )

                suggestionCard(
                    icon: "checkmark.circle.fill",
                    color: "667eea",
                    title: "Приоритеты дел",
                    prompt: "Помоги расставить приоритеты по моим открытым задачам."
                )

                suggestionCard(
                    icon: "moon.stars.fill",
                    color: "fa709a",
                    title: "Итоги дня",
                    prompt: "Подведи краткие итоги дня по моим задачам и тратам."
                )
            }
            .padding(.top, 4)

            Spacer(minLength: 24)
        }
        .padding(.vertical, 8)
    }

    private func suggestionCard(icon: String, color: String, title: String, prompt: String) -> some View {
        Button {
            viewModel.messageText = prompt
            sendMessage()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 22, height: 22)
                    .background(Color(hex: color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.25))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColors.textPrimary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Minimalist Input Bar

    private var inputBar: some View {
        VStack(spacing: 4) {
            // Active context chip
            if let fn = viewModel.activeFunction {
                HStack(spacing: 6) {
                    Text(fn.emoji)
                        .font(.system(size: 11))
                    Text(fn.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if let p = viewModel.selectedPeriod {
                        Text("(\(p.rawValue.lowercased()))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.clearActiveFunction()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "667eea").opacity(0.12))
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Minimalist Context (+) Menu Button
                Menu {
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.activeFunction = .calendar
                        }
                    } label: {
                        Label("Календарь (события и праздники)", systemImage: "calendar")
                    }

                    Menu("Финансы (баланс и транзакции)") {
                        ForEach(FinancePeriod.allCases, id: \.self) { period in
                            Button("За \(period.rawValue.lowercased())") {
                                withAnimation(.spring(response: 0.25)) {
                                    viewModel.activeFunction = .finance
                                    viewModel.selectedPeriod = period
                                }
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.activeFunction != nil ? Color(hex: "667eea").opacity(0.18) : AppColors.textPrimary.opacity(0.06))
                            .frame(width: 32, height: 32)
                        Image(systemName: viewModel.activeFunction != nil ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(viewModel.activeFunction != nil ? Color(hex: "667eea") : AppColors.textPrimary.opacity(0.6))
                    }
                }

                // Text Input Field
                TextField("Спроси Friday...", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1...5)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppColors.textPrimary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.textPrimary.opacity(0.07), lineWidth: 1)
                    )
                    .focused($isInputFocused)

                // Send or Loading Button
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .frame(width: 32, height: 32)
                } else {
                    let hasText = !viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button {
                        sendMessage()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    hasText
                                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(AppColors.textPrimary.opacity(0.05))
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(hasText ? Color.white : AppColors.textPrimary.opacity(0.25))
                        }
                    }
                    .disabled(!hasText)
                    .animation(.spring(response: 0.25), value: hasText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.appBackground)
        }
    }

    private func sendMessage() {
        let text = viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let events = calendarService.upcomingEvents
        Task {
            await viewModel.sendMessage(
                context: modelContext,
                messages: messages,
                events: events
            )
        }
        isInputFocused = false
    }
}

// MARK: - Chat Message Row (Equatable Router)

struct ChatMessageRow: View, Equatable {
    let message: ChatMessage

    static func == (lhs: ChatMessageRow, rhs: ChatMessageRow) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.content == rhs.message.content &&
        lhs.message.isFromUser == rhs.message.isFromUser &&
        lhs.message.timestamp == rhs.message.timestamp
    }

    var body: some View {
        if message.isFromUser {
            UserMessageBubble(message: message)
        } else {
            AIMessageBubble(message: message)
        }
    }
}

// MARK: - Redesigned User Message Bubble

struct UserMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 44)

            VStack(alignment: .trailing, spacing: 3) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 4,
                            topTrailingRadius: 16,
                            style: .continuous
                        )
                    )
                    .textSelection(.enabled)

                Text(ChatTimeFormatters.format(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.3))
                    .padding(.trailing, 2)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Скопировать", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Minimalist AI Message Bubble

struct AIMessageBubble: View {
    let message: ChatMessage
    @State private var copied = false

    private var chunks: [MessageChunk] {
        AIMessageParser.shared.chunks(from: message.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Minimalist AI Header
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 17, height: 17)
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Friday")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(ChatTimeFormatters.format(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.3))

                Spacer()

                Button {
                    UIPasteboard.general.string = message.content
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(copied ? Color(hex: "43e97b") : AppColors.textPrimary.opacity(0.35))
                        .padding(3)
                }
                .buttonStyle(.plain)
            }

            // Structured Content Card (Single Text View for fluid typography)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chunks) { chunk in
                    switch chunk {
                    case .text(_, let text):
                        Text(MarkdownCache.shared.attributed(from: text))
                            .font(.subheadline)
                            .lineSpacing(3)
                            .foregroundStyle(AppColors.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                    case .code(_, let language, let code):
                        AICodeBlockView(language: language, code: code)
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(AppColors.textPrimary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 24)
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Скопировать текст", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Minimalist Code Block View

struct AICodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text((language ?? "КОД").uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .semibold))
                        Text(copied ? "Скопировано" : "Копировать")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(copied ? Color(hex: "43e97b") : AppColors.textPrimary.opacity(0.55))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.textPrimary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .background(AppColors.textPrimary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Minimalist Typing Indicator

struct TypingIndicator: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 17, height: 17)
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(hex: "667eea"))
                            .frame(width: 4.5, height: 4.5)
                            .scaleEffect(phase == Double(index) ? 1.25 : 0.75)
                            .opacity(phase == Double(index) ? 1.0 : 0.4)
                    }
                }

                Text("Friday думает...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.45))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(AppColors.textPrimary.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.textPrimary.opacity(0.05), lineWidth: 1)
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var chatFormatted: String {
        if Calendar.current.isDateInToday(self) {
            return ChatTimeFormatters.format(self)
        } else if Calendar.current.isDateInYesterday(self) {
            return "Вчера"
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }
}
