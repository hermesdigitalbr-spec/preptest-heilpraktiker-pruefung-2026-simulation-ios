import Testing
import Foundation
@testable import HeilpraktikerPrep

/// Per-session choice shuffling rebuilds each `Question`, so every field has to be
/// carried across. `imageURL` was being dropped: since every quiz mode passes a
/// shuffle seed, a bank whose images are remote showed no images at all — and
/// nothing failed loudly, the card just never rendered.
struct QuizSessionImageTests {

    private func question(imageName: String? = nil, imageURL: String? = nil) -> Question {
        Question(id: "q1", subjectId: "s1", difficulty: 2,
                 text: "Enunciado", choices: ["a", "b", "c", "d"], correctIndex: 0,
                 explanation: "porque sim",
                 states: ["SP"], imageName: imageName, imageURL: imageURL)
    }

    @Test func shuffledSessionKeepsRemoteImageURL() {
        let session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: [question(imageURL: "https://example.test/a.png")],
                                  shuffleSeed: 42)
        #expect(session.currentQuestion?.imageURL == "https://example.test/a.png")
    }

    @Test func shuffledSessionKeepsBundledImageName() {
        let session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: [question(imageName: "diagram")],
                                  shuffleSeed: 42)
        #expect(session.currentQuestion?.imageName == "diagram")
    }

    @Test func shuffledSessionKeepsRegionRestriction() {
        let session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: [question(imageURL: "https://example.test/a.png")],
                                  shuffleSeed: 42)
        #expect(session.currentQuestion?.states == ["SP"])
    }

    /// Guards the whole struct rather than one field at a time: everything except
    /// the deliberately reordered choices/correctIndex/explanation must survive.
    @Test func shufflingOnlyChangesChoiceOrdering() {
        let original = question(imageURL: "https://example.test/a.png")
        let session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: [original], shuffleSeed: 7)
        let shuffled = try! #require(session.currentQuestion)
        #expect(shuffled.id == original.id)
        #expect(shuffled.subjectId == original.subjectId)
        #expect(shuffled.difficulty == original.difficulty)
        #expect(shuffled.text == original.text)
        #expect(shuffled.states == original.states)
        #expect(shuffled.imageName == original.imageName)
        #expect(shuffled.imageURL == original.imageURL)
        #expect(Set(shuffled.choices) == Set(original.choices))
    }
}
