import Foundation

// MARK: - Game24Engine

/// Generates solvable Game-of-24 puzzles and validates player expressions.
struct Game24Engine {

    // MARK: Puzzle Generation

    /// Returns 4 cards that are guaranteed to have at least one solution equalling 24.
    static func generatePuzzle(difficulty: Game24Difficulty) -> [Int] {
        let range = difficulty.cardRange
        var attempts = 0
        while true {
            let cards = (0..<4).map { _ in Int.random(in: range) }
            if hasSolution(cards) {
                return cards
            }
            attempts += 1
            // Safety valve – after many attempts widen to known-good combos
            if attempts > 200 {
                return knownSolvable(difficulty: difficulty)
            }
        }
    }

    // MARK: Solution Checking

    /// Returns true when `expression` evaluates to 24.0 (±0.001) and
    /// uses exactly the same multiset of numbers as `cards`.
    static func checkSolution(cards: [Int], expression: String) -> Bool {
        guard let result = evaluate(expression: expression) else { return false }
        guard abs(result - 24.0) < 0.001 else { return false }
        let usedNumbers = extractNumbers(from: expression)
        return usedNumbers.sorted() == cards.sorted()
    }

    // MARK: Expression Evaluation

    /// Safely evaluates a math expression string (supports +, -, *, /, parentheses).
    static func evaluate(expression rawExpr: String) -> Double? {
        // Replace '×' and '÷' for convenience
        let cleaned = rawExpr
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "x", with: "*")
            .trimmingCharacters(in: .whitespaces)

        guard !cleaned.isEmpty else { return nil }

        // Use NSExpression for safe evaluation
        let expr = NSExpression(format: cleaned)
        if let value = expr.expressionValue(with: nil, context: nil) as? NSNumber {
            let d = value.doubleValue
            if d.isNaN || d.isInfinite { return nil }
            return d
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Checks if any permutation + operation combination of `cards` yields 24.
    private static func hasSolution(_ cards: [Int]) -> Bool {
        let nums = cards.map(Double.init)
        return canMake24(nums)
    }

    private static func canMake24(_ nums: [Double]) -> Bool {
        if nums.count == 1 {
            return abs(nums[0] - 24.0) < 0.001
        }
        for i in 0..<nums.count {
            for j in 0..<nums.count where j != i {
                let a = nums[i], b = nums[j]
                var remaining = nums.indices.filter { $0 != i && $0 != j }.map { nums[$0] }
                for result in applyOps(a, b) {
                    remaining.append(result)
                    if canMake24(remaining) { return true }
                    remaining.removeLast()
                }
            }
        }
        return false
    }

    private static func applyOps(_ a: Double, _ b: Double) -> [Double] {
        var results: [Double] = [a + b, a - b, a * b, b - a]
        if abs(b) > 0.0001 { results.append(a / b) }
        if abs(a) > 0.0001 { results.append(b / a) }
        return results
    }

    /// Extracts integer numbers from the expression string.
    private static func extractNumbers(from expression: String) -> [Int] {
        // Match sequences of digits
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(expression.startIndex..., in: expression)
        return regex.matches(in: expression, range: range).compactMap { match in
            guard let r = Range(match.range, in: expression) else { return nil }
            return Int(expression[r])
        }
    }

    /// Returns a hardcoded solvable puzzle as a safety fallback.
    private static func knownSolvable(difficulty: Game24Difficulty) -> [Int] {
        let pools: [Game24Difficulty: [[Int]]] = [
            .easy:   [[1, 2, 3, 4], [2, 3, 4, 6], [1, 4, 6, 6], [3, 3, 8, 1], [4, 4, 4, 6]],
            .medium: [[1, 2, 7, 8], [3, 3, 7, 7], [4, 7, 8, 8], [2, 5, 6, 9], [1, 5, 5, 5]],
            .hard:   [[1, 4, 5, 6], [3, 9, 9, 9], [1, 6, 6, 8], [1, 3, 8, 8], [2, 3, 9, 11]]
        ]
        return pools[difficulty]?.randomElement() ?? [3, 8, 3, 1]
    }
}
