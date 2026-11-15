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
    @State private var deepLinkService = DeepLinkParserService.shared

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $prefs.activeTabID) {
                // Главная — всегда первая, не убирается
                DashboardView()
                    .tabItem {
                        Label("Главная", systemImage: "square.grid.2x2")
                    }
                    .tag("dashboard")

                // Пользовательские вкладки (до 3)
                ForEach(prefs.mainTabs) { tab in
                    tab.makeView()
                        .tabItem {
                            Label(tab.title, systemImage: tab.icon)
                        }
                        .tag(tab.rawValue)
                }

                // «Ещё» — всегда последняя
                MoreView()
                    .tabItem {
                        Label("Ещё", systemImage: "ellipsis")
                    }
                    .tag("more")
            }
            .preferredColorScheme(appTheme == "dark" ? .dark : .light)
            .tint(Color(hex: "667eea"))

            // Floating Deep Link Toast Banner
            if deepLinkService.showStatusBanner, let msg = deepLinkService.statusMessage {
                HStack(spacing: 10) {
                    Image(systemName: deepLinkService.isSuccessBanner ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(deepLinkService.isSuccessBanner ? Color(hex: "43e97b") : Color(hex: "fa709a"))
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        withAnimation { deepLinkService.showStatusBanner = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "1f1f2e").opacity(0.95))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            (deepLinkService.isSuccessBanner ? Color(hex: "43e97b") : Color(hex: "fa709a")).opacity(0.3),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
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
