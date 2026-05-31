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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TaskItem.self, Transaction.self, ChatMessage.self, ChatSession.self])
    }
}
