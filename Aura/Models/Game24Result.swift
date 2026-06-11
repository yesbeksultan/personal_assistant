import Foundation
import SwiftData

// MARK: - Game24Difficulty

enum Game24Difficulty: String, CaseIterable, Codable {
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"

    var title: String {
        switch self {
        case .easy:   return "Лёгкий"
        case .medium: return "Средний"
        case .hard:   return "Сложный"
        }
    }

    var emoji: String {
        switch self {
        case .easy:   return "🟢"
        case .medium: return "🟡"
        case .hard:   return "🔴"
        }
    }

    var colorHex: String {
        switch self {
        case .easy:   return "43e97b"
        case .medium: return "fee140"
        case .hard:   return "f5576c"
        }
    }

    /// Number range used to generate cards at this difficulty level.
    var cardRange: ClosedRange<Int> {
        switch self {
        case .easy:   return 1...6
        case .medium: return 1...10
        case .hard:   return 1...13
        }
    }
}

// MARK: - Game24Result (SwiftData Model)

@Model
final class Game24Result {
    var id: UUID
    var date: Date

    /// The four card values shown to the player (stored as comma-separated string for SwiftData compat)
    var cardsRaw: String

    var expression: String
    var solved: Bool
    var difficulty: String   // Game24Difficulty.rawValue
    var timeSeconds: Double

    init(
        cards: [Int],
        expression: String,
        solved: Bool,
        difficulty: Game24Difficulty,
        timeSeconds: Double
    ) {
        self.id = UUID()
        self.date = Date()
        self.cardsRaw = cards.map(String.init).joined(separator: ",")
        self.expression = expression
        self.solved = solved
        self.difficulty = difficulty.rawValue
        self.timeSeconds = timeSeconds
    }

    /// Decoded array of card values.
    var cards: [Int] {
        cardsRaw.split(separator: ",").compactMap { Int($0) }
    }

    var difficultyEnum: Game24Difficulty {
        Game24Difficulty(rawValue: difficulty) ?? .medium
    }

    var timeFormatted: String {
        let m = Int(timeSeconds) / 60
        let s = Int(timeSeconds) % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        } else {
            return String(format: "%ds", s)
        }
    }
}
