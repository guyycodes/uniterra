//
//  ModelManager.swift
//  OnDeviceTranslator
//
//  Created by You on 2025-10-15.
//

import Foundation
import CryptoKit
import os.log

@MainActor
final class ModelManager: ObservableObject {

    // MARK: - Public API

    static let shared = ModelManager()

    /// Configure before first use (e.g., in App start).
    func configure(_ config: Config) {
        self.config = config
    }

    /// Ensures the model file exists, verifies checksum (if set), and loads it.
    func prepareModel(progress: @escaping (Double) -> Void = { _ in }) async throws {
        guard let config else { throw ModelError.notConfigured }

        if isLoaded { return } // already loaded

        isPreparing = true
        defer { isPreparing = false }

        // 1) Ensure file exists (download if needed)
        let localURL = try await fileStore.ensureFile(
            remoteURL: config.modelRemoteURL,
            filename: config.modelFilename,
            expectedSHA256: config.modelSHA256,
            allowResume: true,
            progress: { [weak self] p in
                Task { @MainActor in
                    self?.downloadProgress = p
                    progress(p)
                }
            }
        )

        // 2) Create runtime if needed
        if runtime == nil {
            runtime = config.runtimeFactory()
        }
        guard let runtime else { throw ModelError.runtimeUnavailable }

        // 3) Load once
        if !isLoaded {
            try runtime.loadModel(at: localURL, context: config.contextLength)
            isLoaded = true
        }
    }

    /// Prepare if needed, then translate.
    func ensureAndTranslate(
        _ text: String,
        targetLang: String,
        onToken: ((String) -> Void)? = nil
    ) async throws -> String {
        if !isLoaded {
            try await prepareModel()
        }
        return try await translate(text, targetLang: targetLang, onToken: onToken)
    }

    /// Translate a short text into the target language.
    func translate(
        _ text: String,
        targetLang: String,
        onToken: ((String) -> Void)? = nil
    ) async throws -> String {
        guard let config else { throw ModelError.notConfigured }
        guard let runtime, isLoaded else { throw ModelError.modelNotLoaded }

        let system = config.systemPrompt
        let user = config.userTemplate
            .replacingOccurrences(of: "{TARGET_LANG}", with: targetLang)
            .replacingOccurrences(of: "{SOURCE_TEXT}", with: text)

        let params = GenerationParams(
            temperature: config.temperature,
            topP: config.topP,
            topK: config.topK,
            repeatPenalty: config.repeatPenalty,
            maxTokens: config.maxTokens
        )

        return try await runtime.generate(
            systemPrompt: system,
            userPrompt: user,
            params: params,
            onToken: onToken
        )
    }

    /// Cancel current generation (if supported by runtime).
    func cancel() { runtime?.cancel() }

    /// Convenience to check readiness from UI.
    var isReady: Bool { isLoaded }

    // MARK: - Internals

    private init() {}

    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isPreparing: Bool = false
    @Published private(set) var downloadProgress: Double? = nil

    private var config: Config?
    private var runtime: LLMRuntime?
    private let fileStore = FileStore()
}

// MARK: - Configuration

extension ModelManager {
    struct Config {
        let modelRemoteURL: URL
        let modelFilename: String

        /// If empty or placeholder, checksum verification is skipped (useful for prototyping).
        let modelSHA256: String

        var contextLength: Int = 256

        // Default generation params for translation
        var temperature: Float = 0.2
        var topP: Float = 0.95
        var topK: Int32 = 64
        var repeatPenalty: Float = 1.05
        var maxTokens: Int32 = 256

        // Prompts
        var systemPrompt: String =
        """
        You are a professional translator. Output only the translated text. Keep meaning, tone, numbers, names, emoji, and punctuation. Do not explain. If source and target language are the same, return the input unchanged.
        """

        var userTemplate: String =
        """
        Translate to {TARGET_LANG}:
        {SOURCE_TEXT}
        """

        // Factory so you can switch runtimes (llama.cpp vs MLC) without changing callers.
        var runtimeFactory: () -> LLMRuntime = { LlamaManager() }
    }
}

// MARK: - Errors

enum ModelError: LocalizedError {
    case notConfigured
    case runtimeUnavailable
    case modelNotLoaded
    case invalidChecksum
    case networkFailure
    case fileIO

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "ModelManager is not configured."
        case .runtimeUnavailable: return "Model runtime is unavailable."
        case .modelNotLoaded: return "Model is not loaded."
        case .invalidChecksum: return "Downloaded model failed checksum verification."
        case .networkFailure: return "Network error while downloading model."
        case .fileIO: return "File I/O error."
        }
    }
}

