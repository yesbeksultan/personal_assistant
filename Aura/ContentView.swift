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
    @StateObject private var prefs = TabPreferences.shared

    var body: some View {
        TabView {
            // Главная — всегда первая, не убирается
            DashboardView()
                .tabItem {
                    Label("Главная", systemImage: "square.grid.2x2")
                }

            // Пользовательские вкладки (до 3)
            ForEach(prefs.mainTabs) { tab in
                tab.makeView()
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
            }

            // «Ещё» — всегда последняя
            MoreView()
                .tabItem {
                    Label("Ещё", systemImage: "ellipsis")
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
