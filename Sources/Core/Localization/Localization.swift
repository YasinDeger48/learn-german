import SwiftUI
import Combine

/// The learner's own language. German is always the language being learned.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case tr, en, es, fr, it

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        }
    }

    var code: String { rawValue.uppercased() }

    /// Best match for the phone's language, used before the learner picks one.
    static var device: AppLanguage {
        let preferred = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        return AppLanguage(rawValue: String(preferred)) ?? .en
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
        language = stored ?? AppLanguage.device
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
