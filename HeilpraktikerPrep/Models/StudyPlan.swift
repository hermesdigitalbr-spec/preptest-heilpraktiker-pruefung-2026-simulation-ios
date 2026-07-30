import Foundation

struct StudyPlan: Codable, Equatable {
    let questionsPerDay: Int
    let daysUntilExam: Int?
}
