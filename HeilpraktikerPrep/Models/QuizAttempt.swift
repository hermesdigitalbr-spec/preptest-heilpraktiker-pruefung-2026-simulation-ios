import Foundation

struct QuizAttempt: Codable, Equatable, Identifiable {
    let id: UUID
    let mode: QuizMode
    let startedAt: Date
    let completedAt: Date?
    let answers: [AnswerRecord]
    let durationSeconds: Int
}
