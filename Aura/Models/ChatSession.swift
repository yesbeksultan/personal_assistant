import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]?
    
    init(title: String = "Новый чат") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.messages = []
    }
}
