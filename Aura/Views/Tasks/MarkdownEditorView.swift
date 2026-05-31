import SwiftUI
import Combine

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

    enum Mode: String, CaseIterable, Identifiable {
        case edit = "Редактор"
        case preview = "Просмотр"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Режим", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch mode {
                case .edit:
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal)
                        .onChange(of: text) { _, _ in
                            scheduleAutoSave()
                        }
                case .preview:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(parseMarkdown(text))
                                .foregroundStyle(.primary)
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
                    // Индикатор автосохранения
                    if isSaving {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Сохранение...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Меню действий
                    Menu {
                        ShareLink(item: fileURL) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            saveNow()
                        } label: {
                            Label("Сохранить сейчас", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Удалить документ", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .onAppear { load() }
        .onDisappear { saveNow() }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        .confirmationDialog("Удалить документ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                deleteFile()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    // MARK: - Auto Save

    private func scheduleAutoSave() {
        saveDebounce?.cancel()
        saveDebounce = Just(())
            .delay(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { _ in
                saveNow()
            }
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

    // MARK: - Markdown

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

#Preview {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Preview.md")
    try? "# Превью\n\nТекст превью.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownEditorView(fileURL: tmp) }
}
