import Testing
import Foundation
@testable import HeilpraktikerPrep

struct PackNicheConfigTests {
    private func decode(_ json: String) throws -> NicheConfig {
        try JSONDecoder().decode(NicheConfig.self, from: Data(json.utf8))
    }

    @Test func defaultsWhenOmitted() throws {
        let c = try decode("{}")
        #expect(c.examOutcome == .pass)
        #expect(c.questionFormat == .multipleChoice)
        #expect(c.heroImage == "heroGroup")
        #expect(c.studentPhotoCount == 32)
        #expect(c.motivations.map(\.id) == ["stability", "calling", "family", "newCareer"])
    }

    @Test func customMotivationsAndScoreOutcome() throws {
        let c = try decode(#"{"examOutcome":"score","motivations":[{"id":"fun","label":"Lazer","detail":"Pilotar no fim de semana"}]}"#)
        #expect(c.examOutcome == .score)
        #expect(c.motivations.first?.label == "Lazer")
        #expect(c.outcomeText(pass: "a", score: "b") == "b")
    }

    @Test func regionLabelFallsBackToLanguageDefault() throws {
        #expect(try decode("{}").regionLabel == nil)
        #expect(try decode("{}").regionLabel(default: "estado") == "estado")
    }

    @Test func packRegionLabelWinsOverDefault() throws {
        let c = try decode(#"{"regionLabel":"Bundesland"}"#)
        #expect(c.regionLabel == "Bundesland")
        #expect(c.regionLabel(default: "Region") == "Bundesland")
    }

    @Test func blankRegionLabelUsesDefault() throws {
        #expect(try decode(#"{"regionLabel":"  "}"#).regionLabel(default: "state") == "state")
    }

    @Test func ratingChipOnlyAboveFourPointFive() {
        #expect(NicheConfig.showsRating(4.6))
        #expect(!NicheConfig.showsRating(4.5))
        #expect(!NicheConfig.showsRating(nil))
    }

    @Test func slideYearsCountBackFromCurrent() {
        #expect(NicheConfig.slideYears(now: 2027, count: 4) == [2027, 2026, 2025, 2024])
    }

    @Test func thaiCopyUsesBuddhistEra() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 17))!
        #expect(NicheConfig.displayYear(language: "th", date: date) == 2569)
        #expect(NicheConfig.displayYear(language: "pt-BR", date: date) == 2026)
    }

    @Test func photoNamesFollowCount() {
        #expect(OnboardingPhotos.all(count: 10).count == 10)
        #expect(OnboardingPhotos.all(count: 10).first == "student01")
    }

    @Test func gridWithTwentyFourPhotosHasNoBlanks() {
        let three = OnboardingPhotos.grid(count: 24, slots: 21)
        #expect(three.count == 21)
        #expect(Set(three).count == 21)
        let four = OnboardingPhotos.grid(count: 24, slots: 28)
        #expect(four.count == 28)
        #expect(four[24] == "student01")
    }

    @Test func legacyMotivationRawValueStillDecodes() throws {
        let json = #"{"motivation":"tradition","studyDays":[],"weakSubjectIds":[],"hasCompletedOnboarding":true}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        #expect(profile.motivation == "tradition")
    }

    @Test func bundledPackHasNoPoliceContent() throws {
        for name in ["pack", "strings"] {
            let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
            let text = String(decoding: try Data(contentsOf: url), as: UTF8.self).lowercased()
            for word in ["polícia", "policia", "farda", "corporação", "pmsp"] {
                #expect(!text.contains(word), "\(name).json contém \(word)")
            }
        }
    }
}
