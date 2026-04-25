import Foundation

struct SuggestionResult: Sendable, Equatable {
    let suggestions: [String]
    let metrics: SuggestionMetrics
}
