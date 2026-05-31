import SwiftUI

// MARK: - More View

struct MoreView: View {
    @StateObject private var prefs = TabPreferences.shared
    @State private var showEditSheet = false

    // For navigation to extra tabs
    @State private var navigatingTo: AppTab? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Extra tabs grid (not in main bar)
                    if !prefs.extraTabs.isEmpty {
                        sectionHeader("Разделы")

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 14
                        ) {
                            ForEach(prefs.extraTabs) { tab in
                                NavigationLink(destination: tab.makeView()) {
                                    ExtraTabCard(tab: tab)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // All sections quick access
                    sectionHeader("Все разделы")
                        .padding(.top, prefs.extraTabs.isEmpty ? 0 : 4)

                    VStack(spacing: 2) {
                        ForEach(AppTab.allCases) { tab in
                            NavigationLink(destination: tab.makeView()) {
                                AllSectionsRow(tab: tab, isInMain: prefs.isInMain(tab))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Настроить")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditTabsSheet()
                    .environmentObject(prefs)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
    }
}

// MARK: - Extra Tab Card

private struct ExtraTabCard: View {
    let tab: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tab.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(tab.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - All Sections Row

private struct AllSectionsRow: View {
    let tab: AppTab
    let isInMain: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tab.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tab.color)
            }

            Text(tab.title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)

            Spacer()

            if isInMain {
                Text("На панели")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 62)
        }
    }
}

// MARK: - Edit Tabs Sheet

struct EditTabsSheet: View {
    @EnvironmentObject private var prefs: TabPreferences
    @Environment(\.dismiss) private var dismiss
    #if !os(macOS)
    @State private var editMode: EditMode = .active
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if prefs.mainTabs.isEmpty {
                        Text("Перетащите разделы сюда")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(prefs.mainTabs) { tab in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(tab.color.opacity(0.15))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(tab.color)
                                }
                                Text(tab.title)
                                    .font(.body)
                                Spacer()
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        prefs.removeFromMain(tab)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 22))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { prefs.move(from: $0, to: $1) }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("На панели")
                        Text("До 3 вкладок · Перетащите для сортировки")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.none)
                    }
                }

                Section("Доступно") {
                    ForEach(prefs.extraTabs) { tab in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(tab.color.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: tab.icon)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(tab.color)
                            }
                            Text(tab.title)
                                .font(.body)
                            Spacer()
                            if prefs.canAddMore {
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        prefs.addToMain(tab)
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.system(size: 22))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("Панель заполнена")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            #if !os(macOS)
            .environment(\.editMode, $editMode)
            #endif
            .navigationTitle("Настройка вкладок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    MoreView()
}
