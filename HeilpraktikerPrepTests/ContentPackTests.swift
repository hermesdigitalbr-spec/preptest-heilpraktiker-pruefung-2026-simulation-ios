import Testing
import Foundation
@testable import HeilpraktikerPrep

struct ContentPackTests {
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
        #expect(!content.strings.paywall.trialCta.isEmpty)
    }

    @Test func questionValidationRejectsUnknownSubject() {
        let q = Question(id: "q1", subjectId: "ghost", difficulty: 1,
                         text: "?", choices: ["a", "b", "c", "d"], correctIndex: 0, explanation: "e")
        #expect(throws: ContentError.self) {
            try ContentValidator.validate(question: q, subjectIds: ["subject-1"])
        }
    }
}
