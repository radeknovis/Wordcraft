import Foundation

protocol SuggestionEngine: Sendable {
    func suggestions(for request: SuggestionRequest) async throws -> SuggestionResult
}

enum LocalModelBackend: String, CaseIterable, Identifiable, Sendable {
    case foundationModels
    case mlxvlm
    case gemma4

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundationModels:
            return "Apple Foundation Models"
        case .mlxvlm:
            return "MLXVLM"
        case .gemma4:
            return "Gemma 4"
        }
    }

    var supportsOnDeviceInference: Bool {
        switch self {
        case .foundationModels:
            return true
        case .mlxvlm, .gemma4:
            return false
        }
    }

    var usesMLXRuntime: Bool {
        switch self {
        case .foundationModels:
            return false
        case .mlxvlm, .gemma4:
            return true
        }
    }
}

struct MLXModelSelection: Sendable, Equatable {
    let repositoryID: String
    let localDirectoryPath: String

    var isConfigured: Bool {
        !repositoryID.isEmpty || !localDirectoryPath.isEmpty
    }

    var summary: String {
        if !repositoryID.isEmpty {
            return repositoryID
        }

        if !localDirectoryPath.isEmpty {
            return localDirectoryPath
        }

        return "unconfigured"
    }
}

enum WordcraftModelPreferences {
    static let appGroupIdentifier = "group.com.wordcraft.local"
    static let selectedBackendKey = "selectedLocalModelBackend"
    static let mlxRepositoryKey = "mlxRepositoryID"
    static let mlxLocalDirectoryKey = "mlxLocalDirectoryPath"

    static var selectedBackend: LocalModelBackend {
        get {
            guard
                let defaults = UserDefaults(suiteName: appGroupIdentifier),
                let rawValue = defaults.string(forKey: selectedBackendKey),
                let backend = LocalModelBackend(rawValue: rawValue)
            else {
                return .foundationModels
            }

            return backend
        }
        set {
            UserDefaults(suiteName: appGroupIdentifier)?.set(newValue.rawValue, forKey: selectedBackendKey)
        }
    }

    static var selectedMLXModel: MLXModelSelection {
        get {
            let defaults = UserDefaults(suiteName: appGroupIdentifier)
            return MLXModelSelection(
                repositoryID: defaults?.string(forKey: mlxRepositoryKey) ?? "",
                localDirectoryPath: defaults?.string(forKey: mlxLocalDirectoryKey) ?? ""
            )
        }
        set {
            let defaults = UserDefaults(suiteName: appGroupIdentifier)
            defaults?.set(newValue.repositoryID, forKey: mlxRepositoryKey)
            defaults?.set(newValue.localDirectoryPath, forKey: mlxLocalDirectoryKey)
        }
    }
}
