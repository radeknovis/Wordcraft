import Foundation

struct SuggestionMetrics: Sendable, Equatable {
    let latencyMilliseconds: Double
    let contextLength: Int
    let suggestionCount: Int
    let modelLoadMilliseconds: Double?
    let backend: LocalModelBackend
    let usedFallback: Bool
    
    var summary: String {
        let loadText = modelLoadMilliseconds.map { String(format: "%.1f ms", $0) } ?? "already loaded"
        return "Wordcraft metrics backend=\(backend.rawValue) fallback=\(usedFallback) latency=\(String(format: "%.1f", latencyMilliseconds))ms contextLength=\(contextLength) suggestions=\(suggestionCount) modelLoad=\(loadText)"
    }
}
