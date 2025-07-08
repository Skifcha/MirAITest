//
//  ChatView.swift
//  MirAITestProj
//
//  Created by Andrey Kyashkin on 08.07.2025.
//

import SwiftUI
import Uzu

struct ChatView: View {
    @State private var miraiService = MiraiService.shared
    
    @State private var userInput: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                mainContent
            }
            .navigationTitle("Llama 3.2 Chat (Uzu)")
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        // Switch on the computed `modelState` property from our service.
        // The `?.` is important because the state might not exist yet.
        switch miraiService.modelState {
        case .none, .notDownloaded:
            // "none" means the registry hasn't loaded yet. "idle" means it's there but not downloaded.
            VStack(spacing: 20) {
                Text("Model is ready to be downloaded.")
                Button("Download Llama 3.2 Model") {
                    miraiService.downloadModel()
                }
                .buttonStyle(.borderedProminent)
            }
            
        case .downloading(let progress):
            VStack(spacing: 10) {
                Text("Downloading Model...")
                // This ProgressView directly shows the download percentage.
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(String(format: "%.1f%%", progress * 100))
            }
            .padding()
            
        case .paused(let progress):
            VStack(spacing: 10) {
                Text("Paused downloading...")
                // This ProgressView directly shows the download percentage.
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(String(format: "%.1f%%", progress * 100))
            }
            .padding()
            
        case .downloaded:
            // The model is ready, show the chat interface
            chatInterface

        case .error(let message):
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.largeTitle)
                Text("An Error Occurred")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private var chatInterface: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(miraiService.messages) { message in // No need for id: \.self with Identifiable
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: miraiService.messages) {
                    // Auto-scroll to the bottom when a new message is added
                    proxy.scrollTo(miraiService.messages.last?.id, anchor: .bottom)
                }
            }

            HStack {
                TextField("Ask something...", text: $userInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.largeTitle)
                }
                .disabled(userInput.isEmpty || miraiService.isGenerating)
            }
            .padding()
        }
    }
    
    func sendMessage() {
        let prompt = userInput
        userInput = ""
        miraiService.sendMessage(prompt)
    }
}

// MessageView remains the same
struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            Text(message.text)
                .padding(10)
                .background(message.isFromUser ? .blue : .gray.opacity(0.3))
                .foregroundColor(message.isFromUser ? .white : .primary)
                .cornerRadius(10)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
}


#Preview {
    ChatView()
}
