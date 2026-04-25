import Foundation
import UIKit

@MainActor
final class KeyboardController {
    private weak var textDocumentProxy: UITextDocumentProxy?
    private let engine: SuggestionEngine
    private let state: KeyboardState
    private var suggestionTask: Task<Void, Never>?

    init(
        textDocumentProxy: UITextDocumentProxy,
        engine: SuggestionEngine = LocalLLMSuggestionEngine(),
        state: KeyboardState
    ) {
        self.textDocumentProxy = textDocumentProxy
        self.engine = engine
        self.state = state
    }

    func handleKey(_ key: KeyboardKey) {
        switch key {
        case .character(let value):
            textDocumentProxy?.insertText(value)
            scheduleSuggestionsAfterTyping()
        case .space:
            textDocumentProxy?.insertText(" ")
            requestSuggestionsNow()
        case .delete:
            textDocumentProxy?.deleteBackward()
            scheduleSuggestionsAfterTyping()
        case .return:
            textDocumentProxy?.insertText("\n")
            requestSuggestionsNow()
        case .nextKeyboard:
            break
        }
    }

    func insertSuggestion(_ suggestion: String) {
        let prefix = needsLeadingSpace ? " " : ""
        textDocumentProxy?.insertText(prefix + suggestion + " ")
        requestSuggestionsNow()
    }

    func refreshSuggestions() {
        scheduleSuggestionsAfterTyping()
    }

    func cancelSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
        state.isLoadingSuggestions = false
    }

    private var contextBeforeInput: String {
        String((textDocumentProxy?.documentContextBeforeInput ?? "").suffix(160))
    }

    private var needsLeadingSpace: Bool {
        guard let last = contextBeforeInput.last else { return false }
        return !last.isWhitespace && !Self.isPunctuation(last)
    }

    private func scheduleSuggestionsAfterTyping() {
        suggestionTask?.cancel()
        suggestionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            await self?.runSuggestionRequest()
        }
    }

    private func requestSuggestionsNow() {
        suggestionTask?.cancel()
        suggestionTask = Task { [weak self] in
            await self?.runSuggestionRequest()
        }
    }

    private func runSuggestionRequest() async {
        let context = contextBeforeInput
        guard shouldSuggest(for: context) else {
            state.suggestions = []
            state.isLoadingSuggestions = false
            return
        }

        state.isLoadingSuggestions = true
        do {
            let result = try await engine.suggestions(for: SuggestionRequest(context: context))
            guard !Task.isCancelled else { return }
            state.suggestions = Array(result.suggestions.prefix(3))
            state.isLoadingSuggestions = false
        } catch is CancellationError {
            state.isLoadingSuggestions = false
        } catch {
            print("Wordcraft suggestion error: \(error)")
            state.suggestions = []
            state.isLoadingSuggestions = false
        }
    }

    private func shouldSuggest(for context: String) -> Bool {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let last = context.last, last.isWhitespace || Self.isPunctuation(last) {
            return true
        }

        return true
    }

    private static let punctuationCharacters = CharacterSet(charactersIn: ".,!?;:")

    private static func isPunctuation(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { punctuationCharacters.contains($0) }
    }
}
