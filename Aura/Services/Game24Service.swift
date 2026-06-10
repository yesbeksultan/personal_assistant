import Foundation

enum GameDifficulty: String, CaseIterable, Codable, Identifiable {
    case easy = "Легкий"
    case medium = "Средний"
    case hard = "Сложный"
    
    var id: String { rawValue }
    
    var colorHex: String {
        switch self {
        case .easy: return "43e97b"   // Green
        case .medium: return "4facfe" // Blue
        case .hard: return "fa709a"   // Pink/Red
        }
    }
}

struct Game24Problem: Codable {
    let numbers: [Int]
    let difficulty: GameDifficulty
    let solution: String
}

final class Game24Service {
    static let shared = Game24Service()
    
    private init() {}
    
    struct SolutionItem {
        let val: Double
        let expr: String
    }
    
    /// Generates a problem of the specified difficulty
    func generateProblem(difficulty: GameDifficulty) -> Game24Problem {
        var attempts = 0
        while attempts < 1000 {
            attempts += 1
            // Generate 4 numbers from 1 to 9 (standard 24 game rules)
            let nums = (0..<4).map { _ in Int.random(in: 1...9) }
            let doubleNums = nums.map { Double($0) }
            
            // 1. Check if solvable at Easy level (only +, -, *)
            if let easySol = solveRecursive(items: doubleNums.map { SolutionItem(val: $0, expr: String(Int($0))) }, allowDivision: false, integerDivisionOnly: false) {
                if difficulty == .easy {
                    return Game24Problem(numbers: nums, difficulty: .easy, solution: easySol)
                }
                continue
            }
            
            // 2. Check if solvable at Medium level (allow division but only integer divisions like 8/2, 6/3)
            if let medSol = solveRecursive(items: doubleNums.map { SolutionItem(val: $0, expr: String(Int($0))) }, allowDivision: true, integerDivisionOnly: true) {
                if difficulty == .medium {
                    return Game24Problem(numbers: nums, difficulty: .medium, solution: medSol)
                }
                continue
            }
            
            // 3. Check if solvable at Hard level (allows fractions like 8 / (3 - 8/3))
            if let hardSol = solveRecursive(items: doubleNums.map { SolutionItem(val: $0, expr: String(Int($0))) }, allowDivision: true, integerDivisionOnly: false) {
                if difficulty == .hard {
                    return Game24Problem(numbers: nums, difficulty: .hard, solution: hardSol)
                }
                continue
            }
        }
        
        // Fallback fallback problem if random generation fails to hit target difficulty (very unlikely)
        switch difficulty {
        case .easy:
            return Game24Problem(numbers: [1, 2, 3, 4], difficulty: .easy, solution: "(1 + 2 + 3) * 4")
        case .medium:
            return Game24Problem(numbers: [2, 3, 4, 6], difficulty: .medium, solution: "(6 * 4) / (3 - 2)")
        case .hard:
            return Game24Problem(numbers: [3, 3, 8, 8], difficulty: .hard, solution: "8 / (3 - (8 / 3))")
        }
    }
    
    /// Checks if a mathematical expression string matches the target 24 value and uses all 4 numbers
    func verifyUserSolution(expr: String, problemNumbers: [Int]) -> (isValid: Bool, message: String) {
        // 1. Remove all spaces
        let cleaned = expr.replacingOccurrences(of: " ", with: "")
        
        // 2. Extract all numbers from the expression
        let regex = try! NSRegularExpression(pattern: "\\d+")
        let matches = regex.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
        let exprNumbers = matches.compactMap { match -> Int? in
            guard let range = Range(match.range, in: cleaned) else { return nil }
            return Int(cleaned[range])
        }
        
        // Check if user used exactly 4 numbers
        guard exprNumbers.count == 4 else {
            return (false, "Вы должны использовать ровно 4 числа")
        }
        
        // Check if the numbers match the problem numbers exactly (regardless of order)
        var tempProblem = problemNumbers
        for num in exprNumbers {
            if let index = tempProblem.firstIndex(of: num) {
                tempProblem.remove(at: index)
            } else {
                return (false, "Число \(num) не задано в условии")
            }
        }
        
        guard tempProblem.isEmpty else {
            return (false, "Использованы не все заданные числа")
        }
        
        // 3. Evaluate expression
        let expression = NSExpression(format: cleaned)
        let anyResult = expression.expressionValue(with: nil, context: nil)

        if let number = anyResult as? NSNumber {
            let doubleResult = number.doubleValue
            if abs(doubleResult - 24.0) < 0.001 {
                return (true, "Правильно!")
            } else {
                let formatted = String(format: "%.1f", doubleResult)
                return (false, "Результат выражения равен \(formatted), а должно быть 24")
            }
        }

        return (false, "Не удалось вычислить выражение. Проверьте правильность скобок и знаков.")
    }
    
    // MARK: - Private Recursive Solver
    
    private func solveRecursive(items: [SolutionItem], allowDivision: Bool, integerDivisionOnly: Bool) -> String? {
        if items.count == 1 {
            if abs(items[0].val - 24.0) < 0.001 {
                return items[0].expr
            }
            return nil
        }
        
        for i in 0..<items.count {
            for j in 0..<items.count {
                if i == j { continue }
                
                let a = items[i]
                let b = items[j]
                
                var remaining: [SolutionItem] = []
                for k in 0..<items.count {
                    if k != i && k != j {
                        remaining.append(items[k])
                    }
                }
                
                // Try operations
                var ops: [(val: Double, expr: String)] = [
                    (a.val + b.val, "(\(a.expr) + \(b.expr))"),
                    (a.val - b.val, "(\(a.expr) - \(b.expr))"),
                    (a.val * b.val, "(\(a.expr) * \(b.expr))")
                ]
                
                if allowDivision && abs(b.val) > 0.001 {
                    let divisionResult = a.val / b.val
                    let isIntegerDiv = abs(a.val.truncatingRemainder(dividingBy: b.val)) < 0.001
                    
                    if !integerDivisionOnly || isIntegerDiv {
                        ops.append((divisionResult, "(\(a.expr) / \(b.expr))"))
                    }
                }
                
                for op in ops {
                    let nextItem = SolutionItem(val: op.val, expr: op.expr)
                    if let solution = solveRecursive(items: remaining + [nextItem], allowDivision: allowDivision, integerDivisionOnly: integerDivisionOnly) {
                        return solution
                    }
                }
            }
        }
        return nil
    }
}
