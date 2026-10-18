import Foundation

/// Pure state machine for one quiz run. UI layers observe a copy of this via
/// their own @Observable wrapper; all transitions are explicit mutating funcs.
struct QuizSession: Equatable {
    let mode: QuizMode
    let feedback: FeedbackMode
    /// Questions in the form the UI sees — when a `shuffleSeed` was provided
    /// the choices (and `correctIndex`) have been re-ordered per session, so
    /// the same question appears in different positions on repeat exposure.
    let questions: [Question]
    /// Per-question map from displayed choice index back to the index in the
    /// original questions.json. nil = choices were not shuffled. Used at
    /// `submitAnswer` time so AnswerRecord keeps storing CANONICAL indices,
    /// which lets Review highlight the right "user picked" choice on the
    /// untouched Question loaded from the pack.
    private let displayedToOriginal: [[Int]]?

    private(set) var currentIndex: Int = 0
    private(set) var answers: [AnswerRecord] = []
    private(set) var isCurrentRevealed: Bool = false
    private(set) var isFinished: Bool = false

    init(mode: QuizMode, feedback: FeedbackMode, questions: [Question],
         shuffleSeed: UInt64? = nil) {
        self.mode = mode
        self.feedback = feedback
        if let seed = shuffleSeed {
            let (shuffled, maps) = Self.shuffleChoices(questions, seed: seed)
            self.questions = shuffled
            self.displayedToOriginal = maps
        } else {
            self.questions = questions
            self.displayedToOriginal = nil
        }
        self.isFinished = self.questions.isEmpty
    }

    var currentQuestion: Question? {
        guard !isFinished, questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    /// Whether the answer given to the current question was right.
    var isCurrentCorrect: Bool {
        answers.first { $0.questionId == currentQuestion?.id }?.isCorrect ?? false
    }

    var hasAnsweredCurrent: Bool {
        guard let current = currentQuestion else { return false }
        return answers.contains { $0.questionId == current.id }
    }

    /// The user's selection for the current question, expressed as the index
    /// the UI is displaying (post-shuffle). `AnswerRecord.selectedIndex` is
    /// stored in CANONICAL form so Review/stats are stable across sessions;
    /// the choice list on screen is the shuffled order, so the UI must
    /// translate back when highlighting "you picked this".
    var displayedSelectedIndexForCurrent: Int? {
        guard let current = currentQuestion,
              let record = answers.first(where: { $0.questionId == current.id })
        else { return nil }
        guard let map = displayedToOriginal?[currentIndex] else { return record.selectedIndex }
        return map.firstIndex(of: record.selectedIndex)
    }

    var correctCount: Int { answers.filter(\.isCorrect).count }

    var scorePercent: Int { ScoringLogic.scorePercent(correct: correctCount, total: answers.count) }

    /// Records the answer for the current question. Returns whether it was
    /// correct. Repeated answers to the same question are ignored.
    @discardableResult
    mutating func submitAnswer(_ index: Int, date: Date) -> Bool {
        guard let question = currentQuestion, !hasAnsweredCurrent,
              question.choices.indices.contains(index) else { return false }
        let isCorrect = index == question.correctIndex
        // Translate the displayed pick back to its position in the original
        // pack-supplied question so downstream consumers (Review, stats) see
        // canonical indices regardless of any per-session shuffle.
        let recordedIndex = displayedToOriginal?[currentIndex][index] ?? index
        answers.append(AnswerRecord(
            id: UUID(),
            questionId: question.id,
            selectedIndex: recordedIndex,
            isCorrect: isCorrect,
            date: date,
            quizMode: mode
        ))
        if feedback == .learning {
            isCurrentRevealed = true
        }
        return isCorrect
    }

    /// Moves to the next question, or finishes after the last one.
    /// Outside mock mode the current question must be answered first.
    mutating func advance() {
        guard !isFinished else { return }
        if feedback != .mock && !hasAnsweredCurrent { return }
        isCurrentRevealed = false
        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            isFinished = true
        }
    }

    // MARK: - Choice shuffling

    /// Returns a copy of each question whose `choices` (and `correctIndex`)
    /// have been deterministically shuffled, plus per-question maps from the
    /// new (displayed) order back to the original index.
    private static func shuffleChoices(_ questions: [Question], seed: UInt64)
        -> ([Question], [[Int]]) {
        var rng = SeededGenerator(seed: seed)
        var newQuestions: [Question] = []
        var maps: [[Int]] = []
        newQuestions.reserveCapacity(questions.count)
        maps.reserveCapacity(questions.count)
        for question in questions {
            // mapped[displayedIndex] = original index in question.choices.
            let mapped = Array(0..<question.choices.count).shuffled(using: &rng)
            let shuffledChoices = mapped.map { question.choices[$0] }
            let newCorrectIndex = mapped.firstIndex(of: question.correctIndex) ?? question.correctIndex
            newQuestions.append(Question(
                id: question.id,
                subjectId: question.subjectId,
                difficulty: question.difficulty,
                text: question.text,
                choices: shuffledChoices,
                correctIndex: newCorrectIndex,
                explanation: remapExplanationLetters(question.explanation, mapped: mapped),
                states: question.states,
                imageName: question.imageName,
                imageURL: question.imageURL,
                imageSource: question.imageSource))
            maps.append(mapped)
        }
        return (newQuestions, maps)
    }

