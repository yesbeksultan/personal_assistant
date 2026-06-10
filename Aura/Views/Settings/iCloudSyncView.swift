import SwiftUI

// MARK: - iCloud Sync Status View

struct iCloudSyncView: View {
    private let iCloud = iCloudService.shared
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 16) {
            // Status pill
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iCloud.status.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: iCloud.status.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iCloud.status.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(iCloud.status.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)

                    if iCloud.status == .noAccount {
                        Text("Настройки → Apple ID → iCloud")
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    } else if let date = iCloud.lastSyncDate {
                        Text("Синхронизировано: \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    } else {
                        Text("Данные синхронизируются автоматически")
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    }
                }

                Spacer()

                if iCloud.isAvailable {
                    // Animated sync indicator
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                        .foregroundStyle(iCloud.status.color)
                        .font(.system(size: 18))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
            }

            if iCloud.isAvailable {
                Divider()

                // What syncs
                VStack(alignment: .leading, spacing: 8) {
                    Text("Что синхронизируется")
                        .font(.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    syncRow(icon: "checkmark.circle", color: Color(hex: "667eea"), title: "Задачи", subtitle: "Через iCloud Drive (JSON)", synced: true)
                    syncRow(icon: "creditcard", color: Color(hex: "4facfe"), title: "Финансы", subtitle: "Через iCloud Drive (JSON)", synced: true)
                    syncRow(icon: "sparkles", color: Color(hex: "f093fb"), title: "Чаты", subtitle: "Только локально", synced: false)
                    syncRow(icon: "note.text", color: Color(hex: "fa709a"), title: "Заметки", subtitle: "Файлы в iCloud Drive", synced: true)
                    syncRow(icon: "doc.richtext", color: Color(hex: "43e97b"), title: "Markdown", subtitle: "Документы в iCloud Drive", synced: true)
                    syncRow(icon: "square.grid.2x2", color: Color(hex: "5ee7df"), title: "Вкладки", subtitle: "Порядок и выбор вкладок", synced: true)
                }

                // Manual refresh
                Button {
                    triggerRefresh()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Синхронизировать сейчас")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "4facfe"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(hex: "4facfe").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isRefreshing)
            } else {
                // No account — open settings button
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                        Text("Открыть настройки iPhone")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear { iCloud.checkStatus() }
    }

    // MARK: - Sync Row

    private func syncRow(icon: String, color: Color, title: String, subtitle: String, synced: Bool = true) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.4))
            }

            Spacer()

            if synced {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(hex: "43e97b"))
            } else {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.25))
            }
        }
    }

    // MARK: - Refresh

    private func triggerRefresh() {
        isRefreshing = true
        NSUbiquitousKeyValueStore.default.synchronize()
        iCloud.markSynced()
        iCloud.checkStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
        }
    }
}
