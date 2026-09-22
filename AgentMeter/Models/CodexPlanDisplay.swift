import Foundation

enum CodexPlanDisplay {
    private static let knownPlans: [String: String] = [
        "plus": "Plus",
        "pro": "Pro",
        "team": "Team",
        "business": "Business",
        "enterprise": "Enterprise",
        "free": "Free",
        "go": "Go",
        "edu": "Edu",
        "prolite": "Pro Lite",
        "self_serve_business_prolite": "Pro"
    ]

    static func formatted(_ planType: String?) -> String? {
        guard let planType else { return nil }
        let key = planType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        if let known = knownPlans[key] {
            return known
        }

        guard key.count <= 12, !key.contains("_"), !key.isEmpty else {
            return nil
        }

        return planType.trimmingCharacters(in: .whitespacesAndNewlines).localizedCapitalized
    }
}
