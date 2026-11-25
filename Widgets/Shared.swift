import AppIntents
import SwiftUI
import WidgetKit

// Shared pieces of the Deschly widgets: the word list (Resources/widget_words.json, made by
// tools/widget_words.py), configuration, the "next" button, colours.

struct WidgetWord: Codable, Hashable {
    let d: String
    let a: String
    let tr: String
    let en: String
    let x: String
    let xtr: String
    let xen: String

    var full: String { a.isEmpty ? d : "\(a) \(d)" }
    func meaning(_ turkish: Bool) -> String { turkish ? tr : en }
    func exampleMeaning(_ turkish: Bool) -> String { turkish ? xtr : xen }
}

/// A short everyday sentence for Lina's speech bubble.
struct LinaLine: Codable, Hashable {
    let s: String
    let tr: String
    let en: String
    let l: String
}

private struct WidgetData: Decodable {
    let words: [String: [WidgetWord]]
    let lina: [LinaLine]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        var words: [String: [WidgetWord]] = [:]
        for level in ["A1", "A2", "B1", "B2"] {
            words[level] = try c.decodeIfPresent([WidgetWord].self, forKey: Key(stringValue: level)) ?? []
        }
        self.words = words
        lina = try c.decodeIfPresent([LinaLine].self, forKey: Key(stringValue: "LINA")) ?? []
    }
}

enum WordBank {
    private static let data: WidgetData? = {
        guard let url = Bundle.main.url(forResource: "widget_words", withExtension: "json"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: raw)
    }()

    static var turkish: Bool { Locale.preferredLanguages.first?.hasPrefix("tr") ?? false }

    static let sample = WidgetWord(d: "Verspätung", a: "die", tr: "gecikme", en: "delay",
                                   x: "Der Zug hat zehn Minuten Verspätung.", xtr: "Trenin on dakika gecikmesi var.",
                                   xen: "The train is ten minutes late.")
    static let sampleLine = LinaLine(s: "Danke, ebenfalls!", tr: "Teşekkürler, size de!", en: "Thanks, you too!", l: "A1")

    /// A large prime spreads neighbouring indexes over the whole list.
    private static func pick<T>(_ list: [T], _ index: Int) -> T? {
        guard !list.isEmpty else { return nil }
        let n = list.count
        return list[((index % n) * 7919 % n + n) % n]
    }

    static func word(level: String, index: Int, nounsOnly: Bool = false) -> WidgetWord {
        var list = data?.words[level] ?? []
        if list.isEmpty { list = data?.words["A1"] ?? [] }
        if nounsOnly { list = list.filter { !$0.a.isEmpty } }
        return pick(list, index) ?? sample
    }

    static func line(index: Int) -> LinaLine { pick(data?.lina ?? [], index) ?? sampleLine }
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
    static var description = IntentDescription("A German word with its meaning.")

    @Parameter(title: "Level", default: .a1)
    var level: WidgetLevel

    @Parameter(title: "New word", default: .hourly)
    var rotation: WidgetRotation
}

struct LevelConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Deschly level"
    static var description = IntentDescription("Choose the level.")

    @Parameter(title: "Level", default: .a1)
    var level: WidgetLevel
}

// MARK: - Buttons

/// "Next word" on the Home Screen widgets.
struct NextWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Next word"

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "skip") + 1, forKey: "skip")
        return .result()
    }
}

// MARK: - Look

enum Palette {
    static let der = Color(red: 0.184, green: 0.357, blue: 0.918)
    static let die = Color(red: 0.784, green: 0.196, blue: 0.227)
    static let das = Color(red: 0.082, green: 0.478, blue: 0.255)
    static let gold = Color(red: 0.949, green: 0.761, blue: 0.188)
    static let night = Color(red: 0.055, green: 0.059, blue: 0.047)
    static let cream = Color(red: 0.969, green: 0.969, blue: 0.957)
    static let paper = Color(red: 0.984, green: 0.973, blue: 0.945)
    static let muted = Color(red: 0.42, green: 0.435, blue: 0.463)

    static func article(_ a: String) -> Color {
        switch a {
        case "der": return der
        case "die": return die
        case "das": return das
        default: return gold
        }
    }

    /// Light → dark gradient in the article colour (style C).
    static func articleGradient(_ a: String) -> LinearGradient {
        let colors: [Color]
        switch a {
        case "der": colors = [Color(red: 0.31, green: 0.48, blue: 1), der, Color(red: 0.12, green: 0.25, blue: 0.69)]
        case "die": colors = [Color(red: 0.88, green: 0.35, blue: 0.38), die, Color(red: 0.61, green: 0.12, blue: 0.15)]
        case "das": colors = [Color(red: 0.18, green: 0.65, blue: 0.40), das, Color(red: 0.05, green: 0.35, blue: 0.18)]
        default: colors = [Color(red: 0.36, green: 0.36, blue: 0.40), Color(red: 0.2, green: 0.2, blue: 0.24)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Round icon button used on the widgets.
struct WidgetIconButton<I: AppIntent>: View {
    let intent: I
    let symbol: String
    var foreground: Color = .white
    var background: Color = .white.opacity(0.18)
    var size: CGFloat = 32
    let label: String

    var body: some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Button words in the user's language.
enum WidgetText {
    static func next(_ turkish: Bool) -> String { turkish ? "Sonraki" : "Next" }
}
