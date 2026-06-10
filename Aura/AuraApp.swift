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
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Local SwiftData container (free account compatible)

private let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        TaskItem.self,
        Transaction.self,
        ChatMessage.self,
        ChatSession.self,
        GameRecord.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    return try! ModelContainer(for: schema, configurations: [config])
}()

