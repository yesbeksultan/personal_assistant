//
//  ContentView.swift
//  friday
//
//  Created by Kuralbai Beksultan on 24.05.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: String = "dark"

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Главная", systemImage: "square.grid.2x2")
                }
            
            TasksView()
                .tabItem {
                    Label("Задачи", systemImage: "checkmark.circle")
                }
            
            ChatView()
                .tabItem {
                    Label("Friday AI", systemImage: "sparkles")
                }
            
            FinanceView()
                .tabItem {
                    Label("Финансы", systemImage: "creditcard")
                }
        }
        .preferredColorScheme(appTheme == "dark" ? .dark : .light)
        .tint(Color(hex: "667eea"))
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.appBackground)
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, Transaction.self, ChatMessage.self, ChatSession.self], inMemory: true)
}
