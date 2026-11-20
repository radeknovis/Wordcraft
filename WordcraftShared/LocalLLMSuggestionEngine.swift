import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

actor LocalLLMSuggestionEngine: SuggestionEngine {
    #if canImport(FoundationModels)
    private var nextFoundationSession: Any?
    #endif

    #if WORDCRAFT_MLX
    private let mlxRuntime = MLXLocalRuntime()

    func prepareMLXModel(progressHandler: @Sendable @escaping (Progress) -> Void) async -> String {
        await mlxRuntime.prepareIfNeeded(allowDownload: true, progressHandler: progressHandler).summary
    }
    #endif

    func suggestions(for request: SuggestionRequest) async throws -> SuggestionResult {
        try Task.checkCancellation()
        let backend = WordcraftModelPreferences.selectedBackend
        #if canImport(FoundationModels)
        if backend != .foundationModels { nextFoundationSession = nil }
        #endif
        let start = ContinuousClock.now
        var candidates: [String] = []
        var loadTime: Double?
        var modelName: String?

        switch backend {
        case .sample:
            break
        case .foundationModels:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
                // A fresh session keeps each text field's context out of subsequent requests.
                let instructions = "Return only concise next-word candidates for a keyboard."
                let session = nextFoundationSession as? LanguageModelSession ?? LanguageModelSession(instructions: instructions)
                let nextSession = LanguageModelSession(instructions: instructions)
                nextSession.prewarm()
                nextFoundationSession = nextSession
                loadTime = start.duration(to: .now).milliseconds
                #if compiler(>=6.4)
                let options = GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 24)
                #else
                let options = GenerationOptions(sampling: .greedy, maximumResponseTokens: 24)
                #endif
                if let response = try? await session.respond(to: request.prompt, options: options) {
                    candidates = request.parseCandidates(response.content)
                }
            }
            #endif
        #if WORDCRAFT_MLX
        case .mlx:
            let ready = await mlxRuntime.prepareIfNeeded(allowDownload: false)
            loadTime = start.duration(to: .now).milliseconds
            if case .ready(let name) = ready {
                modelName = name
                candidates = (try? await mlxRuntime.generateCandidates(for: request)) ?? []
            }
        #endif
        }

        try Task.checkCancellation()
        let usedFallback = candidates.isEmpty && backend != .sample
        if candidates.isEmpty {
            candidates = request.parseCandidates(mockModelOutput(for: request.context, backend: backend))
        }
        let metrics = SuggestionMetrics(
            latencyMilliseconds: start.duration(to: .now).milliseconds,
            contextLength: request.context.count,
            suggestionCount: candidates.count,
            modelLoadMilliseconds: loadTime,
            backend: backend,
            modelName: usedFallback ? nil : modelName,
            usedFallback: usedFallback
        )
        #if DEBUG
        print(metrics.summary)
        #endif
        return SuggestionResult(suggestions: candidates, metrics: metrics)
    }

    private func mockModelOutput(for context: String, backend: LocalModelBackend) -> String {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasSuffix("thank") || lowercased.hasSuffix("thanks") {
            #if WORDCRAFT_MLX
            if backend == .mlx { return "you, so, much" }
            #endif
            return "you, again, everyone"
        }

        if lowercased.hasSuffix("see") {
            return "you, what, how"
        }

        if lowercased.hasSuffix("i") {
            #if WORDCRAFT_MLX
            if backend == .mlx { return "need, think, hope" }
            #endif
            return "think, can, will"
        }

        #if WORDCRAFT_MLX
        if backend == .mlx { return "the, to, for" }
        #endif
        return "the, a, and"
    }
}

private extension Duration {
    var milliseconds: Double {
        Double(components.seconds * 1_000) + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
