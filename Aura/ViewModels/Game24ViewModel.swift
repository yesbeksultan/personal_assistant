import SwiftUI
import SwiftData
import Combine

// MARK: - Game State

enum Game24State {
    case idle
    case playing
    case solved
    case failed
}

// MARK: - Game24ViewModel

@Observable
final class Game24ViewModel {

    // MARK: Game state
    var cards: [Int] = []
    var expression: String = ""
    var gameState: Game24State = .idle
    var difficulty: Game24Difficulty = .medium
    var elapsedSeconds: Double = 0
    var showConfetti: Bool = false
    var errorMessage: String? = nil

    // MARK: Timer
    private var timerTask: AnyCancellable?

    // MARK: Start / New Game

    func startNewGame() {
        stopTimer()
        cards = Game24Engine.generatePuzzle(difficulty: difficulty)
        expression = ""
        elapsedSeconds = 0
        gameState = .playing
        errorMessage = nil
        showConfetti = false
        startTimer()
    }

    // MARK: Submit

    func submitExpression(modelContext: ModelContext) {
        guard gameState == .playing else { return }
        errorMessage = nil

        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Введи выражение"
            return
        }

        let isCorrect = Game24Engine.checkSolution(cards: cards, expression: trimmed)

        if isCorrect {
            stopTimer()
            gameState = .solved
            showConfetti = true
            saveResult(solved: true, modelContext: modelContext)
        } else {
            // Evaluate to give a better error message
            if let value = Game24Engine.evaluate(expression: trimmed) {
                let extracted = extractNumbers(from: trimmed).sorted()
                if extracted != cards.sorted() {
                    errorMessage = "Используй именно эти 4 числа!"
                } else {
                    errorMessage = "Результат = \(formatResult(value)), нужно 24"
                }
            } else {
                errorMessage = "Неверное выражение"
            }
        }
    }

    func giveUp(modelContext: ModelContext) {
        guard gameState == .playing else { return }
        stopTimer()
        gameState = .failed
        saveResult(solved: false, modelContext: modelContext)
    }

    // MARK: Timer Helpers

    private func startTimer() {
        timerTask = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 0.1
            }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    var timerDisplay: String {
        let total = Int(elapsedSeconds)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }

    // MARK: Save Result

    private func saveResult(solved: Bool, modelContext: ModelContext) {
        let result = Game24Result(
            cards: cards,
            expression: expression,
            solved: solved,
            difficulty: difficulty,
            timeSeconds: elapsedSeconds
        )
        modelContext.insert(result)
        try? modelContext.save()
    }

    // MARK: Private Helpers

    private func extractNumbers(from expression: String) -> [Int] {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(expression.startIndex..., in: expression)
        return regex.matches(in: expression, range: range).compactMap { match in
            guard let r = Range(match.range, in: expression) else { return nil }
            return Int(expression[r])
        }
    }

    private func formatResult(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
