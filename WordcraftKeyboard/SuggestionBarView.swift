import SwiftUI

struct SuggestionBarView: View {
    let suggestions: [String]
    let isLoading: Bool
    let onSuggestionTapped: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            if suggestions.isEmpty {
                Text(isLoading ? "Thinking..." : "Wordcraft")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSuggestionTapped(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .background(.regularMaterial)
    }
}
