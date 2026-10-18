import Foundation

/// Deterministic RNG (splitmix64) so selections are reproducible in tests
/// and stable for "daily questions" seeded by the calendar day.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum QuestionSelector {
    /// Random sample without replacement.
    ///
    /// When `quicksDoneCount < 3` and the pool has image questions, injects at
    /// least one (preferring unseen ones) so first-time users meet the
    /// illustrated questions right away, never two images in a row and never
    /// at slot 0. A pool with no images behaves exactly like a plain sample.
    static func quick(
        from pool: [Question],
        count: Int,
        seed: UInt64,
        quicksDoneCount: Int = .max,
        seenImageQuestionIds: Set<String> = []
    ) -> [Question] {
        var rng = SeededGenerator(seed: seed)
        let imagePool = pool.filter(hasImage)
        guard quicksDoneCount < 3, !imagePool.isEmpty, count > 1 else {
            let sample = Array(pool.shuffled(using: &rng).prefix(count))
            return sample.contains(where: hasImage) ? deconflictImages(in: sample, using: &rng) : sample
        }
        let textPool = pool.filter { !hasImage($0) }
        let candidates = imagePool.filter { !seenImageQuestionIds.contains($0.id) }
        let forced = (candidates.shuffled(using: &rng).first ?? imagePool.shuffled(using: &rng).first)!
        var filler = textPool + imagePool.filter { $0.id != forced.id }
        filler.shuffle(using: &rng)
        return deconflictImages(in: [forced] + Array(filler.prefix(count - 1)), using: &rng)
    }

    static func hasImage(_ question: Question) -> Bool {
        question.imageName != nil || question.imageURL != nil
    }

    /// Rearranges so no two image-bearing questions are adjacent and none sits
    /// at slot 0. Builds [T, I, T, I, …, T…] — one text before each image.
    private static func deconflictImages(in selected: [Question],
                                         using rng: inout SeededGenerator) -> [Question] {
        var images = selected.filter(hasImage).shuffled(using: &rng)
        var texts = selected.filter { !hasImage($0) }.shuffled(using: &rng)

        guard images.count >= 2 else {
            var shuffled = selected.shuffled(using: &rng)
            if let first = shuffled.first, hasImage(first), shuffled.count > 1 {
                shuffled.swapAt(0, Int.random(in: 1..<shuffled.count, using: &rng))
            }
            return shuffled
        }

        var result: [Question] = []
        while !images.isEmpty {
            if !texts.isEmpty { result.append(texts.removeFirst()) }
            result.append(images.removeFirst())
        }
        result.append(contentsOf: texts)
        return result
    }

    /// Ensures ≥1 image question in `selected` when `attemptsDone < 3`, for
    /// every quiz mode. No-op when the pool has no image questions.
    static func injectImageIfNeeded(
        into selected: [Question],
        pool: [Question],
        attemptsDone: Int,
        seenImageIds: Set<String>,
        seed: UInt64? = nil
    ) -> [Question] {
        guard attemptsDone < 3, selected.count > 1 else { return selected }
        var rng = SeededGenerator(seed: seed ?? .random(in: .min ... .max))

        if selected.contains(where: hasImage) {
            return deconflictImages(in: selected, using: &rng)
        }
        let imagePool = pool.filter(hasImage)
        guard !imagePool.isEmpty else { return selected }

        let selectedIds = Set(selected.map(\.id))
        let candidates = imagePool.filter { !seenImageIds.contains($0.id) && !selectedIds.contains($0.id) }
        guard let forced = candidates.shuffled(using: &rng).first ?? imagePool.shuffled(using: &rng).first else {
            return selected
        }
        var result = selected
        result[result.count - 1] = forced
        return deconflictImages(in: result, using: &rng)
    }

    /// Daily set: prefers unanswered questions and biases toward the user's
    /// weak subjects. `weakSubjectIds` is ordered weakest-first, so a higher
    /// `weakRatio` pulls proportionally more from the most-deficient topics
    /// (the caller raises the ratio when the exam is near and odds are low).
    static func daily(from pool: [Question],
                      weakSubjectIds: [String],
                      answeredIds: Set<String>,
                      count: Int,
                      weakRatio: Double = 0.6,
                      seed: UInt64) -> [Question] {
        var rng = SeededGenerator(seed: seed)
        let fresh = pool.filter { !answeredIds.contains($0.id) }
        let base = fresh.count >= count ? fresh : pool

        let weakSet = Set(weakSubjectIds)
        // Build the weak pool in subject-priority order (weakest subject first).
        var weak: [Question] = []
        for subjectId in weakSubjectIds {
            weak.append(contentsOf: base.filter { $0.subjectId == subjectId }.shuffled(using: &rng))
        }
        let rest = base.filter { !weakSet.contains($0.subjectId) }.shuffled(using: &rng)

        let ratio = Swift.max(0, Swift.min(0.9, weakRatio))
        let weakTarget = weakSubjectIds.isEmpty
            ? 0
            : Swift.min(weak.count, Int((Double(count) * ratio).rounded()))
        var selected = Array(weak.prefix(weakTarget))
        selected.append(contentsOf: rest.prefix(count - selected.count))
        if selected.count < count {
            selected.append(contentsOf: weak.dropFirst(weakTarget).prefix(count - selected.count))
        }
        return selected.shuffled(using: &rng)
    }

    /// Questions whose most recent answer was wrong (not yet re-answered correctly).
    static func missed(from pool: [Question], history: [AnswerRecord]) -> [Question] {
        var latestByQuestion: [String: AnswerRecord] = [:]
        for answer in history.sorted(by: { $0.date < $1.date }) {
            latestByQuestion[answer.questionId] = answer
        }
        let missedIds = Set(latestByQuestion.values.filter { !$0.isCorrect }.map(\.questionId))
        return pool.filter { missedIds.contains($0.id) }
    }

    /// Spaced-repetition session: questions due for review, most urgent
    /// first, capped at `count`. Empty when nothing is due.
    static func review(from pool: [Question], history: [AnswerRecord],
                       count: Int, now: Date = .now) -> [Question] {
        let byId = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let due = SRSScheduler.dueCards(history: history, now: now)
        return due.compactMap { byId[$0.questionId] }.prefix(count).map { $0 }
    }

    /// Exam simulation: proportional distribution across subjects.
    static func mock(from pool: [Question], count: Int, seed: UInt64) -> [Question] {
        var rng = SeededGenerator(seed: seed)
        let bySubject = Dictionary(grouping: pool, by: \.subjectId)
        let total = pool.count
        guard total > 0, count > 0 else { return [] }

        var selected: [Question] = []
        for (_, questions) in bySubject.sorted(by: { $0.key < $1.key }) {
            let share = Int((Double(questions.count) / Double(total) * Double(count)).rounded(.down))
            selected.append(contentsOf: questions.shuffled(using: &rng).prefix(share))
        }
        // Fill rounding remainder from the leftover pool.
        if selected.count < count {
            let chosen = Set(selected.map(\.id))
            let remainder = pool.filter { !chosen.contains($0.id) }.shuffled(using: &rng)
            selected.append(contentsOf: remainder.prefix(count - selected.count))
        }
        return Array(selected.shuffled(using: &rng).prefix(count))
    }

    /// User-built session filtered to chosen subjects.
    static func custom(from pool: [Question], subjectIds: Set<String>, count: Int, seed: UInt64) -> [Question] {
        let filtered = pool.filter { subjectIds.contains($0.subjectId) }
        return quick(from: filtered, count: count, seed: seed)
    }
}
