import Foundation

/// Decides whether to spend a "streak freeze" to bridge a single missed day,
/// so one slip doesn't wipe out a long streak. Pure: it only computes the
/// decision; the caller persists the result.
enum StreakMaintainer {
    struct Decision: Equatable {
        let dayToFreeze: Date
        let freezesRemaining: Int
    }

    /// Returns a freeze decision when yesterday was missed but the streak was
    /// alive the day before — and a freeze is available. Returns nil when
    /// there's nothing to protect (streak intact, already broken by >1 day,
    /// or no freezes left).
    static func decide(activityDays: Set<Date>,
                       frozenDays: Set<Date>,
                       freezes: Int,
                       today: Date,
                       calendar: Calendar = .current) -> Decision? {
        guard freezes > 0 else { return nil }
        let active = activityDays.union(frozenDays).map { calendar.startOfDay(for: $0) }
        let activeSet = Set(active)
        let todayStart = calendar.startOfDay(for: today)

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let dayBefore = calendar.date(byAdding: .day, value: -2, to: todayStart) else { return nil }

        // Yesterday already counts (practiced or already frozen) → nothing to do.
        guard !activeSet.contains(yesterday) else { return nil }
        // Only bridge a SINGLE-day gap: the streak must have been alive at day-2.
        guard activeSet.contains(dayBefore) else { return nil }

        return Decision(dayToFreeze: yesterday, freezesRemaining: freezes - 1)
    }
}
