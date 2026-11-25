import Foundation

/// What the long-press bubble in a text shows for one word.
struct WordInfo: Equatable {
    let word: String
    let article: String?
    let pron: String?
    let meaning: String
    /// Plural or verb forms, if known.
    let extra: String?
}

/// Every word of every level, found by the form that appears in a text: the word itself, the plural,
/// the "er" form and the participle of verbs ("geht", "gegangen" → gehen). Built once, off the main thread.
final class WordLookup {
    static let shared = WordLookup()

    private var table: [String: A1Word] = [:]
    /// Resources/content/lexicon.json: every other form found in the texts (tools/lexicon.py).
    private var lexicon: [String: DailyGloss] = [:]
    private var ready = false
    private var preparing = false
    private let lock = NSLock()

    func prepare() {
        lock.lock()
        guard !ready, !preparing else { lock.unlock(); return }
        preparing = true
        lock.unlock()
        var result: [String: A1Word] = [:]
        // Higher levels first, so the simplest meaning (A1) wins for words that appear in several levels.
        for level in LevelModels.practiceLevels.reversed() {
            guard let content = A1Content.load(level) else { continue }
            for word in content.words {
                for key in WordLookup.keys(for: word) { result[key] = word }
            }
        }
        var forms: [String: DailyGloss] = [:]
        for gloss in Bundled.decode(Lexicon.self, "lexicon")?.forms ?? [] { forms[gloss.form.lowercased()] = gloss }
        lock.lock()
        table = result
        lexicon = forms
        ready = true
        preparing = false
        lock.unlock()
    }

    private static func keys(for word: A1Word) -> [String] {
        var keys = [word.de.lowercased()]
        if let plural = word.plural, !plural.isEmpty { keys.append(plural.lowercased()) }
        // "er geht" → "geht", "ist gegangen" / "hat gemacht" → "gegangen" / "gemacht"
        if let er = word.er, let last = er.split(separator: " ").last { keys.append(String(last).lowercased()) }
        if let perfekt = word.perfekt, let last = perfekt.split(separator: " ").last { keys.append(String(last).lowercased()) }
        return keys
    }

    /// The token as written in the text ("Verspätung,", "Zügen", "ging").
    func info(for token: String, glossary: [DailyGloss]) -> WordInfo? {
        let core = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…‚‘'»«")).lowercased()
        guard !core.isEmpty else { return nil }
        if let gloss = glossary.first(where: { $0.form.lowercased() == core }) {
            return WordInfo(word: gloss.lemma, article: gloss.art, pron: gloss.pron, meaning: gloss.mean.text, extra: gloss.extra)
        }
        lock.lock()
        let isReady = ready
        lock.unlock()
        guard isReady else { return nil }
        if table[core] == nil, let gloss = lexicon[core] {
            return WordInfo(word: gloss.lemma, article: gloss.art, pron: gloss.pron, meaning: gloss.mean.text, extra: gloss.extra)
        }
        if let word = table[core] ?? stemMatch(core) {
            let article = ["der", "die", "das"].contains(word.type) ? word.type : nil
            let extra = word.plural.map { "Pl. \($0)" } ?? word.perfekt
            return WordInfo(word: word.de, article: article, pron: word.pron, meaning: word.mean.text, extra: extra)
        }
        return nil
    }

    /// Common endings: "kleinen" → "klein", "Kindern" → "kinder"/"kind", "fährst" → "fährt"?
    private func stemMatch(_ core: String) -> A1Word? {
        for ending in ["en", "em", "er", "es", "e", "n", "s", "st", "t"] where core.hasSuffix(ending) && core.count > ending.count + 2 {
            let stem = String(core.dropLast(ending.count))
            if let word = table[stem] ?? table[stem + "en"] ?? table[stem + "n"] { return word }
        }
        return nil
    }
}

/// lexicon.json: {"forms": [glossary entries]}.
struct Lexicon: Decodable {
    let forms: [DailyGloss]
}
