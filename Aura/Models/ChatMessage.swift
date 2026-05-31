import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var session: ChatSession?
    
    init(content: String, isFromUser: Bool, session: ChatSession? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.session = session
    }
}
