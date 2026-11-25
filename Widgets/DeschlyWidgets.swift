import AppIntents
import SwiftUI
import WidgetKit

// Deschly widgets (iOS 17+): a German word on the Lock Screen and the Home Screen.
// The extension carries its own word list (Resources/widget_words.json, made by tools/widget_words.py)
// because it cannot read the app's data.

struct WidgetWord: Codable, Hashable {
    let d: String
    let a: String
    let tr: String
    let en: String
    let x: String
    let xtr: String
    let xen: String

    var full: String { a.isEmpty ? d : "\(a) \(d)" }
}

enum WordBank {
    static let all: [String: [WidgetWord]] = {
        guard let url = Bundle.main.url(forResource: "widget_words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([String: [WidgetWord]].self, from: data) else { return [:] }
        return words
    }()

    static var turkish: Bool { Locale.preferredLanguages.first?.hasPrefix("tr") ?? false }

    static let sample = WidgetWord(d: "Verspätung", a: "die", tr: "gecikme", en: "delay",
                                   x: "Der Zug hat zehn Minuten Verspätung.", xtr: "Trenin on dakika gecikmesi var.",
                                   xen: "The train is ten minutes late.")

    static func word(level: String, index: Int) -> WidgetWord {
        let list = all[level] ?? all["A1"] ?? []
        guard !list.isEmpty else { return sample }
        // A large prime spreads neighbouring indexes over the whole list.
        return list[((index % list.count) * 7919 % list.count + list.count) % list.count]
    }
}

// MARK: - Configuration

enum WidgetLevel: String, AppEnum {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Level"
    static var caseDisplayRepresentations: [WidgetLevel: DisplayRepresentation] = [
        .a1: "A1", .a2: "A2", .b1: "B1", .b2: "B2",
    ]
}

enum WidgetRotation: String, AppEnum {
    case hourly, daily

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "New word"
    static var caseDisplayRepresentations: [WidgetRotation: DisplayRepresentation] = [
        .hourly: "Every hour", .daily: "Every day",
    ]
}

struct WordConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Deschly word"
    static var description = IntentDescription("A German word with its meaning on your Lock Screen and Home Screen.")

    @Parameter(title: "Level", default: .a1)
    var level: WidgetLevel

    @Parameter(title: "New word", default: .hourly)
    var rotation: WidgetRotation
}

/// "Next word" button on the Home Screen widget.
struct NextWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Next word"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "skip") + 1, forKey: "skip")
        return .result()
    }
}

// MARK: - Timeline

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord
    let level: String
    let turkish: Bool
}

struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: WordBank.sample, level: "A1", turkish: WordBank.turkish)
    }

    func snapshot(for configuration: WordConfigIntent, in context: Context) async -> WordEntry {
        entry(at: Date(), configuration)
    }

    func timeline(for configuration: WordConfigIntent, in context: Context) async -> Timeline<WordEntry> {
        let calendar = Calendar.current
        let now = Date()
        var dates: [Date] = [now]
        if configuration.rotation == .hourly {
            let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            dates += (1...24).compactMap { calendar.date(byAdding: .hour, value: $0, to: hourStart) }
        } else {
            let dayStart = calendar.startOfDay(for: now)
            dates += (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: dayStart) }
        }
        return Timeline(entries: dates.map { entry(at: $0, configuration) }, policy: .atEnd)
    }

    private func entry(at date: Date, _ configuration: WordConfigIntent) -> WordEntry {
        let period = configuration.rotation == .hourly
            ? Int(date.timeIntervalSince1970 / 3600)
            : Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
        let index = period + UserDefaults.standard.integer(forKey: "skip")
        let level = configuration.level.rawValue
        return WordEntry(date: date, word: WordBank.word(level: level, index: index), level: level, turkish: WordBank.turkish)
    }
}

// MARK: - Views

private enum Palette {
    static let der = Color(red: 0.184, green: 0.357, blue: 0.918)
    static let die = Color(red: 0.784, green: 0.196, blue: 0.227)
    static let das = Color(red: 0.082, green: 0.478, blue: 0.255)
    static let gold = Color(red: 0.949, green: 0.761, blue: 0.188)
    static let night = Color(red: 0.055, green: 0.059, blue: 0.047)
    static let cream = Color(red: 0.969, green: 0.969, blue: 0.957)

    static func article(_ a: String) -> Color {
        switch a {
        case "der": return der
        case "die": return die
        case "das": return das
        default: return gold
        }
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var meaning: String { entry.turkish ? entry.word.tr : entry.word.en }
    private var exampleMeaning: String { entry.turkish ? entry.word.xtr : entry.word.xen }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.word.full) · \(meaning)")
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(entry.word.a.isEmpty ? "DE" : entry.word.a).font(.system(size: 11, weight: .heavy))
                    Text(entry.word.d).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(4)
            }
            .widgetAccentable()
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.word.full).font(.headline).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
                Text(meaning).font(.caption).lineLimit(1)
                Text(entry.word.x).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var articleTag: some View {
        Text(entry.word.a.isEmpty ? entry.level : entry.word.a)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Palette.article(entry.word.a), in: Capsule())
    }

    private var nextButton: some View {
        Button(intent: NextWordIntent()) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Palette.night)
                .frame(width: 28, height: 28)
                .background(Palette.gold, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.turkish ? "Sonraki kelime" : "Next word")
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                articleTag
                Spacer()
                Text("deschly.").font(.system(size: 11, weight: .heavy)).foregroundColor(Palette.cream.opacity(0.6))
            }
            Spacer(minLength: 0)
            Text(entry.word.d)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Palette.cream)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(meaning).font(.system(size: 13)).foregroundColor(Palette.cream.opacity(0.75)).lineLimit(2)
            HStack {
                Text(entry.level).font(.system(size: 11, weight: .bold)).foregroundColor(Palette.gold)
                Spacer()
                nextButton
            }
        }
        .containerBackground(for: .widget) { Palette.night }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                articleTag
                Text(entry.word.d)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Palette.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(meaning).font(.system(size: 14)).foregroundColor(Palette.cream.opacity(0.75)).lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text("deschly.").font(.system(size: 11, weight: .heavy)).foregroundColor(Palette.cream.opacity(0.6))
                    Text(entry.level).font(.system(size: 11, weight: .bold)).foregroundColor(Palette.gold)
                }
            }
            .frame(width: 130, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text("„\(entry.word.x)“")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.cream)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                Text(exampleMeaning).font(.system(size: 12)).foregroundColor(Palette.cream.opacity(0.65)).lineLimit(3)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    nextButton
                }
            }
        }
        .containerBackground(for: .widget) { Palette.night }
    }
}

// MARK: - Widget

struct WordWidget: Widget {
    let kind = "DeschlyWord"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WordConfigIntent.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName(WordBank.turkish ? "Deschly kelime" : "Deschly word")
        .description(WordBank.turkish
                     ? "Kilit ekranında ve ana ekranda anlamıyla bir Almanca kelime."
                     : "A German word with its meaning on your Lock Screen and Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct DeschlyWidgets: WidgetBundle {
    var body: some Widget {
        WordWidget()
    }
}
