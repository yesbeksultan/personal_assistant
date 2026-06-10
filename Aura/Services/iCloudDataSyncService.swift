import Foundation
import SwiftData
import Observation
import UIKit

// MARK: - Codable DTOs (Data Transfer Objects)

struct TaskItemDTO: Codable {
    var id: UUID
    var title: String
    var taskDescription: String
    var category: String
    var priority: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?

    init(from task: TaskItem) {
        id = task.id
        title = task.title
        taskDescription = task.taskDescription
        category = task.category
        priority = task.priority.rawValue
        isCompleted = task.isCompleted
        createdAt = task.createdAt
        dueDate = task.dueDate
    }

    func apply(to task: TaskItem) {
        task.title = title
        task.taskDescription = taskDescription
        task.category = category
        task.priority = TaskPriority(rawValue: priority) ?? .medium
        task.isCompleted = isCompleted
        task.dueDate = dueDate
    }
}

struct TransactionDTO: Codable {
    var id: UUID
    var title: String
    var amount: Double
    var type: String
    var category: String
    var date: Date
    var note: String

    init(from t: Transaction) {
        id = t.id
        title = t.title
        amount = t.amount
        type = t.type.rawValue
        category = t.category
        date = t.date
        note = t.note
    }
}

struct SyncPayload: Codable {
    var exportedAt: Date
    var deviceName: String
    var tasks: [TaskItemDTO]
    var transactions: [TransactionDTO]
}

// MARK: - iCloudDataSyncService

@Observable
final class iCloudDataSyncService {
    static let shared = iCloudDataSyncService()

    // File names in iCloud Documents
    private let syncFileName = "friday_sync.json"
    private let iCloud = iCloudService.shared

    var isSyncing = false
    var lastSyncError: String? = nil

    private init() {
        // Observe iCloud file changes (when another device uploads new data)
        setupMetadataQuery()
    }

    // MARK: - Public API

    /// Call on app launch — imports latest data from iCloud if newer
    func syncOnLaunch() {
        guard iCloud.isAvailable else { return }
        DispatchQueue.global(qos: .utility).async {
            self.downloadAndImport()
        }
    }

    /// Export current data to iCloud (call after any data change)
    func exportToiCloud(tasks: [TaskItem], transactions: [Transaction]) {
        guard iCloud.isAvailable else { return }
        DispatchQueue.global(qos: .utility).async {
            self.performExport(tasks: tasks, transactions: transactions)
        }
    }

    // MARK: - Export

    private func performExport(tasks: [TaskItem], transactions: [Transaction]) {
        let payload = SyncPayload(
            exportedAt: Date(),
            deviceName: UIDevice.current.name,
            tasks: tasks.map { TaskItemDTO(from: $0) },
            transactions: transactions.map { TransactionDTO(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(payload) else { return }

        let url = syncFileURL()
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            do {
                try data.write(to: writeURL, options: .atomic)
                DispatchQueue.main.async {
                    self.isSyncing = false
                    iCloudService.shared.markSynced()
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastSyncError = error.localizedDescription
                    self.isSyncing = false
                }
            }
        }
    }

    // MARK: - Import

    private func downloadAndImport() {
        let url = syncFileURL()

        // Trigger iCloud download if needed
        iCloud.startDownloadIfNeeded(at: url)

        // Wait a bit for download to start, then read
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
            self.readAndPost(from: url)
        }
    }

    private func readAndPost(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let coordinator = NSFileCoordinator()
        var error: NSError?
        var payload: SyncPayload?

        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            payload = try? decoder.decode(SyncPayload.self, from: data)
        }

        if let payload {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .iCloudDataDidDownload,
                    object: payload
                )
            }
        }
    }

    // MARK: - Metadata Query (watch for remote file changes)

    private var metadataQuery: NSMetadataQuery?

    private func setupMetadataQuery() {
        guard iCloud.isAvailable else { return }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, syncFileName)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.downloadAndImport()
        }

        query.start()
        metadataQuery = query
    }

    // MARK: - Helpers

    private func syncFileURL() -> URL {
        iCloud.containerURL().appendingPathComponent(syncFileName)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let iCloudDataDidDownload = Notification.Name("iCloudDataDidDownload")
}

