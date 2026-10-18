import Foundation

/// The token shown for each option. Multiple choice uses A–F; Verdadeiro/Falso
/// uses the pack's short tokens (pt-BR "V"/"F", en "T"/"F").
enum ChoiceLetters {
    static let multipleChoice = ["A", "B", "C", "D", "E", "F"]

    static func letters(for format: NicheConfig.QuestionFormat, strings: UIStrings.Quiz) -> [String] {
        switch format {
        case .multipleChoice: multipleChoice
        case .trueFalse: [strings.trueLetter, strings.falseLetter]
        }
    }

    static func letter(at index: Int, format: NicheConfig.QuestionFormat, strings: UIStrings.Quiz) -> String {
        let all = letters(for: format, strings: strings)
        return all.indices.contains(index) ? all[index] : ""
    }
}
