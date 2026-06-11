import SwiftUI
import SwiftData

// MARK: - Game24HistoryView

struct Game24HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Game24Result.date, order: .reverse) private var results: [Game24Result]

    @State private var selectedDifficulty: Game24Difficulty? = nil

    private var filtered: [Game24Result] {
        guard let d = selectedDifficulty else { return results }
        return results.filter { $0.difficulty == d.rawValue }
    }

    // MARK: Stats

    private func stats(for difficulty: Game24Difficulty) -> (solved: Int, total: Int) {
        let subset = results.filter { $0.difficulty == difficulty.rawValue }
        let solved = subset.filter { $0.solved }.count
        return (solved, subset.count)
    }

    private var bestTime: Game24Result? {
        let solved = filtered.filter { $0.solved }
        return solved.min(by: { $0.timeSeconds < $1.timeSeconds })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Stats cards
                        statsRow

                        // Difficulty filter
                        filterRow

                        // History list
                        if filtered.isEmpty {
                            emptyState
                        } else {
                            historyList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("История")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary.opacity(0.65))
                }
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Game24StatCard(
                    title: "Всего",
                    value: "\(results.count)",
                    icon: "gamecontroller.fill",
                    colorHex: "667eea"
                )
                Game24StatCard(
                    title: "Решено",
                    value: "\(results.filter { $0.solved }.count)",
                    icon: "checkmark.seal.fill",
                    colorHex: "43e97b"
                )
                Game24StatCard(
                    title: "Успех",
                    value: results.isEmpty ? "—" : "\(Int(Double(results.filter { $0.solved }.count) / Double(results.count) * 100))%",
                    icon: "chart.bar.fill",
                    colorHex: "4facfe"
                )
            }

            if let best = bestTime {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color(hex: "fee140"))
                    Text("Рекорд: \(best.timeFormatted) — \(best.difficultyEnum.title)")
                        .foregroundStyle(AppColors.textPrimary.opacity(0.5))
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "fee140").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Per-difficulty breakdown
            HStack(spacing: 10) {
                ForEach(Game24Difficulty.allCases, id: \.rawValue) { d in
                    let s = stats(for: d)
                    VStack(spacing: 4) {
                        Text(d.emoji)
                            .font(.title3)
                        Text("\(s.solved)/\(s.total)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: d.colorHex))
                        Text(d.title)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: d.colorHex).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Все", active: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(Game24Difficulty.allCases, id: \.rawValue) { d in
                    FilterChip(
                        label: "\(d.emoji) \(d.title)",
                        active: selectedDifficulty == d,
                        colorHex: d.colorHex
                    ) {
                        selectedDifficulty = selectedDifficulty == d ? nil : d
                    }
                }
            }
        }
    }

    // MARK: - History List

    private var historyList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filtered, id: \.id) { result in
                HistoryRow(result: result)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppColors.textPrimary.opacity(0.2))
            Text("Нет записей")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary.opacity(0.5))
            Text("Сыграй первую партию!")
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary.opacity(0.3))
        }
        .padding(.top, 40)
    }
}

// MARK: - HistoryRow

struct HistoryRow: View {
    let result: Game24Result

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(result.solved ? Color(hex: "43e97b").opacity(0.15) : Color(hex: "f5576c").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: result.solved ? "checkmark" : "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(result.solved ? Color(hex: "43e97b") : Color(hex: "f5576c"))
            }

            VStack(alignment: .leading, spacing: 5) {
                // Cards
                HStack(spacing: 4) {
                    ForEach(result.cards, id: \.self) { num in
                        Text("\(num)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: result.difficultyEnum.colorHex))
                            .frame(width: 26, height: 26)
                            .background(Color(hex: result.difficultyEnum.colorHex).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }

                    Spacer()

                    Text(result.difficultyEnum.emoji + " " + result.difficultyEnum.title)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: result.difficultyEnum.colorHex))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: result.difficultyEnum.colorHex).opacity(0.1))
                        .clipShape(Capsule())
                }

                if result.solved && !result.expression.isEmpty {
                    Text(result.expression)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.6))
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    Label(result.timeFormatted, systemImage: "timer")
                    Spacer()
                    Text(result.date.shortFormatted)
                }
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textPrimary.opacity(0.35))
            }
        }
        .padding(14)
        .background(AppColors.textPrimary.opacity(result.solved ? 0.05 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Views

struct Game24StatCard: View {
    let title: String
    let value: String
    let icon: String
    let colorHex: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: colorHex))
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: colorHex))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textPrimary.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(hex: colorHex).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct FilterChip: View {
    let label: String
    let active: Bool
    var colorHex: String = "667eea"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color(hex: colorHex) : AppColors.textPrimary.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? Color(hex: colorHex).opacity(0.15) : AppColors.textPrimary.opacity(0.06))
                .clipShape(Capsule())
        }
    }
}
