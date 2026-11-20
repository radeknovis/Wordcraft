import Foundation

struct SuggestionRequest: Sendable, Equatable {
    let context: String
    let maxSuggestions: Int
    let createdAt: ContinuousClock.Instant

    init(context: String, maxSuggestions: Int = 3, createdAt: ContinuousClock.Instant = .now) {
        self.context = String(context.suffix(160))
        self.maxSuggestions = max(1, min(maxSuggestions, 3))
        self.createdAt = createdAt
    }
}

extension SuggestionRequest {
    static let candidateSeparators = CharacterSet(charactersIn: ",\n;|")
    private static let trimmedCharacters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'[]0123456789.-"))

    var prompt: String {
        """
        Context before cursor:
        \(context)

        Return exactly \(maxSuggestions) likely next single-word candidates.
        Output comma-separated words only. No punctuation, no numbering, no explanation.
        """
    }

    func parseCandidates(_ rawOutput: String) -> [String] {
        rawOutput
            .components(separatedBy: Self.candidateSeparators)
            .map { $0.trimmingCharacters(in: Self.trimmedCharacters) }
            .filter { candidate in
                candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
                    && candidate.rangeOfCharacter(from: .letters) != nil
            }
            .reduce(into: [String]()) { partialResult, candidate in
                guard partialResult.count < maxSuggestions else { return }
                guard !partialResult.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) else { return }
                partialResult.append(candidate)
            }
    }
}
