import Testing
import Foundation
@testable import HeilpraktikerPrep

/// Widget and achievements used to ship hardcoded Portuguese in every locale.
/// These guard the bundled ContentPack: in a non-pt app, no widget text and no
/// achievement title/detail may carry Portuguese.
struct LocalizationLeakTests {
    /// Portuguese-only fragments (chosen not to collide with fr/es/it/tr/vi texts;
    /// diacritics like ç/ã are legit in fr/tr/vi, so they are not used).
    private static let ptWords = [" seu ", " você ", " não ", "questões", "questão", "acerte ", "responda ",
                                  "dias seguidos", "sequência", "defina a data", "para a prova",
                                  "feito hoje", "simulado", "estude ", "matéria", "acerto",
                                  "mantenha ", "alcance ", "experimente ", "contagem regressiva"]

    private func looksPortuguese(_ text: String) -> Bool {
        let padded = " " + text.lowercased() + " "
        return Self.ptWords.contains { padded.contains($0) }
    }

    @Test func widgetStringsLoadFromBundledCatalog() throws {
        let url = try #require(Bundle.main.url(forResource: "strings", withExtension: "json"))
        let strings = try WidgetStrings.decode(from: Data(contentsOf: url))
        #expect(strings.countdown(3).contains("3"))
        #expect(strings.streak(5).contains("5"))
        #expect(strings.dailyTarget(20).contains("20"))
    }

    @Test func noPortugueseInWidgetOrAchievementsOutsidePt() throws {
        let content = try ContentLoader.loadValidated(from: .main)
        guard !content.pack.language.lowercased().hasPrefix("pt") else { return }
        let url = try #require(Bundle.main.url(forResource: "strings", withExtension: "json"))
        let w = try WidgetStrings.decode(from: Data(contentsOf: url))
        let widgetTexts = [w.displayName, w.description, w.daysToExamOne, w.daysToExamOther,
                           w.setExamDate, w.setExamDateMultiline, w.readiness, w.doneToday,
                           w.dailyTargetFormat, w.countdownOneFormat, w.countdownOtherFormat,
                           w.streakFormat]
        for text in widgetTexts { #expect(!looksPortuguese(text), "widget pt: \(text)") }
        for a in content.pack.achievements ?? [] {
            #expect(!looksPortuguese(a.title), "conquista \(a.id) pt: \(a.title)")
            #expect(!looksPortuguese(a.detail), "conquista \(a.id) pt: \(a.detail)")
        }
    }

    private func allTexts(_ node: Any) -> [String] {
        switch node {
        case let s as String: return [s]
        case let a as [Any]: return a.flatMap(allTexts)
        case let d as [String: Any]: return d.values.flatMap(allTexts)
        default: return []
        }
    }

    @Test func noPortugueseAnywhereInStringsCatalogOutsidePt() throws {
        let content = try ContentLoader.loadValidated(from: .main)
        guard !content.pack.language.lowercased().hasPrefix("pt") else { return }
        let url = try #require(Bundle.main.url(forResource: "strings", withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        for text in allTexts(json) { #expect(!looksPortuguese(text), "strings.json pt: \(text)") }
    }

    @Test func portugueseDetectorCatchesKnownLeaks() {
        #expect(looksPortuguese("Defina a data da sua prova"))
        #expect(looksPortuguese("Termine seu primeiro quiz"))
        #expect(!looksPortuguese("Termine ton premier quiz"))
        #expect(!looksPortuguese("Prendiamo il tempo per sua materia"))
        #expect(!looksPortuguese("Set your exam date"))
        #expect(!looksPortuguese("試験日を設定してください"))
    }
}
