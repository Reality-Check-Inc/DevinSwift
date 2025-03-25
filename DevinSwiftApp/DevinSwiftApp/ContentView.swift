//
//  ContentView.swift
//  DevinSwiftApp
//
//  Created by David N. Junod on 3/25/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var viewModel: ChatViewModel
    
    @State private var messageText = ""
    @State private var showApiKeyAlert = false
    @AppStorage("openAIApiKey") private var apiKey = ""
    
    init() {
        let audioManager = AudioManager()
        let savedApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
        _viewModel = StateObject(wrappedValue: ChatViewModel(apiKey: savedApiKey, audioManager: audioManager))
        _audioManager = StateObject(wrappedValue: audioManager)
    }
    
    var body: some View {
        VStack {
            // Chat header
            HStack {
                Text("AI Voice Chat")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showApiKeyAlert = true
                }) {
                    Image(systemName: "key.fill")
                }
            }
            .padding()
            
            // Messages list
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message) {
                            viewModel.playMessageAudio(message)
                        }
                    }
                }
                .padding()
            }
            
            // Recording visualization
            if case .recording = viewModel.state {
                AudioWaveformView(levels: audioManager.recordingLevels, color: .blue)
                    .padding(.horizontal)
            } else if case .processing = viewModel.state {
                ProgressView("Processing...")
                    .padding()
            } else if case .error(let message) = viewModel.state {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            // Input area
            HStack {
                // Text input
                TextField("Type a message", text: $messageText)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .disabled(viewModel.state == .recording || viewModel.state == .processing)
                
                // Send button
                if !messageText.isEmpty {
                    Button(action: {
                        Task {
                            let text = messageText
                            messageText = ""
                            await viewModel.sendMessage(text)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                    }
                    .disabled(viewModel.state == .recording || viewModel.state == .processing)
                }
                
                // Record button
                Button(action: {
                    if case .recording = viewModel.state {
                        Task {
                            await viewModel.stopRecordingAndProcess()
                        }
                    } else if case .idle = viewModel.state {
                        Task {
                            await viewModel.startRecording()
                        }
                    }
                }) {
                    Image(systemName: viewModel.state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(viewModel.state == .recording ? .red : .blue)
                }
                .disabled(viewModel.state == .processing)
            }
            .padding()
        }
        .alert("Enter OpenAI API Key", isPresented: $showApiKeyAlert) {
            TextField("API Key", text: $apiKey)
            Button("Save") {
                UserDefaults.standard.set(apiKey, forKey: "openAIApiKey")
                viewModel = ChatViewModel(apiKey: apiKey, audioManager: audioManager)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your API key is stored only on this device")
        }
        .onAppear {
            if apiKey.isEmpty {
                showApiKeyAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
}
