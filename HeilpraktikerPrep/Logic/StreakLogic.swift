import Foundation

enum StreakLogic {
    /// Consecutive days with at least one completed quiz, counting back from
    /// today — or from yesterday when today has no activity yet (an open day
    /// does not break the streak). Frozen days (saved with a streak freeze)
    /// count as active.
    static func currentStreak(activityDates: [Date],
                              frozenDays: [Date] = [],
                              today: Date,
                              calendar: Calendar) -> Int {
        let activeDays = Set((activityDates + frozenDays).map { calendar.startOfDay(for: $0) })
        guard !activeDays.isEmpty else { return 0 }

        let todayStart = calendar.startOfDay(for: today)
        var cursor = todayStart
        if !activeDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  activeDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
