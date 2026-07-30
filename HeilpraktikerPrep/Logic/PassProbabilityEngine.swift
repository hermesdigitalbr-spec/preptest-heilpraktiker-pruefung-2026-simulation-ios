import Foundation

/// Estimates the user's probability of passing the real written exam, based
/// on recent practice accuracy versus the pack's pass threshold. The number
/// is a calibrated heuristic — not a statistical guarantee — and is meant to
/// motivate consistent practice rather than predict the actual outcome.
///
/// Curve (recent accuracy `p`, pass threshold `t`, both 0…1):
///
///   raw = 1 / (1 + e^(-k * (p - t)))     // logistic centered on the threshold
///   prob = 0.5 + (raw - 0.5) * damping   // pulled toward 50% when sample is thin
///
/// With k = 10 the steepness lines up with real intuition: at the threshold
/// the probability is 50%, +10 points of accuracy makes it ~73%, −10 points
/// ~27%. Damping prevents "98% probable" reads after 5 lucky answers.
enum PassProbabilityEngine {
    /// Only the last `recentWindow` answers feed the accuracy reading, so a
    /// long history of past mistakes doesn't keep dragging the estimate down
    /// once the user improves.
    static let recentWindow = 60
    /// Below this sample size the estimate is dampened toward 50% (uncertain).
    static let confidentSample = 30
    /// Fewer than this many answers → return nil (not enough signal to show a number).
    static let minimumSample = 15
    /// Logistic steepness — higher = more sensitive to accuracy moves.
    static let steepness = 10.0

    /// - Parameter passThresholdPercent: the pack's mock-exam pass mark, e.g. 80.
    /// - Returns: probability 1…99, or nil when the sample is too small to be meaningful.
    static func evaluate(answers: [AnswerRecord],
                         passThresholdPercent: Int) -> Int? {
        guard answers.count >= minimumSample else { return nil }
        let chronological = answers.sorted { $0.date < $1.date }
        let recent = chronological.suffix(recentWindow)
        let p = Double(recent.filter(\.isCorrect).count) / Double(recent.count)
        let t = Double(max(0, min(100, passThresholdPercent))) / 100

        let raw = 1.0 / (1.0 + exp(-steepness * (p - t)))
        let damping = min(1.0, Double(answers.count) / Double(confidentSample))
        let pulled = 0.5 + (raw - 0.5) * damping
        let clamped = min(0.99, max(0.15, pulled))
        return Int((clamped * 100).rounded())
    }
}
