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
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TaskItem.self, Transaction.self, ChatMessage.self, ChatSession.self])
    }
}
