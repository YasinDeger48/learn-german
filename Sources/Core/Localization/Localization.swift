import SwiftUI
import Combine

/// The learner's own language. German is always the language being learned.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case tr, en, es, fr, it, ku, ar

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .ku: return "Kurmancî"
        case .ar: return "العربية"
        }
    }

    var code: String { rawValue.uppercased() }

    /// Flag shown next to the language name. Kurmancî has no flag emoji: `LanguageFlag` draws it.
    var flag: String {
        switch self {
        case .tr: return "🇹🇷"
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .it: return "🇮🇹"
        case .ku: return ""
        case .ar: return "🇸🇦"
        }
    }

    var isRightToLeft: Bool { self == .ar }

    /// Languages the learner can choose. UI texts come from strings_<code>.json; learning content
    /// (word meanings, translations) not translated yet into a language shows in English (LocText falls back).
    static let offered: [AppLanguage] = [.tr, .en, .es, .fr, .it, .ku, .ar]

    /// Best match for the phone's language, used before the learner picks one.
    static var device: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        let match = AppLanguage(rawValue: String(preferred)) ?? .en
        return offered.contains(match) ? match : .en
    }
}

/// A small flag for a language (emoji, or drawn for Kurmancî).
struct LanguageFlag: View {
    let language: AppLanguage
    var size: CGFloat = 22

    var body: some View {
        if language == .ku {
            // Red, white, green with a golden sun.
            VStack(spacing: 0) {
                Color(red: 0.93, green: 0.14, blue: 0.14)
                ZStack {
                    Color.white
                    Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.0)).padding(size * 0.06)
                }
                Color(red: 0.16, green: 0.62, blue: 0.29)
            }
            .frame(width: size * 1.4, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
            .accessibilityHidden(true)
        } else {
            Text(language.flag).font(.system(size: size)).accessibilityHidden(true)
        }
    }
}

/// UI strings come from Resources/i18n/strings_<lang>.json (shared with future web and Android apps).
/// Placeholders are {0}, {1}, … so every platform can fill them the same way.
final class Localizer: ObservableObject {
    static let shared = Localizer()

    private static let languageKey = "appLanguage"
    private static let chosenKey = "appLanguageChosen"

    @Published private(set) var language: AppLanguage
    @Published private(set) var hasChosen: Bool
    private var table: [String: String] = [:]
    private var fallback: [String: String] = [:]

    private init() {
        let stored = UserDefaults.standard.string(forKey: Localizer.languageKey).flatMap(AppLanguage.init(rawValue:))
        // A language chosen earlier but not offered now falls back to English.
        language = stored.map { AppLanguage.offered.contains($0) ? $0 : .en } ?? AppLanguage.device
        hasChosen = UserDefaults.standard.bool(forKey: Localizer.chosenKey)
        fallback = Localizer.load(.en)
        table = Localizer.load(language)
    }

    func choose(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: Localizer.languageKey)
        UserDefaults.standard.set(true, forKey: Localizer.chosenKey)
        table = Localizer.load(language)
        self.language = language
        hasChosen = true
    }

    func string(_ key: String) -> String {
        table[key] ?? fallback[key] ?? key
    }

    private static func load(_ language: AppLanguage) -> [String: String] {
        guard let url = Bundle.main.url(forResource: "strings_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }
}

/// Translated UI string. `t("quiz.progress", 3, 20)` fills {0} and {1}.
func t(_ key: String, _ args: CustomStringConvertible...) -> String {
    var text = Localizer.shared.string(key)
    for (index, arg) in args.enumerated() {
        text = text.replacingOccurrences(of: "{\(index)}", with: arg.description)
    }
    return text
}

/// A content text in every learner language: {"tr": "...", "en": "..."}.
/// Decodes from a plain string too, so older data keeps working.
struct LocText: Codable, Hashable {
    let values: [String: String]

    init(_ values: [String: String]) { self.values = values }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let plain = try? container.decode(String.self) {
            values = ["tr": plain]
        } else {
            values = try container.decode([String: String].self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    /// Current language, then English, then Turkish.
    var text: String {
        let lang = Localizer.shared.language.rawValue
        return values[lang] ?? values["en"] ?? values["tr"] ?? ""
    }

    func contains(_ query: String) -> Bool {
        values.values.contains { $0.localizedStandardContains(query) }
    }
}
