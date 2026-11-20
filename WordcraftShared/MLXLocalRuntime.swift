#if WORDCRAFT_MLX
import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import HuggingFace
import Tokenizers

enum MLXRuntimeStatus: Sendable, Equatable {
    case ready(modelDescription: String)
    case failed(reason: String)

    var summary: String {
        switch self {
        case .ready(let modelDescription):
            return "Loaded \(modelDescription)."
        case .failed(let reason):
            return "MLX runtime unavailable: \(reason)"
        }
    }
}

actor MLXLocalRuntime {
    private var preparedModelSelection: MLXModelSelection?
    private var modelContainer: ModelContainer?
    private var isPreparing = false

    func prepareIfNeeded(
        allowDownload: Bool,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async -> MLXRuntimeStatus {
        #if targetEnvironment(simulator)
        return .failed(reason: "Run the MLX model on a physical device.")
        #else
        let selection = WordcraftModelPreferences.selectedMLXModel
        let configuration = configuration(for: selection)
        if preparedModelSelection == selection, modelContainer != nil {
            return .ready(modelDescription: configuration.name)
        }

        guard !isPreparing else { return .failed(reason: "A model is already loading.") }
        isPreparing = true
        defer { isPreparing = false }
        modelContainer = nil
        preparedModelSelection = nil
        do {
            guard let group = WordcraftModelPreferences.appGroupIdentifier,
                  let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
                return .failed(reason: "Check the shared App Group in Signing & Capabilities.")
            }

            let cache = HubCache(cacheDirectory: directory.appending(path: "Library/Caches/models"))
            let downloader = ModelDownloader(client: HubClient(cache: cache), localFilesOnly: !allowDownload)
            let container = try await MLXLMCommon.loadModelContainer(
                from: downloader,
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration,
                progressHandler: { progress in progressHandler?(progress) }
            )
            try Task.checkCancellation()
            preparedModelSelection = selection
            modelContainer = container
            return .ready(modelDescription: configuration.name)
        } catch {
            return .failed(reason: error.localizedDescription)
        }
        #endif
    }

    func generateCandidates(for request: SuggestionRequest) async throws -> [String] {
        guard preparedModelSelection == WordcraftModelPreferences.selectedMLXModel,
              let modelContainer else { return [] }

        let input = try await modelContainer.prepare(input: UserInput(prompt: request.prompt))
        let parameters = GenerateParameters(
            maxTokens: 24,
            temperature: 0,
            topP: 1,
            topK: 0
        )
        let stream = try await modelContainer.generate(input: input, parameters: parameters)

        var output = ""
        generationLoop: for await generation in stream {
            switch generation {
            case .chunk(let text):
                output += text
                // Stop once enough words are complete; breaking ends the stream and cancels generation.
                if let last = output.unicodeScalars.last,
                   SuggestionRequest.candidateSeparators.contains(last),
                   request.parseCandidates(output).count >= request.maxSuggestions {
                    break generationLoop
                }
            case .toolCall:
                continue
            case .info:
                continue
            }
        }

        try Task.checkCancellation()

        return request.parseCandidates(output)
    }

    private func configuration(for selection: MLXModelSelection) -> ModelConfiguration {
        if !selection.localDirectoryPath.isEmpty {
            return ModelConfiguration(directory: URL(filePath: selection.localDirectoryPath), extraEOSTokens: ["<turn|>"])
        }
        if !selection.repositoryID.isEmpty {
            return ModelConfiguration(id: selection.repositoryID, extraEOSTokens: ["<turn|>"])
        }
        return LLMRegistry.gemma4_e2b_it_4bit
    }
}

// The host can populate the shared cache. Suggestion requests only read from it.
private struct ModelDownloader: MLXLMCommon.Downloader {
    let client: HubClient
    let localFilesOnly: Bool

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repo = Repo.ID(rawValue: id) else { throw URLError(.badURL) }
        return try await client.downloadSnapshot(
            of: repo,
            revision: revision ?? "main",
            matching: patterns,
            localFilesOnly: localFilesOnly,
            progressHandler: { progress in progressHandler(progress) }
        )
    }
}
#endif
