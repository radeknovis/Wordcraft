import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import HuggingFace

import Tokenizers

enum MLXRuntimeStatus: Sendable, Equatable {
    case notConfigured
    case ready(modelDescription: String)
    case failed(reason: String)

    var summary: String {
        switch self {
        case .notConfigured:
            return "MLX runtime linked. Model selection still needed."
        case .ready(let modelDescription):
            return "MLX runtime linked. Pending load for \(modelDescription)."
        case .failed(let reason):
            return "MLX runtime unavailable: \(reason)"
        }
    }
}

actor MLXLocalRuntime {
    private var preparedBackend: LocalModelBackend?
    private var preparedModelSelection: MLXModelSelection?
    private var modelContainer: ModelContainer?
    private var lastStatus: MLXRuntimeStatus = .notConfigured

    func prepareIfNeeded(
        for backend: LocalModelBackend,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async -> MLXRuntimeStatus {
        guard backend.usesMLXRuntime else {
            modelContainer = nil
            lastStatus = .failed(reason: "Selected backend does not use MLX.")
            return lastStatus
        }

        let modelSelection = WordcraftModelPreferences.selectedMLXModel
        let configuration = configuration(for: backend, selection: modelSelection)
        guard let configuration else {
            modelContainer = nil
            preparedBackend = nil
            preparedModelSelection = nil
            lastStatus = .notConfigured
            return lastStatus
        }

        guard preparedBackend != backend || preparedModelSelection != modelSelection || modelContainer == nil else {
            return lastStatus
        }

        do {
            modelContainer = try await loadContainer(
                for: configuration,
                selection: modelSelection,
                progressHandler: progressHandler
            )
            preparedBackend = backend
            preparedModelSelection = modelSelection
            lastStatus = .ready(modelDescription: configuration.name)
        } catch {
            modelContainer = nil
            preparedBackend = nil
            preparedModelSelection = nil
            lastStatus = .failed(reason: error.localizedDescription)
        }

        return lastStatus
    }

    func generateCandidates(
        for request: SuggestionRequest,
        backend: LocalModelBackend
    ) async throws -> [String]? {
        let status = await prepareIfNeeded(for: backend)
        guard case .ready = status else {
            return nil
        }

        guard let modelContainer else {
            return nil
        }

        let prompt = """
        Context before cursor:
        \(request.context)

        Return exactly \(request.maxSuggestions) likely next single-word candidates.
        Output comma-separated words only. No punctuation, no numbering, no explanation.
        """

        let input = try await modelContainer.prepare(input: UserInput(prompt: prompt))
        let parameters = GenerateParameters(
            maxTokens: 24,
            temperature: 0,
            topP: 1,
            topK: 0
        )
        let stream = try await modelContainer.generate(input: input, parameters: parameters)

        var output = ""
        for await generation in stream {
            switch generation {
            case .chunk(let text):
                output += text
            case .toolCall:
                continue
            case .info:
                continue
            }
        }

        let candidates = parseCandidates(output, limit: request.maxSuggestions)
        return candidates.isEmpty ? nil : candidates
    }

    private func configuration(
        for backend: LocalModelBackend,
        selection: MLXModelSelection
    ) -> ModelConfiguration? {
        switch backend {
        case .foundationModels:
            return nil
        case .mlxvlm:
            return nil
        case .gemma4:
            if !selection.localDirectoryPath.isEmpty {
                return ModelConfiguration(
                    directory: URL(filePath: selection.localDirectoryPath),
                    extraEOSTokens: ["<turn|>"]
                )
            }

            if !selection.repositoryID.isEmpty {
                return ModelConfiguration(
                    id: selection.repositoryID,
                    extraEOSTokens: ["<turn|>"]
                )
            }

            return LLMRegistry.gemma4_e2b_it_4bit
        }
    }

    private func loadContainer(
        for configuration: ModelConfiguration,
        selection: MLXModelSelection,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> ModelContainer {
        if !selection.localDirectoryPath.isEmpty {
            return try await LLMModelFactory.shared.loadContainer(
                from: URL(filePath: selection.localDirectoryPath),
                using: #huggingFaceTokenizerLoader()
            )
        }

        return try await #huggingFaceLoadModelContainer(configuration: configuration) { progress in
            progressHandler?(progress)
            print("Wordcraft MLX download progress \(Int(progress.fractionCompleted * 100))% for \(configuration.name)")
        }
    }

    private func parseCandidates(_ rawOutput: String, limit: Int) -> [String] {
        rawOutput
            .components(separatedBy: CharacterSet(charactersIn: ",\n;|"))
            .map { token in
                token
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'[]0123456789.-"))
            }
            .filter { candidate in
                candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
                    && candidate.rangeOfCharacter(from: .letters) != nil
            }
            .reduce(into: [String]()) { partialResult, candidate in
                guard partialResult.count < limit else { return }
                guard !partialResult.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) else { return }
                partialResult.append(candidate)
            }
    }
}
