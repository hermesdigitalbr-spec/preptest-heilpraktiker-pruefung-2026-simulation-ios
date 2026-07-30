import Foundation

struct Question: Equatable, Identifiable, Hashable {
    let id: String
    let subjectId: String
    let difficulty: Int
    let text: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    var states: [String]?
    var imageName: String?
    var imageURL: String?
    var imageSource: String?
}

extension Question: Codable {
    enum CodingKeys: String, CodingKey {
        case id, subjectId, difficulty, text, choices, correctIndex, explanation, states
        case imageName, imageURL, imageSource
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self,   forKey: .id)
        subjectId    = try c.decode(String.self,   forKey: .subjectId)
        difficulty   = try c.decode(Int.self,      forKey: .difficulty)
        text         = try c.decode(String.self,   forKey: .text)
        choices      = try c.decode([String].self, forKey: .choices)
        correctIndex = try c.decode(Int.self,      forKey: .correctIndex)
        explanation  = try c.decode(String.self,   forKey: .explanation)
        states       = try c.decodeIfPresent([String].self,  forKey: .states)
        imageName    = try c.decodeIfPresent(String.self,    forKey: .imageName)
        imageURL     = try c.decodeIfPresent(String.self,    forKey: .imageURL)
        imageSource  = try c.decodeIfPresent(String.self,    forKey: .imageSource)
    }
}
