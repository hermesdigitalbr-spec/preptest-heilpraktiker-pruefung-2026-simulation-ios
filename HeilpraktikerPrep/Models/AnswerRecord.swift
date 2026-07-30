import Foundation

struct AnswerRecord: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    let questionId: String
    let selectedIndex: Int
    let isCorrect: Bool
    let date: Date
    let quizMode: QuizMode
}
