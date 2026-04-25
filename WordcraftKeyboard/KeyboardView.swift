import SwiftUI

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState
    let onKeyTapped: (KeyboardKey) -> Void
    let onSuggestionTapped: (String) -> Void
    let onNextKeyboardTapped: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            SuggestionBarView(
                suggestions: state.suggestions,
                isLoading: state.isLoadingSuggestions,
                onSuggestionTapped: onSuggestionTapped
            )

            VStack(spacing: 7) {
                ForEach(Array(KeyboardLayout.qwertyRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 5) {
                        if index == 1 {
                            Spacer(minLength: 14)
                        } else if index == 2 {
                            Spacer(minLength: 32)
                        }

                        ForEach(row, id: \.self) { key in
                            keyButton(for: key)
                        }

                        if index == 1 {
                            Spacer(minLength: 14)
                        } else if index == 2 {
                            Spacer(minLength: 32)
                        }
                    }
                }

                HStack(spacing: 5) {
                    controlButton(.nextKeyboard, width: 46)
                    controlButton(.space)
                    controlButton(.delete, width: 72)
                    controlButton(.return, width: 72)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemGray4))
    }

    private func keyButton(for key: KeyboardKey) -> some View {
        Button {
            onKeyTapped(key)
        } label: {
            Text(key.title)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(KeyButtonStyle(background: .white))
    }

    private func controlButton(_ key: KeyboardKey, width: CGFloat? = nil) -> some View {
        Button {
            if key == .nextKeyboard {
                onNextKeyboardTapped()
            } else {
                onKeyTapped(key)
            }
        } label: {
            label(for: key)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: width == nil ? .infinity : nil, minHeight: 42)
                .frame(width: width)
        }
        .buttonStyle(KeyButtonStyle(background: Color(uiColor: .systemGray5)))
    }

    @ViewBuilder
    private func label(for key: KeyboardKey) -> some View {
        switch key {
        case .delete:
            Image(systemName: "delete.left")
                .accessibilityLabel("Delete")
        case .nextKeyboard:
            Image(systemName: "globe")
                .accessibilityLabel("Next Keyboard")
        default:
            Text(key.title)
        }
    }
}

private struct KeyButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(background.opacity(configuration.isPressed ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
    }
}
