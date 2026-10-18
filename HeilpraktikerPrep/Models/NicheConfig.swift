import Foundation

/// Tudo que muda de prova para prova no funil. Omitido = padrão de concurso.
struct NicheConfig: Codable, Equatable {
    enum ExamOutcome: String, Codable { case pass, score }
    enum QuestionFormat: String, Codable { case multipleChoice, trueFalse }

    struct Motivation: Codable, Equatable, Identifiable {
        let id: String
        let label: String
        let detail: String
    }

    var examOutcome: ExamOutcome = .pass
    var questionFormat: QuestionFormat = .multipleChoice
    var heroImage: String = "heroGroup"
    var studentPhotoCount: Int = 32
    /// Linhas da grade de fotos do slide 1 do paywall (7 colunas). 3 = 21
    /// fotos mais altas (padrão, escolhido pela operadora); 4 = 28 menores.
    var paywallPhotoRows: Int = NicheConfig.defaultPaywallPhotoRows
    static let defaultPaywallPhotoRows = 3
    static let paywallPhotoRowsRange = 2...6
    /// nil = usa as 4 genéricas do strings.json (sem opções de nicho).
    var customMotivations: [Motivation]?
    /// Como a prova chama a região, em substantivo curto e como aparece na UI
    /// ("estado", "Bundesland", "state", "cantone"). Entra nos formatos de
    /// `onboarding`/`settings` do strings.json. nil = palavra neutra do idioma
    /// (`onboarding.regionLabelDefault`).
    var regionLabel: String?

    /// Palavra usada nas telas de região: a do pack quando existe, senão a
    /// neutra do idioma. Ponto único do fallback.
    func regionLabel(default fallback: String) -> String {
        let trimmed = regionLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? trimmed! : fallback)
    }

    var motivations: [Motivation] {
        customMotivations ?? Self.genericMotivationIds.map { Motivation(id: $0, label: "", detail: "") }
    }
    static let genericMotivationIds = ["stability", "calling", "family", "newCareer"]

    static func showsRating(_ rating: Double?) -> Bool { (rating ?? 0) > 4.5 }

    /// Year shown in copy, in the era the app's language uses: Thai apps show the
    /// Buddhist Era (CE + 543) whatever calendar the device is set to.
    static func displayYear(language: String, date: Date = .now) -> Int {
        let gregorian = Calendar(identifier: .gregorian).component(.year, from: date)
        return language.lowercased().hasPrefix("th") ? gregorian + 543 : gregorian
    }

    static func slideYears(now: Int = Calendar.current.component(.year, from: .now), count: Int) -> [Int] {
        (0..<count).map { now - $0 }
    }

    /// Copy that talks about passing (`.pass`) or about raising a score (`.score`).
    func outcomeText(pass: String, score: String) -> String {
        examOutcome == .score ? score : pass
    }

    enum CodingKeys: String, CodingKey {
        case examOutcome, questionFormat, heroImage, studentPhotoCount, regionLabel, paywallPhotoRows
        case customMotivations = "motivations"
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        examOutcome = try c.decodeIfPresent(ExamOutcome.self, forKey: .examOutcome) ?? .pass
        questionFormat = try c.decodeIfPresent(QuestionFormat.self, forKey: .questionFormat) ?? .multipleChoice
        heroImage = try c.decodeIfPresent(String.self, forKey: .heroImage) ?? "heroGroup"
        studentPhotoCount = max(8, try c.decodeIfPresent(Int.self, forKey: .studentPhotoCount) ?? 32)
        customMotivations = try c.decodeIfPresent([Motivation].self, forKey: .customMotivations)
        regionLabel = try c.decodeIfPresent(String.self, forKey: .regionLabel)
        let rows = try c.decodeIfPresent(Int.self, forKey: .paywallPhotoRows) ?? Self.defaultPaywallPhotoRows
        paywallPhotoRows = min(max(rows, Self.paywallPhotoRowsRange.lowerBound), Self.paywallPhotoRowsRange.upperBound)
    }
}
