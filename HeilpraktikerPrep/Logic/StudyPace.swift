import Foundation

/// Urgency band derived from the days left until the exam. Drives the badge
/// shown right after the user picks a date — the urgency is *theirs*, never a
/// countdown we invented.
enum StudyPace: Equatable {
    case sprint, active, steady

    static let sprintMaxDays = 7
    static let activeMaxDays = 30

    static func forDays(_ days: Int) -> StudyPace {
        if days <= sprintMaxDays { return .sprint }
        if days <= activeMaxDays { return .active }
        return .steady
    }
}

/// Projected readiness from "today" to exam day, used by the pre-paywall
/// plan card. Starting point comes from the self-reported level; the curve
/// is an ease-in-out towards ~95% — a promise of the plan, not a measurement.
enum ReadinessForecast {
    /// Where the curve lands on exam day. The plan's promise, not a measurement —
    /// the screen labels it "Nossa previsão" for that reason.
    static let target = 1.0

    static func baseline(for level: UserProfile.Level?) -> Double {
        switch level {
        case .none, .newbie: 0.12
        case .skilled: 0.32
        case .master: 0.55
        case .expert: 0.70
        }
    }

    static func points(startingAt level: UserProfile.Level?, count: Int) -> [Double] {
        guard count > 1 else { return [baseline(for: level)] }
        let start = baseline(for: level)
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            return start + (target - start) * eased
        }
    }
}
