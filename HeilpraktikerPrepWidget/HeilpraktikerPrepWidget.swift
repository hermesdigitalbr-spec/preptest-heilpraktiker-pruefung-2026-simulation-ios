import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ExamEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ExamEntry {
        ExamEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ExamEntry) -> Void) {
        completion(ExamEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = ExamEntry(date: .now, snapshot: snapshot)
        // Refresh just after midnight so the exam countdown ticks down daily.
        let nextMidnight = Calendar.current.nextDate(
            after: .now, matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - Widget

struct HeilpraktikerPrepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeilpraktikerPrepWidget", provider: Provider()) { entry in
            HeilpraktikerPrepWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prüfungs-Countdown")
        .description("Countdown bis zur Prüfung, Serie und Tagesfortschritt.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Views

struct HeilpraktikerPrepWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ExamEntry

    private var accent: Color { Color(widgetHex: entry.snapshot.accentHex) }

    var body: some View {
        // Tapping the widget jumps straight into today's daily quiz — the
        // highest-intent re-entry surface, otherwise a dead end.
        content.widgetURL(URL(string: "heilpraktiker://daily"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:   accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        case .systemMedium:        mediumView
        default:                   smallView
        }
    }

    // Home-screen small: countdown hero + streak.
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(entry.snapshot.streak)")
                    .font(.system(size: 15, weight: .bold)).monospacedDigit()
                Spacer()
                Text(entry.snapshot.examShortName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let days = entry.snapshot.daysToExam {
                Text("\(days)")
                    .font(.system(size: 44, weight: .bold)).monospacedDigit()
                    .foregroundStyle(accent)
                Text(days == 1 ? "Tag bis zur Prüfung" : "Tage bis zur Prüfung")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("Leg deinen Prüfungstermin fest")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            dailyPill
        }
    }

    // Home-screen medium: countdown + readiness + streak + daily.
    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.snapshot.examShortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let days = entry.snapshot.daysToExam {
                    Text("\(days)")
                        .font(.system(size: 46, weight: .bold)).monospacedDigit()
                        .foregroundStyle(accent)
                    Text(days == 1 ? "Tag bis zur Prüfung" : "Tage bis zur Prüfung")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Leg deinen\nPrüfungstermin fest")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                dailyPill
            }
            Spacer()
            VStack(spacing: 10) {
                Gauge(value: Double(entry.snapshot.readiness), in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.snapshot.readiness)")
                        .font(.system(size: 16, weight: .bold)).monospacedDigit()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(accent)
                Text("Bereit")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(entry.snapshot.streak)")
                        .font(.system(size: 13, weight: .bold)).monospacedDigit()
                }
            }
        }
    }

    private var dailyPill: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.snapshot.dailyDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(entry.snapshot.dailyDone ? .green : .secondary)
            Text(entry.snapshot.dailyDone ? "Heute erledigt" : "\(entry.snapshot.dailyTarget) heute")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // Lock-screen circular: exam countdown.
    private var accessoryCircular: some View {
        Gauge(value: Double(entry.snapshot.readiness), in: 0...100) {
            Image(systemName: "calendar")
        } currentValueLabel: {
            if let days = entry.snapshot.daysToExam {
                Text("\(days)").monospacedDigit()
            } else {
                Image(systemName: "flame.fill")
            }
        }
        .gaugeStyle(.accessoryCircular)
    }

    // Lock-screen rectangular: countdown + streak line.
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot.examShortName)
                .font(.system(size: 13, weight: .semibold))
            if let days = entry.snapshot.daysToExam {
                Text("\(days) \(days == 1 ? "Tag" : "Tage") bis zur Prüfung")
                    .font(.system(size: 15, weight: .bold))
            } else {
                Text("Leg deinen Prüfungstermin fest").font(.system(size: 13))
            }
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(entry.snapshot.streak) \(entry.snapshot.streak == 1 ? "Tag" : "Tage") in Serie")
            }
            .font(.system(size: 12, weight: .medium))
        }
    }
}

// Local hex → Color so the widget needs no app-target code.
private extension Color {
    init(widgetHex: String) {
        let hex = widgetHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
