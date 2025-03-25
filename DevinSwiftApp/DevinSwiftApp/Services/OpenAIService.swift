import Foundation

enum OpenAIError: Error {
    case invalidURL
    case requestFailed(Error)
    case decodingFailed(Error)
    case invalidResponse
    case authenticationFailed
    case rateLimitExceeded
    case serverError
    case unknown
}

class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Speech-to-Text (Whisper API)
    func transcribeAudio(fileURL: URL) async throws -> String {
        let endpoint = "\(baseURL)/audio/transcriptions"
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add model parameter
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add file data
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        do {
            let audioData = try Data(contentsOf: fileURL)
            data.append(audioData)
            data.append("\r\n".data(using: .utf8)!)
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let result = try decoder.decode(TranscriptionResponse.self, from: responseData)
                    return result.text
                } catch {
                    throw OpenAIError.decodingFailed(error)
                }
            case 401:
                throw OpenAIError.authenticationFailed
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.unknown
            }
        } catch {
            throw OpenAIError.requestFailed(error)
        }
    }
    
    // Chat Completion API
    func sendMessage(prompt: String) async throws -> String {
        let endpoint = "\(baseURL)/chat/completions"
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo", // Or "gpt-4" if available
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                do {
                    let result = try decoder.decode(ChatCompletionResponse.self, from: responseData)
                    if let message = result.choices.first?.message.content {
                        return message
                    } else {
                        throw OpenAIError.invalidResponse
                    }
                } catch {
                    throw OpenAIError.decodingFailed(error)
                }
            case 401:
                throw OpenAIError.authenticationFailed
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.unknown
            }
        } catch {
            throw OpenAIError.requestFailed(error)
        }
    }
    
    // Text-to-Speech API
    func textToSpeech(text: String) async throws -> URL {
        let endpoint = "\(baseURL)/audio/speech"
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "tts-1", // Or "tts-1-hd" for higher quality
            "input": text,
            "voice": "alloy" // Available voices: alloy, echo, fable, onyx, nova, shimmer
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // Save audio data to temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp3")
                try responseData.write(to: fileURL)
                return fileURL
            case 401:
                throw OpenAIError.authenticationFailed
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.unknown
            }
        } catch {
            throw OpenAIError.requestFailed(error)
        }
    }
}

// Response models
struct TranscriptionResponse: Decodable {
    let text: String
}

struct ChatCompletionResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
    
    struct Choice: Decodable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Decodable {
        let role: String
        let content: String
    }
}
