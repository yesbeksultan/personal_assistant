import Foundation
import SwiftData

@Model
final class GameRecord {
    var id: UUID
    var date: Date
    var difficulty: String
    var solvedCount: Int
    
    init(id: UUID = UUID(), date: Date = Date(), difficulty: String, solvedCount: Int = 1) {
        self.id = id
        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: date)
        self.difficulty = difficulty
        self.solvedCount = solvedCount
    }
}