// MARK: - Runtime abstraction

protocol LLMRuntime {
    func loadModel(at localURL: URL, context: Int) throws
    func generate(
        systemPrompt: String,
        userPrompt: String,
        params: GenerationParams,
        onToken: ((String) -> Void)?
    ) async throws -> String
    func cancel()
}

struct GenerationParams {
    var temperature: Float
    var topP: Float
    var topK: Int32
    var repeatPenalty: Float
    var maxTokens: Int32
}

// MARK: - File store (download + checksum + version pin)

private final class FileStore {
    private let log = Logger(subsystem: "OnDeviceTranslator", category: "FileStore")

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func path(for filename: String) -> URL {
        documentsDir.appendingPathComponent(filename, isDirectory: false)
    }

    func ensureFile(
        remoteURL: URL,
        filename: String,
        expectedSHA256: String,
        allowResume: Bool,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let dst = path(for: filename)

        // If file exists and checksum passes (or checksum is skipped), return.
        if FileManager.default.fileExists(atPath: dst.path) {
            if shouldSkipChecksum(expectedSHA256) || (try? verifySHA256(url: dst, expected: expectedSHA256)) == true {
                return dst
            } else {
                log.warning("Checksum mismatch for existing file. Redownloading.")
                try? FileManager.default.removeItem(at: dst)
            }
        }

        try await download(remote: remoteURL, to: dst, allowResume: allowResume, progress: progress)

        if !shouldSkipChecksum(expectedSHA256) {
            guard (try? verifySHA256(url: dst, expected: expectedSHA256)) == true else {
                try? FileManager.default.removeItem(at: dst)
                throw ModelError.invalidChecksum
            }
        } else {
            log.warning("Checksum skipped. Set modelSHA256 in Config for production.")
        }

        return dst
    }

    private func shouldSkipChecksum(_ sha: String) -> Bool {
        let trimmed = sha.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed.uppercased().contains("PUT_THE_EXACT_SHA256") { return true }
        return false
    }

    private func download(
        remote: URL,
        to localURL: URL,
        allowResume: Bool,
        progress: @escaping (Double) -> Void
    ) async throws {
        let tmpURL = localURL.appendingPathExtension("part")
        var request = URLRequest(url: remote)
        var startFrom: Int64 = 0

        if allowResume, FileManager.default.fileExists(atPath: tmpURL.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: tmpURL.path),
               let size = attrs[.size] as? NSNumber {
                startFrom = size.int64Value
                if startFrom > 0 {
                    request.addValue("bytes=\(startFrom)-", forHTTPHeaderField: "Range")
                }
            }
        }

        print("🔗 Downloading from: \(remote.absoluteString)")
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("❌ No HTTP response received")
            throw ModelError.networkFailure
        }
        
        print("📡 HTTP Status Code: \(http.statusCode)")
        
        guard (200...206).contains(http.statusCode) else {
            print("❌ Download failed with status: \(http.statusCode)")
            throw ModelError.networkFailure
        }

        let totalSize: Int64? = {
            if let cl = http.value(forHTTPHeaderField: "Content-Length"),
               let sz = Int64(cl) {
                return startFrom + sz
            }
            return nil
        }()

        try FileManager.default.createDirectory(at: tmpURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)

        let handle: FileHandle
        if FileManager.default.fileExists(atPath: tmpURL.path) {
            handle = try FileHandle(forWritingTo: tmpURL)
            try handle.seekToEnd()
        } else {
            FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
            handle = try FileHandle(forWritingTo: tmpURL)
        }

        var written: Int64 = startFrom

        // Buffer bytes into Data, write periodically (64 KB chunks)
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {            // 'byte' is UInt8
            buffer.append(byte)                  // append to Data buffer
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)

                if let t = totalSize, t > 0 {
                    progress(Double(written) / Double(t))
                }
            }
        }

        // flush any remainder
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
            if let t = totalSize, t > 0 {
                progress(Double(written) / Double(t))
            }
        }

        try handle.close()

        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: tmpURL, to: localURL)
    }

    private func verifySHA256(url: URL, expected: String) throws -> Bool {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex.lowercased() == expected.lowercased()
    }
}
