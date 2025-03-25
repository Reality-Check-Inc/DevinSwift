import SwiftUI

struct ChatBubbleView: View {
    let message: Message
    var onAudioTap: () -> Void
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(message.isFromUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)
                
                if !message.isFromUser, message.audioUrl != nil {
                    Button(action: onAudioTap) {
                        Label("Play Audio", systemImage: "play.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
