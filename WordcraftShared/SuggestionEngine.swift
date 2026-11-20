import Foundation

protocol SuggestionEngine: Sendable {
    func suggestions(for request: SuggestionRequest) async throws -> SuggestionResult
}

enum LocalModelBackend: String, CaseIterable, Identifiable, Sendable {
    case sample
    case foundationModels
    #if WORDCRAFT_MLX
    case mlx = "gemma4"
    #endif

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sample: return "Built-in demo"
        case .foundationModels: return "Apple Foundation Models"
        #if WORDCRAFT_MLX
        case .mlx: return "MLX"
        #endif
        }
    }
}

#if WORDCRAFT_MLX
struct MLXModelSelection: Sendable, Equatable {
    let repositoryID: String
    let localDirectoryPath: String
}
#endif

enum WordcraftModelPreferences {
    static let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "WordcraftAppGroup") as? String
    static let selectedBackendKey = "selectedLocalModelBackend"
    static let mlxRepositoryKey = "mlxRepositoryID"
    static let mlxLocalDirectoryKey = "mlxLocalDirectoryPath"
    private static let defaults = UserDefaults(suiteName: appGroupIdentifier)

    static var selectedBackend: LocalModelBackend {
        defaults?.string(forKey: selectedBackendKey).flatMap(LocalModelBackend.init(rawValue:)) ?? .sample
    }

    #if WORDCRAFT_MLX
    static var selectedMLXModel: MLXModelSelection {
        MLXModelSelection(
            repositoryID: defaults?.string(forKey: mlxRepositoryKey) ?? "",
            localDirectoryPath: defaults?.string(forKey: mlxLocalDirectoryKey) ?? ""
        )
    }
    #endif
}
