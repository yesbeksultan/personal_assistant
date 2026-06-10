import Foundation
import SwiftUI
import Combine

// MARK: - iCloud Sync Status

enum iCloudStatus {
    case available
    case noAccount
    case restricted
    case unknown

    var title: String {
        switch self {
        case .available:   return "iCloud подключён"
        case .noAccount:   return "Войдите в iCloud"
        case .restricted:  return "iCloud ограничен"
        case .unknown:     return "Проверка..."
        }
    }

    var icon: String {
        switch self {
        case .available:   return "icloud.fill"
        case .noAccount:   return "icloud.slash.fill"
        case .restricted:  return "icloud.slash.fill"
        case .unknown:     return "icloud"
        }
    }

    var color: Color {
        switch self {
        case .available:  return Color(hex: "43e97b")
        case .noAccount:  return Color(hex: "fa709a")
        case .restricted: return Color(hex: "fa709a")
        case .unknown:    return Color(hex: "4facfe")
        }
    }
}

// MARK: - iCloudService

@Observable
final class iCloudService {
    static let shared = iCloudService()

    // MARK: State

    var status: iCloudStatus = .unknown
    var lastSyncDate: Date? {
        get {
            let ts = NSUbiquitousKeyValueStore.default.double(forKey: "lastSyncTimestamp")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
    }

    // MARK: iCloud Documents container ID
    // Set this to your actual iCloud container ID (matches entitlements)
    private let containerID = "iCloud.com.beksultan.friday"

    // MARK: Init

    private init() {
        checkStatus()
        setupKVStoreObserver()
    }

    // MARK: Status

    func checkStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let token = FileManager.default.ubiquityIdentityToken
            DispatchQueue.main.async {
                self?.status = token != nil ? .available : .noAccount
            }
        }
    }

    var isAvailable: Bool { status == .available }

    // MARK: - iCloud Documents URL

    /// Returns the iCloud ubiquity container URL for documents.
    /// Falls back to local Documents directory if iCloud is unavailable.
    func containerURL(subpath: String? = nil) -> URL {
        if let ubiquity = FileManager.default.url(
            forUbiquityContainerIdentifier: containerID
        ) {
            var base = ubiquity.appendingPathComponent("Documents", isDirectory: true)
            if let sub = subpath {
                base = base.appendingPathComponent(sub, isDirectory: true)
            }
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base
        }

        // Fallback — local Documents
        let local = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let sub = subpath {
            let dir = local.appendingPathComponent(sub, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        return local
    }

    // MARK: - KV Store

    private func setupKVStoreObserver() {
        NSUbiquitousKeyValueStore.default.synchronize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }

    @objc private func kvStoreDidChange(_ notification: Notification) {
        // Broadcast so subscribers (TabPreferences, FinanceCategoryStore) can refresh
        NotificationCenter.default.post(
            name: .iCloudKVStoreDidChange,
            object: notification.userInfo
        )
    }

    // MARK: - Mark sync time

    func markSynced() {
        NSUbiquitousKeyValueStore.default.set(
            Date().timeIntervalSince1970,
            forKey: "lastSyncTimestamp"
        )
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Download iCloud file if needed

    func startDownloadIfNeeded(at url: URL) {
        let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        let downloadStatus = values?.ubiquitousItemDownloadingStatus

        if downloadStatus != .current {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let iCloudKVStoreDidChange = Notification.Name("iCloudKVStoreDidChange")
}
