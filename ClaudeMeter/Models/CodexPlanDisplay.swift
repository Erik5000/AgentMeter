import Foundation

enum CodexPlanDisplay {
    static func formatted(_ planType: String?) -> String? {
        guard let planType else { return nil }
        let words = planType
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        return words
            .map { $0.localizedCapitalized }
            .joined(separator: " ")
    }
}
