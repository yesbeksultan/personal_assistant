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
    @State private var metadataQuery: NSMetadataQuery?
    private let iCloud = iCloudService.shared

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
            .onAppear {
                startMetadataQuery()
                loadFiles()
            }
            .onDisappear { stopMetadataQuery() }
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
        // iCloud Documents если доступно, иначе локальная папка
        iCloud.containerURL(subpath: "Markdown")
    }

    // MARK: - iCloud Metadata Query

    private func startMetadataQuery() {
        guard iCloud.isAvailable else { return }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { _ in loadFiles() }
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { _ in loadFiles() }
        query.start()
        metadataQuery = query
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
    }

    private func loadFiles() {
        isLoading = true
        defer { isLoading = false }
        let dir = documentsDirectory()
        iCloud.startDownloadIfNeeded(at: dir)
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey]
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
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do {
                try "# Новый документ\n\nНапишите здесь...".data(using: .utf8)?.write(to: writeURL)
                iCloudService.shared.markSynced()
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        if let err = coordError {
            self.errorMessage = err.localizedDescription
            self.showError = true
        }
        loadFiles()
    }

    private func deleteFile(url: URL) {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { deleteURL in
            do {
                try FileManager.default.removeItem(at: deleteURL)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        if let err = coordError {
            self.errorMessage = err.localizedDescription
            self.showError = true
        }
        loadFiles()
    }

    private func rename(url: URL, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(trimmed)
            .appendingPathExtension("md")

        guard newURL != url else { return }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forMoving,
                               writingItemAt: newURL, options: .forReplacing,
                               error: &coordError) { srcURL, dstURL in
            do {
                try FileManager.default.moveItem(at: srcURL, to: dstURL)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        if let err = coordError {
            self.errorMessage = err.localizedDescription
            self.showError = true
        }
        loadFiles()
    }
}

#Preview {
    MarkdownListView()
}
