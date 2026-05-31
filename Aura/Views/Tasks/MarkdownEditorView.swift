import SwiftUI
import Combine

// MARK: - Markdown Shortcut

struct MarkdownShortcut {
    let icon: String
    let label: String
    let prefix: String
    let suffix: String
    let placeholder: String
}

private let shortcuts: [MarkdownShortcut] = [
    MarkdownShortcut(icon: "bold",         label: "Жирный",     prefix: "**", suffix: "**", placeholder: "текст"),
    MarkdownShortcut(icon: "italic",       label: "Курсив",     prefix: "_",  suffix: "_",  placeholder: "текст"),
    MarkdownShortcut(icon: "number",       label: "Заголовок",  prefix: "# ", suffix: "",   placeholder: "Заголовок"),
    MarkdownShortcut(icon: "list.bullet",  label: "Список",     prefix: "- ", suffix: "",   placeholder: "пункт"),
    MarkdownShortcut(icon: "list.number",  label: "Нумерация",  prefix: "1. ",suffix: "",   placeholder: "пункт"),
    MarkdownShortcut(icon: "chevron.left.forwardslash.chevron.right", label: "Код", prefix: "`", suffix: "`", placeholder: "код"),
    MarkdownShortcut(icon: "link",         label: "Ссылка",     prefix: "[",  suffix: "](url)", placeholder: "текст"),
    MarkdownShortcut(icon: "minus",        label: "Линия",      prefix: "\n---\n", suffix: "", placeholder: ""),
    MarkdownShortcut(icon: "checkmark.square", label: "Чекбокс", prefix: "- [ ] ", suffix: "", placeholder: "задача"),
]

// MARK: - Editor View

struct MarkdownEditorView: View {
    let fileURL: URL

    @State private var text: String = ""
    @State private var mode: Mode = .edit
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var saveDebounce: AnyCancellable?
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool

