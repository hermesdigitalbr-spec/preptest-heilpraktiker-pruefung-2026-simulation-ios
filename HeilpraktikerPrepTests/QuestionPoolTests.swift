import Testing
import Foundation
@testable import HeilpraktikerPrep

@MainActor
struct QuestionPoolTests {
    private func makeSession(stateId: String?) throws -> AppSession {
        var content = try ContentLoader.load(from: .main)
        let universal = Question(id: "u1", subjectId: content.pack.subjects[0].id, difficulty: 1,
                                 text: "t", choices: ["a", "b"], correctIndex: 0, explanation: "e")
        var floridaOnly = universal
        floridaOnly = Question(id: "fl1", subjectId: content.pack.subjects[0].id, difficulty: 1,
                               text: "t", choices: ["a", "b"], correctIndex: 0, explanation: "e",
                               states: ["FL"])
        content = ContentBundle(pack: content.pack, strings: content.strings,
                                questions: [universal, floridaOnly])

        var profile = UserProfile()
        profile.stateId = stateId
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        return AppSession(content: content, progress: ProgressStore(fileURL: tempURL), profile: profile)
    }

    @Test func universalQuestionsAlwaysIncluded() throws {
        let session = try makeSession(stateId: nil)
        #expect(session.questionPool.contains { $0.id == "u1" })
    }

    @Test func stateQuestionsExcludedWithoutChosenState() throws {
        let session = try makeSession(stateId: nil)
        #expect(!session.questionPool.contains { $0.id == "fl1" })
    }

    @Test func stateQuestionsIncludedForMatchingState() throws {
        let session = try makeSession(stateId: "FL")
        #expect(session.questionPool.contains { $0.id == "fl1" })
    }

    @Test func stateQuestionsExcludedForOtherState() throws {
        let session = try makeSession(stateId: "CA")
        #expect(!session.questionPool.contains { $0.id == "fl1" })
    }

    @Test func packHasNoRegions() throws {
        let content = try ContentLoader.load(from: .main)
        // This niche is a national certification — no per-state jurisdictions.
        #expect((content.pack.regions ?? []).isEmpty)
    }
}
