import Foundation

/// Visible texts of the widget extension, read from the `widget` block of
/// `ContentPack/strings.json` (the same per-locale catalog the app uses, copied
/// from `locales/<code>/` by `scripts/new-app.sh`). The file is bundled into the
/// widget target too (see project.yml), so no text is hardcoded in the widget.
/// Compiled into both the app (tests) and the widget extension.
struct WidgetStrings: Codable, Equatable {
    let displayName: String
    let description: String
    let daysToExamOne: String          // label under the big number, 1 day
    let daysToExamOther: String        // label under the big number, n days
    let setExamDate: String
    let setExamDateMultiline: String   // may contain "\n"
    let readiness: String
    let doneToday: String
    let dailyTargetFormat: String      // %d = daily target
    let countdownOneFormat: String     // %d = days (1)
    let countdownOtherFormat: String   // %d = days (n)
    let streakFormat: String           // %d = streak days

    func daysLabel(_ days: Int) -> String { days == 1 ? daysToExamOne : daysToExamOther }

    func countdown(_ days: Int) -> String {
        String(format: days == 1 ? countdownOneFormat : countdownOtherFormat, days)
    }

    func dailyTarget(_ target: Int) -> String { String(format: dailyTargetFormat, target) }

    func streak(_ days: Int) -> String { String(format: streakFormat, days) }

    private struct Envelope: Decodable { let widget: WidgetStrings }

    static func decode(from data: Data) throws -> WidgetStrings {
        try JSONDecoder().decode(Envelope.self, from: data).widget
    }

    /// Loads from `strings.json` in the given bundle. A missing/broken catalog
    /// is a build bug: crash in DEBUG, fall back to neutral English in Release.
    static func load(from bundle: Bundle = .main) -> WidgetStrings {
        do {
            guard let url = bundle.url(forResource: "strings", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try decode(from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            fatalError("Widget strings failed to load: \(error)")
            #else
            return .fallback
            #endif
        }
    }

    static let fallback = WidgetStrings(
        displayName: "Exam Countdown",
        description: "Exam countdown, streak and daily progress.",
        daysToExamOne: "day to exam", daysToExamOther: "days to exam",
        setExamDate: "Set your exam date", setExamDateMultiline: "Set your\nexam date",
        readiness: "Ready", doneToday: "Done today", dailyTargetFormat: "%d today",
        countdownOneFormat: "%d day to exam", countdownOtherFormat: "%d days to exam",
        streakFormat: "%d-day streak")
}
