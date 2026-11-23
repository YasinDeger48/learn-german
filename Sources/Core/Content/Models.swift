import Foundation

// Content files live in Resources/content and are produced by tools/ (see docs/ARCHITECTURE.md).
// The same JSON is meant to be read by the future web and Android apps.

enum Bundled {
    static func decode<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Level content (a1.json)

struct A1Theme: Codable, Identifiable {
    let id: Int
    let de: String
    let name: LocText
}

struct A1Example: Codable {
    let de: String
    let pron: String
    let mean: LocText
}

struct A1Word: Codable, Identifiable {
    let id: Int
    let theme: Int
    let type: String
    let de: String
    let pron: String
    let mean: LocText
    let plural: String?
    let er: String?
    let perfekt: String?
    let ex: [A1Example]

    var isNoun: Bool { type == "der" || type == "die" || type == "das" }
    var withArticle: String {
        if isNoun { return "\(type) \(de)" }
        if type == "pl" { return "die \(de)" }
        return de
    }
    var group: String {
        if isNoun || type == "pl" { return "noun" }
        return type == "verb" ? "verb" : "word"
    }
}

struct A1Choice: Codable {
    let q: String
    let options: [String]
}

struct A1Text: Codable, Identifiable {
    let id: Int
    let title: String
    let titleL: LocText
    let de: [String]
    let trans: LocText
    let questions: [A1Choice]
}

struct A1GrammarExample: Codable, Hashable {
    let de: String
    let mean: LocText
}

struct A1GrammarTopic: Codable, Identifiable {
    let id: Int
    let de: String
    let name: LocText
    let rule: LocText
    let examples: [A1GrammarExample]
}

struct A1GrammarItem: Codable {
    let topic: Int
    let q: String
    let options: [String]
    let why: LocText
}

struct A1Line: Codable {
    let s: Int
    let t: String
}

struct A1Hoeren: Codable {
    let part: Int
    let lines: [A1Line]
    let q: String
    let options: [String]
    let trans: LocText
}

struct A1Mistake: Codable {
    let wrong: String
    let right: String
    let why: LocText
}

struct A1Situation: Codable {
    let q: LocText
    let options: [String]
}

struct A1Content: Codable {
    let themes: [A1Theme]
    let words: [A1Word]
    let texts: [A1Text]
    let grammar: [A1GrammarTopic]
    let grammarItems: [A1GrammarItem]
    let mistakes: [A1Mistake]
    let situations: [A1Situation]
    let hoeren: [A1Hoeren]

    static func load(_ level: String = "A1") -> A1Content? { Bundled.decode(A1Content.self, level.lowercased()) }
}

// MARK: - Daily reading (daily_a1.json, …)

/// A word in a daily text that the reader can tap. `form` is the exact spelling in the text.
struct DailyGloss: Codable, Hashable {
    let form: String
    let lemma: String
    let art: String?
    let pron: String?
    let extra: String?
    let mean: LocText

    var display: String { art.map { "\($0) \(lemma)" } ?? lemma }
}

/// type "mc": options + answer index. type "tf": answer 0 = Richtig, 1 = Falsch.
struct DailyQuestion: Codable, Hashable {
    let type: String
    let q: String
    let options: [String]?
    let answer: Int
}

struct DailyText: Codable, Identifiable, Hashable {
    let id: String
    let level: String
    let topic: String
    let title: String
    let paragraphs: [String]
    let trans: [LocText]
    let glossary: [DailyGloss]
    let questions: [DailyQuestion]

    var wordCount: Int { paragraphs.joined(separator: " ").split(separator: " ").count }
    var minutes: Int { max(1, Int((Double(wordCount) / 60).rounded(.up))) }
    var fullText: String { paragraphs.joined(separator: " ") }
}

struct DailyFile: Codable {
    let level: String
    let texts: [DailyText]
}

// MARK: - Video lessons (lessons.json)

struct Lesson: Codable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    let level: String
}