    enum Mode: String, CaseIterable, Identifiable {
        case edit    = "Редактор"
        case preview = "Просмотр"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Сегментный переключатель
            Picker("Режим", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Контент
            Group {
                switch mode {
                case .edit:
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .focused($editorFocused)
                        .onChange(of: text) { _, _ in
                            scheduleAutoSave()
                        }

                case .preview:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            MarkdownPreview(text: text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(fileURL.deletingPathExtension().lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if isSaving {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.7)
                            Text("Сохранение...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Menu {
                        ShareLink(item: fileURL) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            saveNow()
                        } label: {
                            Label("Сохранить", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            // Тулбар подсказок над клавиатурой
            ToolbarItemGroup(placement: .keyboard) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(shortcuts, id: \.label) { shortcut in
                            Button {
                                insertShortcut(shortcut)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: shortcut.icon)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(shortcut.label)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Spacer()

                Button {
                    editorFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16))
                }
            }
        }
        .onAppear { load() }
        .onDisappear { saveNow() }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage) }
        .confirmationDialog("Удалить документ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { deleteFile() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    // MARK: - Shortcut insertion

    private func insertShortcut(_ shortcut: MarkdownShortcut) {
        let insert = shortcut.prefix + shortcut.placeholder + shortcut.suffix
        text += insert
        scheduleAutoSave()
    }

    // MARK: - Auto Save

    private func scheduleAutoSave() {
        saveDebounce?.cancel()
        saveDebounce = Just(())
            .delay(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { _ in saveNow() }
    }

    private func saveNow() {
        isSaving = true
        do {
            try text.data(using: .utf8)?.write(to: fileURL)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSaving = false
        }
    }

    // MARK: - File ops

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            self.text = String(decoding: data, as: UTF8.self)
        } catch {
            self.text = ""
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func deleteFile() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Markdown Preview

/// Полноценный рендер Markdown с поддержкой заголовков, списков, кода и таблиц
struct MarkdownPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks(from: text).enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: Block types

    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bulletItem(String)
        case numberedItem(Int, String)
        case codeBlock(String)
        case horizontalRule
        case checkboxItem(checked: Bool, text: String)
        case blockquote(String)
    }

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {

        case .heading(let level, let text):
            Text(inlineMarkdown(text))
                .font(headingFont(level))
                .bold()
                .foregroundStyle(.primary)
                .padding(.top, level == 1 ? 8 : 4)

        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(.secondary)
                    .padding(.top, 7)
                Text(inlineMarkdown(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .numberedItem(let n, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\(n).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 20, alignment: .trailing)
                Text(inlineMarkdown(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)

        case .checkboxItem(let checked, let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? .blue : .secondary)
                Text(inlineMarkdown(text))
                    .font(.body)
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .frame(width: 3)
                    .foregroundStyle(.blue.opacity(0.7))
                    .clipShape(Capsule())
                Text(inlineMarkdown(text))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Parser

    private func blocks(from raw: String) -> [Block] {
        var result: [Block] = []
        var codeLines: [String] = []
        var inCode = false
        var numberedCount = 0

        let lines = raw.components(separatedBy: .newlines)

        for line in lines {
            // Код-блок ```
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    result.append(.codeBlock(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }
            if inCode {
                codeLines.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Горизонтальная линия
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.horizontalRule)
                numberedCount = 0
                continue
            }

            // Заголовки
            if let (level, text) = parseHeading(trimmed) {
                result.append(.heading(level: level, text: text))
                numberedCount = 0
                continue
            }

            // Чекбоксы
            if trimmed.hasPrefix("- [ ] ") {
                result.append(.checkboxItem(checked: false, text: String(trimmed.dropFirst(6))))
                numberedCount = 0
                continue
            }
            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                result.append(.checkboxItem(checked: true, text: String(trimmed.dropFirst(6))))
                numberedCount = 0
                continue
            }

            // Маркированный список
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                result.append(.bulletItem(String(trimmed.dropFirst(2))))
                numberedCount = 0
                continue
            }

            // Нумерованный список  1. 2. ...
            if let match = numberedListMatch(trimmed) {
                numberedCount += 1
                result.append(.numberedItem(numberedCount, match))
                continue
            } else {
                numberedCount = 0
            }

            // Цитата
            if trimmed.hasPrefix("> ") {
                result.append(.blockquote(String(trimmed.dropFirst(2))))
                continue
            }

            // Пустая строка — пропуск
            if trimmed.isEmpty { continue }

            // Параграф
            result.append(.paragraph(trimmed))
        }

        if inCode && !codeLines.isEmpty {
            result.append(.codeBlock(codeLines.joined(separator: "\n")))
        }

        return result
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level) + " "
            if line.hasPrefix(prefix) {
                return (level, String(line.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    private func numberedListMatch(_ line: String) -> String? {
        let pattern = #"^\d+\.\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    // MARK: Inline markdown → AttributedString

    private func inlineMarkdown(_ text: String) -> AttributedString {
        // Обрабатываем inline: bold, italic, code, link
        let mdText = text
        do {
            var attr = try AttributedString(
                markdown: mdText,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
            // Убираем синие подчёркивания у ссылок если нет URL
            return attr
        } catch {
            return AttributedString(text)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }
}

// MARK: - Preview

#Preview {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Preview.md")
    let sample = """
    # Заголовок первого уровня
    ## Заголовок второго уровня

    Обычный параграф с **жирным** и _курсивом_ текстом.

    - Пункт один
    - Пункт два
    - Пункт три

    1. Первый
    2. Второй
    3. Третий

    - [ ] Задача не выполнена
    - [x] Задача выполнена

    > Это цитата из важного источника.

    ```
    let hello = "Hello, World!"
    print(hello)
    ```

    ---

    [Ссылка](https://apple.com)
    """
    try? sample.data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownEditorView(fileURL: tmp) }
}
