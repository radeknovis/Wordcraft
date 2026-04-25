import Foundation

@MainActor
final class KeyboardState: ObservableObject {
    @Published var suggestions: [String] = []
    @Published var isLoadingSuggestions = false
}
