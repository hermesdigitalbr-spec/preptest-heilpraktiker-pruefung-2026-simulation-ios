import Foundation

/// One study session inside a day — a single quiz attempt, as the log shows it.
struct StudySession: Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let mode: QuizMode
    let durationSeconds: Int
    let questionsAnswered: Int
    let correctAnswers: Int
    let completed: Bool

    /// nil when nothing was answered — the log then shows no percentage.
    var accuracyPercent: Int? {
        guard questionsAnswered > 0 else { return nil }
        return Int((Double(correctAnswers) / Double(questionsAnswered) * 100).rounded())
    }
}

/// Um dia de estudo, derivado das tentativas salvas. É o que a garantia dos
/// Termos exige comprovar (tempo, volume e simulados por dia).
struct DailyStudyDay: Equatable, Identifiable {
    let day: Date
    let studySeconds: Int
    let questionsAnswered: Int
    let completedMocks: Int
    /// Newest first, the order the log lists them in.
    let sessions: [StudySession]
    var id: Date { day }
}

enum DailyStudyLog {
    /// Days with study, oldest first.
    static func build(from attempts: [QuizAttempt], calendar: Calendar = .current) -> [DailyStudyDay] {
        Dictionary(grouping: attempts) { calendar.startOfDay(for: $0.startedAt) }
            .map { day, items in
                DailyStudyDay(
                    day: day,
                    studySeconds: items.reduce(0) { $0 + $1.durationSeconds },
                    questionsAnswered: items.reduce(0) { $0 + $1.answers.count },
                    completedMocks: items.filter { $0.mode == .mock && $0.completedAt != nil }.count,
                    sessions: items
                        .sorted { $0.startedAt > $1.startedAt }
                        .map { attempt in
                            StudySession(
                                id: attempt.id,
                                startedAt: attempt.startedAt,
                                mode: attempt.mode,
                                durationSeconds: attempt.durationSeconds,
                                questionsAnswered: attempt.answers.count,
                                correctAnswers: attempt.answers.filter(\.isCorrect).count,
                                completed: attempt.completedAt != nil)
                        })
            }
            .sorted { $0.day < $1.day }
    }

    /// Totals across the whole log, for the page header.
    struct Totals: Equatable {
        var studySeconds = 0
        var days = 0
        var questionsAnswered = 0
        var completedMocks = 0
    }

    static func totals(of days: [DailyStudyDay]) -> Totals {
        days.reduce(into: Totals()) { totals, day in
            totals.studySeconds += day.studySeconds
            totals.days += 1
            totals.questionsAnswered += day.questionsAnswered
            totals.completedMocks += day.completedMocks
        }
    }
}
