import Foundation

enum QuizMode: String, Codable, CaseIterable, Equatable {
    case daily
    case quick10
    case timed
    case missed
    case collected
    case mock
    case custom
    case review
}

/// How answer feedback is delivered during a quiz.
enum FeedbackMode: String, Codable, CaseIterable, Equatable {
    /// Instant green/red + explanation after each answer.
    case learning
    /// Feedback only on the results screen.
    case quick
    /// Exam simulation: no feedback, timed.
    case mock
}
