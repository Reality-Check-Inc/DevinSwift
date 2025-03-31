import Foundation
import SwiftUI

enum ChatViewState: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var state: ChatViewState = .idle
    @Published var errorMessage: String?
    
    private let openAIService: OpenAIService
    private let audioManager: AudioManager
    
    init(apiKey: String, audioManager: AudioManager) {
        self.openAIService = OpenAIService(apiKey: apiKey)
        self.audioManager = audioManager
    }
    
    // Start recording user's voice
    func startRecording() async {
        do {
            try await audioManager.startRecording()
            await MainActor.run {
                state = .recording
            }
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    // Stop recording and process audio
    func stopRecordingAndProcess() async {
        audioManager.stopRecording()
        
        guard let recordingURL = audioManager.recordingURL else {
            await MainActor.run {
                state = .error("No recording found")
                errorMessage = "No recording found"
            }
            return
        }
        
        await MainActor.run {
            state = .processing
        }
        
        do {
            // 1. Convert speech to text
            let transcription = try await openAIService.transcribeAudio(fileURL: recordingURL)
            
            // 2. Add user message
            let userMessage = Message(content: transcription, isFromUser: true)
            await MainActor.run {
                messages.append(userMessage)
            }
            
            // 3. Get response from ChatGPT
            let chatResponse = try await openAIService.sendMessage(prompt: transcription)
            
            // 4. Convert response to speech
            let speechURL = try await openAIService.textToSpeech(text: chatResponse)
            
            // 5. Add assistant message with speech URL
            let assistantMessage = Message(content: chatResponse, isFromUser: false, audioUrl: speechURL)
            await MainActor.run {
                messages.append(assistantMessage)
                state = .idle
            }
            
            // 6. Play the response
            try audioManager.playAudio(from: speechURL)
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
                errorMessage = "Error processing audio: \(error.localizedDescription)"
            }
        }
    }
    
    // Add a text message manually
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMessage = Message(content: text, isFromUser: true)
        await MainActor.run {
            messages.append(userMessage)
            state = .processing
        }
        
        do {
            // Get response from ChatGPT
            let chatResponse = try await openAIService.sendMessage(prompt: text)
            
            // Convert response to speech
            let speechURL = try await openAIService.textToSpeech(text: chatResponse)
            
            // Add assistant message with speech URL
            let assistantMessage = Message(content: chatResponse, isFromUser: false, audioUrl: speechURL)
            await MainActor.run {
                messages.append(assistantMessage)
                state = .idle
            }
            
            // Play the response
            try audioManager.playAudio(from: speechURL)
        } catch {
            await MainActor.run {
                state = .error(error.localizedDescription)
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    // Play a message's audio
    func playMessageAudio(_ message: Message) {
        guard let audioUrl = message.audioUrl else { return }
        
        do {
            try audioManager.playAudio(from: audioUrl)
        } catch {
            errorMessage = "Failed to play audio: \(error.localizedDescription)"
        }
    }
    
    // Clear all messages
    func clearMessages() {
        messages = []
    }
}
