import SwiftUI

struct KeyboardSetupInstructionsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your typing stays on this device.", systemImage: "lock.shield")
                    Label("Next-word suggestions run on device.", systemImage: "text.word.spacing")
                    Label("The keyboard runs with Full Access off.", systemImage: "wifi.slash")
                } header: {
                    Text("Privacy")
                }

                Section {
                    InstructionRow(number: 1, text: "Open Settings.")
                    InstructionRow(number: 2, text: "Go to General > Keyboard > Keyboards.")
                    InstructionRow(number: 3, text: "Tap Add New Keyboard.")
                    InstructionRow(number: 4, text: "Choose Wordcraft.")
                    InstructionRow(number: 5, text: "In a normal text field, hold the globe and choose Wordcraft.")
                } header: {
                    Text("Enable Wordcraft Keyboard")
                }
            }
            .navigationTitle("Wordcraft")
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())

            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    KeyboardSetupInstructionsView()
}
