import SwiftUI
import Combine

// MARK: - Note Editor

struct NoteEditorView: View {
    let fileURL: URL
    var onDelete: (() -> Void)? = nil

    @State private var text: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var saveDebounce: AnyCancellable?
    @State private var showDeleteConfirm = false
    @State private var wordCount = 0

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .focused($isFocused)
            .onChange(of: text) { _, newVal in
                scheduleAutoSave()
                updateWordCount(newVal)
            }
            .navigationTitle(fileURL.deletingPathExtension().lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
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
                                Label("Удалить заметку", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                // Status bar with word count
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text("\(wordCount) сл.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(modifiedDate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Keyboard dismiss button
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        isFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
            }
            .onAppear {
                load()
                isFocused = text.isEmpty
            }
            .onDisappear { saveNow() }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage) }
            .confirmationDialog("Удалить заметку?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { deleteNote() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить.")
            }
    }

    // MARK: - Helpers

    private var modifiedDate: String {
        let date = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        return "Изменено " + date.formatted(.dateTime.day().month().hour().minute())
    }

    private func updateWordCount(_ s: String) {
        let words = s.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.count
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

    // MARK: - File Ops

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            self.text = String(decoding: data, as: UTF8.self)
            updateWordCount(self.text)
        } catch {
            self.text = ""
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func deleteNote() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            onDelete?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("Test Note.txt")
    try? "Это тестовая заметка.\nЗдесь можно писать всё что угодно.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { NoteEditorView(fileURL: tmp) }
}
