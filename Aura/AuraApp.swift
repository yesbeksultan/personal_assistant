//
//  fridayApp.swift
//  friday
//
//  Created by Kuralbai Beksultan on 24.05.2026.
//

import SwiftUI
import SwiftData

@main
struct fridayApp: App {
    init() {
        // Register default notification settings
        NotificationDefaults.registerDefaults()

        // Setup notification delegate and request permissions / reschedule
        NotificationService.shared.setupNotificationDelegate()
        NotificationService.shared.requestPermission { granted in
            if granted {
                NotificationService.shared.rescheduleAll()
            }
        }

        // Start iCloud status check & KV store sync
        _ = iCloudService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Auto-sync data from iCloud on launch
                    iCloudDataSyncService.shared.syncOnLaunch()
                }
                .onOpenURL { url in
                    // Handle deep links from Apple Shortcuts / Apple Pay / external triggers
                    DeepLinkParserService.shared.handleURL(url)
                }
        }
        .modelContainer(AppStorageContainer.shared)
    }
}

// MARK: - Local SwiftData container (free account compatible)

enum AppStorageContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            Transaction.self,
            ChatMessage.self,
            ChatSession.self,
            Game24Result.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
}

