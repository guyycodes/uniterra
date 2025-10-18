//
//  LlamaManager.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/17/25.
//

import Foundation

// Bridge to the actual LlamaRunner (Objective-C++)
final class LlamaManager: LLMRuntime, @unchecked Sendable {
    private var runner: LlamaRunner?
    private let queue = DispatchQueue(label: "com.uniterra.llama", qos: .userInitiated)
    
    func loadModel(at localURL: URL, context: Int) async throws {
        // Clean up any existing runner
        runner?.cleanup()
        
        // Load model on background queue without blocking
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                // This loads the 4GB model - happens on background queue
                let newRunner = LlamaRunner(modelPath: localURL.path, contextSize: Int32(context))
                
                // Check if runner was successfully created (it's non-optional but might be invalid)
                self?.runner = newRunner
                continuation.resume()
            }
        }
    }
    
    func generate(
        systemPrompt: String,
        userPrompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String {
        guard let runner = runner else {
            throw ModelError.modelNotLoaded
        }
        
        // Format the prompt for translation
        let fullPrompt = """
        <|im_start|>system
        \(systemPrompt)
        <|im_end|>
        <|im_start|>user
        \(userPrompt)
        <|im_end|>
        <|im_start|>assistant
        """
        
        // Generate response on background queue
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let response = runner.generateResponse(
                    forPrompt: fullPrompt,
                    temperature: params.temperature,
                    topP: params.topP,
                    maxTokens: Int32(params.maxTokens)
                ) {
                    // Stream tokens if callback provided
                    if let onToken = onToken {
                        DispatchQueue.main.async {
                            onToken(response)
                        }
                    }
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: ModelError.runtimeUnavailable)
                }
            }
        }
    }
    
    func cancel() {
        // TODO: Implement cancellation in LlamaRunner if needed
    }
    
    deinit {
        runner?.cleanup()
    }
}

// Model definitions for Qwen models
struct ModelDefinition {
    let id: String
    let name: String
    let huggingFaceURL: String
    let filename: String
    let sha256: String // Will be filled in once we have actual checksums
    let contextLength: Int
    let description: String
}

extension ModelDefinition {
    static let qwen8BInstruct = ModelDefinition(
        id: "qwen-8b-instruct",
        name: "Qwen3 8B Instruct",
        huggingFaceURL: "https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf",
        filename: "Qwen3-8B-Q4_K_M.gguf",
        sha256: "", // Checksum verification disabled for development
        contextLength: 456,
        description: "Powerful 8B model with thinking mode"
    )
    
    static let qwen7BInstruct = ModelDefinition(
        id: "qwen-7b-instruct",
        name: "Qwen 2.5 7B Instruct",
        huggingFaceURL: "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf",
        filename: "Qwen2.5-7B-Instruct-Q4_K_M.gguf",
        sha256: "", // Checksum verification disabled for development
        contextLength: 456,
        description: "Efficient 7B model"
    )
    
    static let availableModels = [qwen8BInstruct, qwen7BInstruct]
}
