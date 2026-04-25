import SwiftUI
import WordcraftKeyboard

struct DemoView: View {

    @AppStorage(
        WordcraftModelPreferences.selectedBackendKey,
        store: UserDefaults(suiteName: WordcraftModelPreferences.appGroupIdentifier)
    )
    private var selectedBackendRawValue = LocalModelBackend.foundationModels.rawValue
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
    @State private var text: String = ""
    @State private var errorMessage: String?
    @State private var engine = LocalLLMSuggestionEngine()
    @State private var modelStatusMessage: String?
    @State private var downloadProgress: Double?
    @State private var downloadCompletedBytes: Int64 = 0
    @State private var downloadTotalBytes: Int64 = 0
    @State private var downloadStartDate: Date?
    @State private var estimatedRemainingTime: TimeInterval?
    @State private var isLoadingModel = false
    @State private var suggestionResult: SuggestionResult?

    var body: some View {
        NavigationStack {
            Form {
                Section("Model Backend") {
                    Picker("Backend", selection: $selectedBackendRawValue) {
                        ForEach(LocalModelBackend.allCases) { backend in
                            Text(backend.displayName).tag(backend.rawValue)
                        }
                    }

                    Text(selectedBackend.supportsOnDeviceInference ? "Uses on-device Foundation Models when available." : "Selection saved now. Requests use mock fallback until this runtime is integrated.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if selectedBackend.usesMLXRuntime {
                    Section("MLX Model Settings") {
                        TextField("Repository ID", text: $mlxRepositoryID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Local Model Folder", text: $mlxLocalDirectoryPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button(isLoadingModel ? "Loading Model..." : "Download / Load Model") {
                            isLoadingModel = true
                            downloadStartDate = Date()
                            downloadProgress = 0
                            downloadCompletedBytes = 0
                            downloadTotalBytes = 0
                            estimatedRemainingTime = nil
                            Task {
                                let status = await engine.preloadSelectedBackend { progress in
                                    Task { @MainActor in
                                        updateDownloadProgress(progress)
                                    }
                                }
                                await MainActor.run {
                                    modelStatusMessage = status
                                    isLoadingModel = false
                                }
                            }
                        }
                        .disabled(isLoadingModel)

                        Text("Leave both fields empty to use the built-in Gemma 4 default. Set a repository ID to fetch from Hugging Face, or set a local folder to load files already on disk.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("Download in the host app first. The keyboard extension can reuse the prepared selection, but it should not be the first place that fetches model files.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let modelStatusMessage {
                            Text(modelStatusMessage)
                                .font(.footnote)
                        }

                        if isLoadingModel || downloadTotalBytes > 0 || downloadCompletedBytes > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: downloadProgress ?? 0)

                                Text(downloadSummary)
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)

                                if let estimatedRemainingTime {
                                    Text("ETA \(formatDuration(estimatedRemainingTime))")
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Try Suggestions") {
                    TextField("Test textfield", text: $text)

                    Button("Generate suggestions") {
                        Task {
                            do {
                                suggestionResult = try await engine.suggestions(for: .init(context: text))
                                errorMessage = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section("Error") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let suggestionResult {
                    Section("Suggestions") {
                        ForEach(suggestionResult.suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                        }

                        Text(suggestionResult.metrics.summary)
                    }
                }
            }
            .navigationTitle("Demo")
        }
    }

    private var selectedBackend: LocalModelBackend {
        LocalModelBackend(rawValue: selectedBackendRawValue) ?? .foundationModels
    }

    private var downloadSummary: String {
        let percent = Int((downloadProgress ?? 0) * 100)
        let completed = ByteCountFormatter.string(fromByteCount: downloadCompletedBytes, countStyle: .file)
        let total = downloadTotalBytes > 0
            ? ByteCountFormatter.string(fromByteCount: downloadTotalBytes, countStyle: .file)
            : "unknown"
        return "\(percent)% • \(completed) / \(total)"
    }

    @MainActor
    private func updateDownloadProgress(_ progress: Progress) {
        downloadProgress = progress.fractionCompleted.isFinite ? progress.fractionCompleted : nil
        downloadCompletedBytes = progress.completedUnitCount
        downloadTotalBytes = progress.totalUnitCount

        guard
            let start = downloadStartDate,
            progress.completedUnitCount > 0,
            progress.totalUnitCount > progress.completedUnitCount
        else {
            estimatedRemainingTime = nil
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else {
            estimatedRemainingTime = nil
            return
        }

        let bytesPerSecond = Double(progress.completedUnitCount) / elapsed
        guard bytesPerSecond > 0 else {
            estimatedRemainingTime = nil
            return
        }

        let remainingBytes = Double(progress.totalUnitCount - progress.completedUnitCount)
        estimatedRemainingTime = remainingBytes / bytesPerSecond
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

#Preview {
    DemoView()
}
