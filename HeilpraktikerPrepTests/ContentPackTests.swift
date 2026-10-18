import Testing
import Foundation
import UIKit
@testable import HeilpraktikerPrep

struct ContentPackTests {
    @Test func stringsHaveNoGuaranteeBadge() throws {
        let data = try Data(contentsOf: Bundle.main.url(forResource: "strings", withExtension: "json")!)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("planBulletGuarantee"))
    }

    @Test func decodesPackConfig() throws {
        let json = """
        {"examName":"Prep Kit Text","examShortName":"EXAM","tagline":"REPLACE — your one-line tagline",
         "language":"en","accentHex":"#1B9AF7",
         "subjects":[{"id":"subject-1","name":"Topic One","sfSymbol":"1.circle.fill"}],
         "mockExam":{"questionCount":40,"minutes":45,"passPercent":80},
         "dailyQuestionsCount":10,"quickQuizCount":10,"freeQuickQuizzes":3,"freeDailyQuizzes":3,
         "products":{"weekly":"app.x.weekly","monthly":"app.x.monthly"},
         "legal":{"privacyUrl":"https://x.test/p","termsUrl":"https://x.test/t","supportEmail":"s@x.test"}}
        """.data(using: .utf8)!
        let pack = try JSONDecoder().decode(PackConfig.self, from: json)
        #expect(pack.examShortName == "EXAM")
        #expect(pack.subjects.first?.id == "subject-1")
        #expect(pack.mockExam.passPercent == 80)
        #expect(pack.products.monthly == "app.x.monthly")
    }

    @Test func uiStringsFailsOnMissingKey() {
        let incomplete = #"{"tabs":{"home":"Home"}}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(UIStrings.self, from: incomplete)
        }
    }

    @Test func questionValidationRejectsOutOfRangeCorrectIndex() {
        let q = Question(id: "q1", subjectId: "subject-1", difficulty: 1,
                         text: "?", choices: ["a", "b"], correctIndex: 5, explanation: "e")
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: q, subjectIds: ["subject-1"])
        }
    }

    @Test func loadsAndValidatesBundledContentPack() throws {
        let content = try ContentLoader.loadValidated(from: .main)
        // Template invariant: the bundled pack must have at least enough
        // questions to run a mock exam (a real niche ships thousands).
        #expect(content.questions.count >= content.pack.mockExam.questionCount)
        #expect(!content.pack.subjects.isEmpty)
        #expect(content.pack.products.monthly.hasSuffix(".monthly"))
        let subjectIds = Set(content.pack.subjects.map(\.id))
        #expect(Set(content.questions.map(\.subjectId)).isSubset(of: subjectIds))
        #expect(!content.strings.paywall.trialCtaFunnel.isEmpty)
    }

    @Test func questionValidationRejectsUnknownSubject() {
        let q = Question(id: "q1", subjectId: "ghost", difficulty: 1,
                         text: "?", choices: ["a", "b", "c", "d"], correctIndex: 0, explanation: "e")
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: q, subjectIds: ["subject-1"])
        }
    }
    // MARK: - Verdadeiro/Falso

    private func trueFalse(_ choices: [String], correct: Int = 0) -> Question {
        Question(id: "vf1", subjectId: "subject-1", difficulty: 1,
                 text: "Afirmação.", choices: choices, correctIndex: correct, explanation: "e")
    }

    @Test func trueFalseModeAcceptsTheConfiguredPair() throws {
        try ContentValidator.validate(question: trueFalse(["Verdadeiro", "Falso"], correct: 1),
                                      subjectIds: ["subject-1"],
                                      trueFalseLabels: ["Verdadeiro", "Falso"])
        try ContentValidator.validate(question: trueFalse(["True", "False"]),
                                      subjectIds: ["subject-1"],
                                      trueFalseLabels: ["True", "False"])
    }

    @Test func trueFalseModeRejectsFourChoices() {
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: trueFalse(["a", "b", "c", "d"]),
                                          subjectIds: ["subject-1"],
                                          trueFalseLabels: ["Verdadeiro", "Falso"])
        }
    }

    @Test func trueFalseModeRejectsSwappedOrder() {
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: trueFalse(["Falso", "Verdadeiro"]),
                                          subjectIds: ["subject-1"],
                                          trueFalseLabels: ["Verdadeiro", "Falso"])
        }
    }

    @Test func questionFormatDecodesFromPackNiche() throws {
        let niche = try JSONDecoder().decode(NicheConfig.self,
                                             from: Data(#"{"questionFormat":"trueFalse"}"#.utf8))
        #expect(niche.questionFormat == .trueFalse)
    }

    @Test func trueFalseLettersComeFromStrings() throws {
        let content = try ContentLoader.load(from: .main)
        let letters = ChoiceLetters.letters(for: .trueFalse, strings: content.strings.quiz)
        #expect(letters == [content.strings.quiz.trueLetter, content.strings.quiz.falseLetter])
        #expect(ChoiceLetters.letters(for: .multipleChoice, strings: content.strings.quiz).first == "A")
    }

    // MARK: - Imagem

    @Test func imageQuestionWithMissingAssetFailsValidation() {
        var q = trueFalse(["a", "b", "c", "d"])
        q.imageName = "does-not-exist"
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: q, subjectIds: ["subject-1"],
                                          imageExists: { _ in false })
        }
    }

    /// Banks without image questions (e.g. GED) are valid: only the assets of
    /// the image questions that do exist are required.
    @Test func bundledImageQuestionsHaveTheirAssets() throws {
        let content = try ContentLoader.loadValidated(from: .main)
        let withImage = content.questions.filter { $0.imageName != nil }
        #expect(withImage.allSatisfy { UIImage(named: $0.imageName!) != nil })
    }

    @Test func textOnlyQuestionKeepsNoImage() throws {
        let q = try JSONDecoder().decode(Question.self, from: Data(
            #"{"id":"x","subjectId":"s","difficulty":1,"text":"t","choices":["a","b"],"correctIndex":0,"explanation":"e"}"#.utf8))
        #expect(q.imageName == nil && q.imageURL == nil)
    }
}
