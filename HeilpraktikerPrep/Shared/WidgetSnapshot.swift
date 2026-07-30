import Foundation

/// Lightweight state the app publishes to the shared App Group container for
/// the widget to render. Kept tiny and self-contained (no app types) so it
/// can be compiled into both the app and the widget extension.
struct WidgetSnapshot: Codable, Equatable {
    var examShortName: String
    var daysToExam: Int?        // nil when no future exam date
    var streak: Int
    var dailyDone: Bool
    var dailyTarget: Int
    var readiness: Int          // 0...100
    var accentHex: String

    static let placeholder = WidgetSnapshot(
        examShortName: "EXAM", daysToExam: 24, streak: 7, dailyDone: false,
        dailyTarget: 20, readiness: 78, accentHex: "#4F8EF7")
}

/// Reads/writes the snapshot in the App Group both processes share.
enum WidgetSnapshotStore {
    static let appGroup = "group.app.hermesdigital.hp"
    private static let key = "widget.snapshot.v1"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
