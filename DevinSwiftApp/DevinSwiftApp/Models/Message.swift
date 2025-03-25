import Foundation

struct Message: Identifiable {
    var id = UUID()
    let content: String
    let isFromUser: Bool
    var audioUrl: URL?
    
    static func example(isFromUser: Bool) -> Message {
        Message(content: isFromUser ? "Hello, how are you?" : "I'm doing well, thank you for asking!", isFromUser: isFromUser)
    }
}
