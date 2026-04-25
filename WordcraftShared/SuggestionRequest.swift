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
