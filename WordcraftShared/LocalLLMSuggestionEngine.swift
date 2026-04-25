import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

actor LocalLLMSuggestionEngine: SuggestionEngine {
    private var didLoadModel = false
    private var isUsingMockFallback = true
    private var activeBackend: LocalModelBackend = WordcraftModelPreferences.selectedBackend
    private let mlxRuntime = MLXLocalRuntime()

    #if canImport(FoundationModels)
    private var foundationModelsSession: Any?
    #endif

    func suggestions(for request: SuggestionRequest) async throws -> SuggestionResult {
        synchronizeSelectedBackend()

        let start = ContinuousClock.now
        let loadTime = try await loadModelIfNeeded()
        try Task.checkCancellation()

        let suggestions = try await generateCandidates(for: request)
        let latency = start.duration(to: .now).milliseconds
        let metrics = SuggestionMetrics(
            latencyMilliseconds: latency,
            contextLength: request.context.count,
            suggestionCount: suggestions.count,
            modelLoadMilliseconds: loadTime,
            backend: activeBackend,
            usedFallback: isUsingMockFallback
        )
        print(metrics.summary)

        return SuggestionResult(suggestions: suggestions, metrics: metrics)
    }

    func preloadSelectedBackend(
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async -> String {
        synchronizeSelectedBackend()

        do {
            _ = try await loadModelIfNeeded(progressHandler: progressHandler)
            if activeBackend.usesMLXRuntime {
                return await mlxRuntime.prepareIfNeeded(
                    for: activeBackend,
                    progressHandler: progressHandler
                ).summary
            }

            return "Foundation Models backend checked and ready when available."
        } catch {
            return error.localizedDescription
        }
    }

    private func synchronizeSelectedBackend() {
        let selectedBackend = WordcraftModelPreferences.selectedBackend
        guard selectedBackend != activeBackend else { return }

        activeBackend = selectedBackend
        didLoadModel = false
        isUsingMockFallback = true
        #if canImport(FoundationModels)
        foundationModelsSession = nil
        #endif
    }

    private func loadModelIfNeeded(
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Double? {
        guard !didLoadModel else { return nil }

        let start = ContinuousClock.now
        switch activeBackend {
        case .foundationModels:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let model = SystemLanguageModel.default
                if model.isAvailable {
                    let session = LanguageModelSession(
                        model: model,
                        instructions: "Return only concise next-word candidates for a keyboard. Do not explain."
                    )
                    session.prewarm()
                    foundationModelsSession = session
                    isUsingMockFallback = false
                } else {
                    print("Wordcraft local model unavailable: \(model.availability)")
                    isUsingMockFallback = true
                }
            } else {
                isUsingMockFallback = true
            }
            #else
            isUsingMockFallback = true
            #endif
        case .mlxvlm, .gemma4:
            let status = await mlxRuntime.prepareIfNeeded(
                for: activeBackend,
                progressHandler: progressHandler
            )
            print(status.summary)
            if case .ready = status {
                isUsingMockFallback = false
            } else {
                isUsingMockFallback = true
            }
        }

        try Task.checkCancellation()
        didLoadModel = true

        return start.duration(to: .now).milliseconds
    }

    private func generateCandidates(for request: SuggestionRequest) async throws -> [String] {
        if activeBackend.usesMLXRuntime,
           let suggestions = try await mlxRuntime.generateCandidates(for: request, backend: activeBackend) {
            isUsingMockFallback = false
            return suggestions
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let session = foundationModelsSession as? LanguageModelSession {
            return try await generateWithFoundationModels(session: session, request: request)
        }
        #endif

        try await Task.sleep(for: .milliseconds(isUsingMockFallback ? 35 : 0))
        try Task.checkCancellation()

        let rawOutput = mockModelOutput(for: request.context, backend: activeBackend)
        return parseCandidates(rawOutput, limit: request.maxSuggestions)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(
        session: LanguageModelSession,
        request: SuggestionRequest
    ) async throws -> [String] {
        let prompt = """
        Context before cursor:
        \(request.context)

        Return exactly \(request.maxSuggestions) likely next single-word candidates.
        Output comma-separated words only. No punctuation, no numbering, no explanation.
        """
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0.2,
            maximumResponseTokens: 24
        )
        let response = try await session.respond(to: prompt, options: options)
        try Task.checkCancellation()
        let parsed = parseCandidates(response.content, limit: request.maxSuggestions)
        return parsed.isEmpty ? parseCandidates(mockModelOutput(for: request.context, backend: activeBackend), limit: request.maxSuggestions) : parsed
    }
    #endif

    private func mockModelOutput(for context: String, backend: LocalModelBackend) -> String {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        if lowercased.hasSuffix("thank") || lowercased.hasSuffix("thanks") {
            return backend == .gemma4 ? "you, so, much" : "you, again, everyone"
        }

        if lowercased.hasSuffix("see") {
            return backend == .mlxvlm ? "this, that, more" : "you, what, how"
        }

        if lowercased.hasSuffix("i") {
            switch backend {
            case .foundationModels:
                return "think, can, will"
            case .mlxvlm:
                return "see, know, want"
            case .gemma4:
                return "need, think, hope"
            }
        }

        switch backend {
        case .foundationModels:
            return "the, a, and"
        case .mlxvlm:
            return "look, make, take"
        case .gemma4:
            return "the, to, for"
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

private extension Duration {
    var milliseconds: Double {
        Double(components.seconds * 1_000) + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
