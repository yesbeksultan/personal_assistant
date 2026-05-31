import SwiftUI
import UniformTypeIdentifiers

// MARK: - Helpers

/// Читает первую непустую строку из markdown-текста файла
private func firstParagraph(of url: URL) -> String? {
    guard let data = try? Data(contentsOf: url),
          let raw = String(data: data, encoding: .utf8) else { return nil }

    for line in raw.components(separatedBy: .newlines) {
        // Убираем markdown-символы заголовков и пробелы
        let stripped = line
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
        if !stripped.isEmpty {
            return stripped
        }
    }
    return nil
}

// MARK: - View

struct MarkdownListView: View {
    @State private var files: [URL] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Переименование
    @State private var renamingURL: URL? = nil
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(files, id: \.self) { url in
                    NavigationLink(destination: MarkdownEditorView(fileURL: url)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.headline)
                                .lineLimit(1)

                            if let preview = firstParagraph(of: url) {
                                Text(preview)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    // Долгое нажатие → переименование
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
                            deleteFile(url: url)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteFile(url: url)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }

                        Button {
                            renameText = url.deletingPathExtension().lastPathComponent
                            renamingURL = url
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .overlay(alignment: .center) {
                if files.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "Нет документов",
                        systemImage: "doc.text",
                        description: Text("Нажмите + чтобы создать документ")
                    )
                }
            }
            .navigationTitle("Документы")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createNewDocument) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { loadFiles() }
            .onAppear { loadFiles() }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Alert переименования
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
                Text("Введите новое имя файла")
            }
        }
    }

    // MARK: - File System

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func loadFiles() {
        isLoading = true
        defer { isLoading = false }
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory(),
                includingPropertiesForKeys: nil
            )
            self.files = urls
                .filter { $0.pathExtension.lowercased() == "md" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            self.files = []
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func createNewDocument() {
        let base = documentsDirectory().appendingPathComponent("Новый документ")
        var url = base.appendingPathExtension("md")
        var idx = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = documentsDirectory()
                .appendingPathComponent("Новый документ \(idx)")
                .appendingPathExtension("md")
            idx += 1
        }
        do {
            try "# Новый документ\n\nНапишите здесь...".data(using: .utf8)?.write(to: url)
            loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }

    private func deleteFile(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadFiles()
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
            .appendingPathExtension("md")

        guard newURL != url else { return }

        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            loadFiles()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
}

#Preview {
    MarkdownListView()
}
