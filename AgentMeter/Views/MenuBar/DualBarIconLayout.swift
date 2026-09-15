import Foundation

enum DualBarIconLayout: Equatable {
    case loading
    case idle
    case singleColumn
    case pairedColumns

    static func resolve(
        isLoading: Bool,
        showsCodex: Bool,
        hasProviderValues: Bool
    ) -> DualBarIconLayout {
        if isLoading {
            return .loading
        }
        if showsCodex && !hasProviderValues {
            return .idle
        }
        if showsCodex {
            return .pairedColumns
        }
        return .singleColumn
    }
}