    // MARK: - Explanation letter remapping

    /// Rewrites option-letter references inside an explanation so they point at
    /// the option the user is ACTUALLY looking at.
    ///
    /// The banks are written against the canonical order in `questions.json`, and
    /// many explanations end with "故選D" / "alternativa B" / "(C) está correta".
    /// Since `shuffleChoices` reorders the options per session, those letters would
    /// name the wrong option on screen — the learner answers correctly and then
    /// reads an explanation pointing somewhere else. Measured on 2026-08-21: 99% of
    /// the 初考 bank, 43% of 不動產經紀人, 33% of 一般警察.
    ///
    /// `mapped[displayed] = original`, so the inverse says where each canonical
    /// option ended up. Only letters in an explicit option-reference context are
    /// rewritten — never a stray capital in ordinary prose (e.g. Portuguese "A
    /// alternativa…" must not be touched).
    static func remapExplanationLetters(_ text: String, mapped: [Int]) -> String {
        guard !text.isEmpty, mapped.count > 1 else { return text }

        var inverse = Array(repeating: 0, count: mapped.count)
        for (displayed, original) in mapped.enumerated() where original < inverse.count {
            inverse[original] = displayed
        }

        let half = Array("ABCDEFGH")
        let full = Array("ＡＢＣＤＥＦＧＨ")
        func remapped(_ ch: Character) -> Character? {
            let isFull = full.contains(ch)
            let table = isFull ? full : half
            guard let idx = table.firstIndex(of: ch), idx < inverse.count else { return nil }
            let target = inverse[idx]
            guard target < table.count else { return nil }
            return table[target]
        }

        // Só letras dentro da faixa real de opções. "A-H" fixo reescrevia siglas.
        let last = half[min(mapped.count, half.count) - 1]
        let range = "A-\(last)Ａ-\(full[min(mapped.count, full.count) - 1])"

        // Guarda contra notação: se o texto tem letra entre parênteses FORA da faixa de
        // opções, os parênteses ali são sigla, não referência a alternativa. Caso real:
        // "適應（A）與模式維護（L）" (AGIL de Parsons) — o （L） denuncia que （A） não é opção.
        var parenIsNotation = false
        if let probe = try? NSRegularExpression(pattern: "[（(【\\[]\\s*([A-ZＡ-Ｚ])\\s*[）)】\\]]") {
            let ns = text as NSString
            for m in probe.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard let ch = ns.substring(with: m.range(at: 1)).first else { continue }
                let table = full.contains(ch) ? full : half
                guard let i = table.firstIndex(of: ch) else { parenIsNotation = true; break }
                if i >= mapped.count { parenIsNotation = true; break }
            }
        }

        // Cada padrão captura exatamente uma letra de alternativa no grupo 1.
        var patterns = [
            "(?:故選|正確答案為|正確答案是|答案為|答案是|應選|選項|選)\\s*([\(range)])",
            "(?:故|則)?\\s*([\(range)])\\s*(?:敘述)?\\s*(?:錯誤|正確|選項)",
            "(?:錯誤者為|正確者為|答案應為)\\s*([\(range)])",
            "(?:alternativa|letra|opção|opcao|item|option|choice|answer)\\s+([\(range)])"
        ]
        if !parenIsNotation {
            patterns.insert("[（(【\\[]\\s*([\(range)])\\s*[）)】\\]]", at: 0)
        }

        // PASSE ÚNICO. Aplicar os padrões em sequência remapeava duas vezes o mesmo trecho
        // quando dois deles se sobrepunham — "故選項 C 錯誤" casava em `選項 C` (padrão 2) e
        // depois em `C 錯誤` (padrão 3) sobre o texto já reescrito, saindo com a letra errada.
        // Agora as ocorrências de TODOS os padrões são coletadas sobre o texto original, as
        // sobreposições descartadas, e a reescrita acontece uma vez só.
        let ns = text as NSString
        var hits: [(NSRange, Character)] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern,
                                                       options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let r = match.range(at: 1)
                guard r.location != NSNotFound,
                      let ch = ns.substring(with: r).first,
                      let new = remapped(ch) else { continue }
                hits.append((r, new))
            }
        }
        guard !hits.isEmpty else { return text }
        hits.sort { $0.0.location < $1.0.location }

        var result = ""
        var cursor = 0
        for (r, new) in hits {
            guard r.location >= cursor else { continue }   // descarta sobreposição
            result += ns.substring(with: NSRange(location: cursor, length: r.location - cursor))
            result += String(new)
            cursor = r.location + r.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
