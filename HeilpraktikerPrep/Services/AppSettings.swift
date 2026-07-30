import Foundation
import Observation
import SwiftUI

/// User preferences persisted in UserDefaults. Pure preferences only —
/// study progress lives in ProgressStore, profile in AppSession.
@MainActor
@Observable
final class AppSettings {
    enum Theme: String, Codable, CaseIterable {
        case system, light, dark

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    private struct Stored: Codable, Equatable {
        var feedbackMode: FeedbackMode = .learning
        var theme: Theme = .system
        var notificationsEnabled: Bool = false
        var reminderHour: Int = 19
        var reminderMinute: Int = 0

        // Tolerate older stored payloads that miss newer keys.
        init() {}
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            feedbackMode = try container.decodeIfPresent(FeedbackMode.self, forKey: .feedbackMode) ?? .learning
            theme = try container.decodeIfPresent(Theme.self, forKey: .theme) ?? .system
            notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
            reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
            reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        }
    }

    var feedbackMode: FeedbackMode {
        get { stored.feedbackMode }
        set { stored.feedbackMode = newValue }
    }

    var theme: Theme {
        get { stored.theme }
        set { stored.theme = newValue }
    }

    var notificationsEnabled: Bool {
        get { stored.notificationsEnabled }
        set { stored.notificationsEnabled = newValue }
    }

    var reminderHour: Int {
        get { stored.reminderHour }
        set { stored.reminderHour = newValue }
    }

    var reminderMinute: Int {
        get { stored.reminderMinute }
        set { stored.reminderMinute = newValue }
    }

    private var stored: Stored {
        didSet { Self.persist(stored) }
    }

    private static let key = "settings.v1"

    init() {
        stored = Self.load()
    }

    private static func load() -> Stored {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return Stored()
        }
        return stored
    }

    private static func persist(_ stored: Stored) {
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
