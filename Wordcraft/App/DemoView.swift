import SwiftUI

struct DemoView: View {

    @AppStorage(
        WordcraftModelPreferences.selectedBackendKey,
        store: UserDefaults(suiteName: WordcraftModelPreferences.appGroupIdentifier)
    )
    private var selectedBackendRawValue = LocalModelBackend.sample.rawValue
    #if WORDCRAFT_MLX
    @AppStorage(
        WordcraftModelPreferences.mlxRepositoryKey,
        store: UserDefaults(suiteName: WordcraftModelPreferences.appGroupIdentifier)
    )
    private var mlxRepositoryID = ""
    @AppStorage(
        WordcraftModelPreferences.mlxLocalDirectoryKey,
        store: UserDefaults(suiteName: WordcraftModelPreferences.appGroupIdentifier)
    )
    private var mlxLocalDirectoryPath = ""
    @State private var modelStatusMessage: String?
    @State private var downloadProgress: Double?
    @State private var isLoadingModel = false
    #endif
    @State private var text = "i "
    @State private var engine = LocalLLMSuggestionEngine()
    @State private var isGenerating = false
    @FocusState private var editingText: Bool
    @State private var suggestionResult: SuggestionResult?

    var body: some View {
        NavigationStack {
            Form {
                Section("Model Backend") {
                    Picker("Backend", selection: Binding(get: { selectedBackend.rawValue }, set: { selectedBackendRawValue = $0 })) {
                        ForEach(LocalModelBackend.allCases) { backend in
                            Text(backend.displayName).tag(backend.rawValue)
                        }
                    }

                    Text(backendDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .disabled(isBusy)

                #if WORDCRAFT_MLX
                if selectedBackend == .mlx {
                    Section("MLX Model Settings") {
                        TextField("Repository ID", text: $mlxRepositoryID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Local Model Folder", text: $mlxLocalDirectoryPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button(isLoadingModel ? "Loading Model..." : "Download / Load Model") {
                            isLoadingModel = true
                            downloadProgress = 0
                            Task {
                                let status = await engine.prepareMLXModel { progress in
                                    Task { @MainActor in
                                        downloadProgress = min(1, max(0, progress.fractionCompleted))
                                    }
                                }
                                modelStatusMessage = status
                                isLoadingModel = false
                            }
                        }
                        .disabled(isLoadingModel)

                        Text("Leave both fields empty for Gemma 4 E2B, or enter a compatible Hugging Face repository ID. A local folder takes precedence.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Downloads go into the shared App Group. The keyboard reads cached files and uses built-in suggestions if the model is unavailable.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let modelStatusMessage {
                            Text(modelStatusMessage)
                                .font(.footnote)
                        }

                        if isLoadingModel {
                            ProgressView(value: downloadProgress)
                        }
                    }
                    .disabled(isBusy)
                }
                #endif

                Section("Try Suggestions") {
                    TextField("Text before the cursor", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($editingText)
                        .disabled(isBusy)

                    Button(isGenerating ? "Generating…" : "Generate suggestions") {
                        editingText = false
                        isGenerating = true
                        Task {
                            defer { isGenerating = false }
                            suggestionResult = try? await engine.suggestions(for: .init(context: text))
                        }
                    }
                    .disabled(isBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let suggestionResult {
                    Section("Suggestions") {
                        ForEach(suggestionResult.suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                        }

                        let metrics = suggestionResult.metrics
                        Text(metrics.usedFallback ? "Source: Built-in fallback" : "Source: \(metrics.modelName ?? metrics.backend.displayName)")
                            .font(.footnote)
                        Text("Latency: \(metrics.latencyMilliseconds, specifier: "%.1f") ms")
                            .font(.footnote.monospacedDigit())
                    }
                }
            }
            .navigationTitle("Wordcraft Demo")
            .onChange(of: text) { suggestionResult = nil }
            #if WORDCRAFT_MLX
            .onChange(of: MLXModelSelection(repositoryID: mlxRepositoryID, localDirectoryPath: mlxLocalDirectoryPath)) {
                suggestionResult = nil
                modelStatusMessage = nil
                downloadProgress = nil
            }
            #endif
            .onChange(of: selectedBackendRawValue) {
                suggestionResult = nil
                #if WORDCRAFT_MLX
                modelStatusMessage = nil
                #endif
            }
        }
    }

    private var selectedBackend: LocalModelBackend {
        LocalModelBackend(rawValue: selectedBackendRawValue) ?? .sample
    }

    private var backendDescription: String {
        switch selectedBackend {
        case .sample: return "Try “i ” for three repeatable next words."
        case .foundationModels: return "Uses Apple Intelligence when available. Each result shows its source."
        #if WORDCRAFT_MLX
        case .mlx: return "Prepare the model on a physical device before generating suggestions."
        #endif
        }
    }

    private var isBusy: Bool {
        #if WORDCRAFT_MLX
        isGenerating || isLoadingModel
        #else
        isGenerating
        #endif
    }
}

#Preview {
    DemoView()
}
