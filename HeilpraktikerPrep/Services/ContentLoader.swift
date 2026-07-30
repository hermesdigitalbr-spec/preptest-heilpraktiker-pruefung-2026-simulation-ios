import Foundation

enum ContentError: Error, Equatable {
    case missingResource(String)
    case validationFailed(String)
}

struct ContentBundle: Equatable {
    let pack: PackConfig
    let strings: UIStrings
    let questions: [Question]
}

enum ContentValidator {
    static func validate(question: Question, subjectIds: Set<String>) throws {
        guard (2...6).contains(question.choices.count) else {
            throw ContentError.validationFailed("question \(question.id): needs 2–6 choices")
        }
        guard (0..<question.choices.count).contains(question.correctIndex) else {
            throw ContentError.validationFailed("question \(question.id): correctIndex out of range")
        }
        guard subjectIds.contains(question.subjectId) else {
            throw ContentError.validationFailed("question \(question.id): unknown subject \(question.subjectId)")
        }
        guard (1...3).contains(question.difficulty) else {
            throw ContentError.validationFailed("question \(question.id): difficulty must be 1–3")
        }
        guard !question.text.isEmpty, !question.explanation.isEmpty else {
            throw ContentError.validationFailed("question \(question.id): empty text or explanation")
        }
    }

    static func validate(_ content: ContentBundle) throws {
        guard !content.pack.subjects.isEmpty else {
            throw ContentError.validationFailed("pack has no subjects")
        }
        let subjectIds = Set(content.pack.subjects.map(\.id))
        guard subjectIds.count == content.pack.subjects.count else {
            throw ContentError.validationFailed("duplicate subject ids")
        }
        let questionIds = content.questions.map(\.id)
        guard Set(questionIds).count == questionIds.count else {
            throw ContentError.validationFailed("duplicate question ids")
        }
        guard content.pack.dailyQuestionsCount > 0, content.pack.quickQuizCount > 0 else {
            throw ContentError.validationFailed("daily/quick counts must be positive")
        }
        guard content.pack.mockExam.questionCount <= content.questions.count else {
            throw ContentError.validationFailed("mock exam asks for more questions than the pack has")
        }
        for question in content.questions {
            try validate(question: question, subjectIds: subjectIds)
        }
    }
}

enum ContentLoader {
    static func load(from bundle: Bundle = .main) throws -> ContentBundle {
        ContentBundle(
            pack: try decodeResource("pack", as: PackConfig.self, from: bundle),
            strings: try decodeResource("strings", as: UIStrings.self, from: bundle),
            questions: try decodeResource("questions", as: [Question].self, from: bundle)
        )
    }

    /// Loads and validates; the app entry point uses this.
    static func loadValidated(from bundle: Bundle = .main) throws -> ContentBundle {
        let content = try load(from: bundle)
        try ContentValidator.validate(content)
        return content
    }

    private static func decodeResource<T: Decodable>(_ name: String, as type: T.Type, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ContentError.missingResource("\(name).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw ContentError.validationFailed("\(name).json failed to decode: \(error)")
        }
    }
}
