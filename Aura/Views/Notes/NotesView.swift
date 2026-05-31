import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notes List View

struct NotesView: View {
    @State private var notes: [URL] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var renamingURL: URL? = nil
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if notes.isEmpty && !isLoading {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Заметки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNote) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .regular))
                    }
                }
            }
            .refreshable { loadNotes() }
            .onAppear { loadNotes() }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Переименовать", isPresented: Binding(
                get: { renamingURL != nil },
                set: { if !$0 { renamingURL = nil } }
            )) {
                TextField("Название", text: $renameText)
                Button("Отмена", role: .cancel) { renamingURL = nil }
                Button("Сохранить") {
                    if let url = renamingURL { rename(url: url, to: renameText) }
                    renamingURL = nil
                }
            } message: {
                Text("Введите новое название заметки")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text("Нет заметок")
                    .font(.title3).fontWeight(.semibold)
                Text("Нажмите   для создания")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: createNote) {
                Text("Создать заметку")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            ForEach(notes, id: \.self) { url in
                NavigationLink(destination: NoteEditorView(fileURL: url, onDelete: {
                    loadNotes()
                })) {
                    NoteRowView(url: url)
                }
                .contextMenu {
                    Button {
                        renameText = url.deletingPathExtension().lastPathComponent
                        renamingURL = url
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }

                    ShareLink(item: url) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        deleteNote(url: url)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteNote(url: url)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }

                    Button {
                        renameText = url.deletingPathExtension().lastPathComponent
                        renamingURL = url
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.easeInOut, value: notes.count)
    }

    // MARK: - File System

    private func notesDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("FridayNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadNotes() {
        isLoading = true
        defer { isLoading = false }
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: notesDirectory(),
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            self.notes = urls
                .filter { $0.pathExtension.lowercased() == "txt" }
                .sorted { lhs, rhs in
                    let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                    return lDate > rDate
                }
        } catch {
            self.notes = []
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func createNote() {
        let base = notesDirectory().appendingPathComponent("Новая заметка")
        var url = base.appendingPathExtension("txt")
        var idx = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = notesDirectory()
                .appendingPathComponent("Новая заметка \(idx)")
                .appendingPathExtension("txt")
            idx += 1
        }
        do {
            try "".data(using: .utf8)?.write(to: url)
            loadNotes()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func deleteNote(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadNotes()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func rename(url: URL, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(trimmed)
            .appendingPathExtension("txt")
        guard newURL != url else { return }
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            loadNotes()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
}

// MARK: - Note Row

private struct NoteRowView: View {
    let url: URL

    private var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    private var preview: String? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modifiedDate: String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Вчера"
        } else {
            return date.formatted(.dateTime.day().month())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(modifiedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let preview {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Пустая заметка")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NotesView()
}
