//
//  MirAIService.swift
//  MirAITestProj
//
//  Created by Andrey Kyashkin on 08.07.2025.
//

import Foundation
import Combine
import Uzu

// ChatMessage struct remains the same
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    var text: String
    let isFromUser: Bool
}

// NOTE: The `ChatStreamHandler` class has been completely removed.

@MainActor
@Observable
final class MiraiService {
    
    static let shared = MiraiService()

    // MARK: - Public Properties for SwiftUI
    
    var messages: [ChatMessage] = []
    var isGenerating: Bool = false
    var modelState: ModelState? {
        engine.states[modelId]
    }

    // MARK: - Private Properties
    
    private let engine: UzuEngine
    private var session: Session?
    
    private let modelId = "Meta-Llama-3.2-1B-Instruct-float16"
    private let apiKey = "YOUR_API_KEY"

    init() {
        guard apiKey != "YOUR_API_KEY" else {
            fatalError("Please replace 'YOUR_API_KEY' in MiraiService.swift with your actual API key.")
        }
        
        self.engine = UzuEngine(apiKey: apiKey)
        start()
    }

    // MARK: - Public Methods

    /// Fetches the available models from the registry.
    func start() {
        Task {
            do {
                print("Updating model registry...")
                _ = try await engine.updateRegistry()
                print("Registry updated. Current state for \(modelId): \(String(describing: modelState))")
                
                print("Creating new session for \(modelId)...")
                session = try engine.createSession(identifier: modelId)
                let config = SessionConfig(
                    preset: .summarization,
                    samplingSeed: .default,
                    contextLength: .default
                )
                try session?.load(config: config)
                print("Session created successfully.")
                
            } catch {
                print("Failed to update registry: \(error.localizedDescription)")
            }
        }
    }

    /// Begins downloading the model if it's not already available.
    func downloadModel() {
        print("Requesting download for model: \(modelId)")
        engine.download(identifier: modelId)
    }

    /// Sends a prompt to the model and handles the streaming response using closures.
    func sendMessage(_ prompt: String) {
        guard !prompt.isEmpty else { return }

        isGenerating = true
        let userMessage = ChatMessage(text: prompt, isFromUser: true)
        messages.append(userMessage)
        
        let assistantMessage = ChatMessage(text: "", isFromUser: false)
        messages.append(assistantMessage)
        
        Task {
            do {
                guard let session = session else {
                    throw NSError(domain: "MiraiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session could not be created."])
                }
                
                let input = SessionInput.messages([
                    .init(role: .system, content: "You are a helpful assistant"),
                    .init(role: .user, content: prompt)
                ])
                let output = session.run(
                    input: input,
                    tokensLimit: 1024,
                    samplingMethod: .argmax
                ) { partialOutput in
                    Task { @MainActor in
                        // Access the current text using partialOutput.text
                        if let lastMessageIndex = self.messages.lastIndex(where: { !$0.isFromUser }) {
                            self.messages[lastMessageIndex].text = partialOutput.text
                        }
                        self.isGenerating = false
                    }
                    return true // Return true to continue generation
                }
            } catch {
                print("Failed to run session: \(error.localizedDescription)")
                self.isGenerating = false
                if let lastMessageIndex = self.messages.lastIndex(where: { !$0.isFromUser }) {
                    self.messages[lastMessageIndex].text = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
