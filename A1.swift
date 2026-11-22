import SwiftUI
import UIKit
import Combine
import AVFoundation

// MARK: - Content (a1.json, built from the A1 PDF by tools/)

struct A1Theme: Codable, Identifiable {
    let id: Int
    let de: String
    let tr: String
}

struct A1Example: Codable {
    let de: String
    let pron: String
    let tr: String
}

struct A1Word: Codable, Identifiable {
    let id: Int
    let theme: Int
    let type: String
    let de: String
    let pron: String
    let tr: String
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
    let titleTr: String
    let de: [String]
    let tr: String
    let questions: [A1Choice]
}

struct A1GrammarTopic: Codable, Identifiable {
    let id: Int
    let de: String
    let tr: String
    let rule: String
    let examples: [String]
}

struct A1GrammarItem: Codable {
    let topic: Int
    let q: String
    let options: [String]
    let why: String
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
    let tr: String
}

struct A1Mistake: Codable {
    let wrong: String
    let right: String
    let why: String
}

struct A1Content: Codable {
    let themes: [A1Theme]
    let words: [A1Word]
    let texts: [A1Text]
    let grammar: [A1GrammarTopic]
    let grammarItems: [A1GrammarItem]
    let mistakes: [A1Mistake]
    let situations: [A1Choice]
    let hoeren: [A1Hoeren]

    static func load() -> A1Content? {
        guard let url = Bundle.main.url(forResource: "a1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(A1Content.self, from: data)
    }
}

// MARK: - Questions

enum A1Mode: String, CaseIterable, Identifiable, Hashable {
    case artikel, wordToTr, trToWord, sentence, cloze, order, listen, hoeren, write, plural, verbs, grammar, numbers, reading, daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artikel: return "Artikel: der, die, das"
        case .wordToTr: return "Kelime → Türkçe"
        case .trToWord: return "Türkçe → Almanca"
        case .sentence: return "Cümle anlamı"
        case .cloze: return "Boşluk doldur"
        case .order: return "Cümle kur"
        case .listen: return "Dinle ve seç (Hören)"
        case .hoeren: return "Sınav dinlemesi (Hören 1–3)"
        case .write: return "Yaz (Schreiben)"
        case .plural: return "Çoğul halleri"
        case .verbs: return "Fiiller ve Perfekt"
        case .grammar: return "Gramer soruları"
        case .numbers: return "Sayı, saat ve tarih"
        case .reading: return "Okuma (Lesen)"
        case .daily: return "Ne dersin? · Hatayı bul"
        }
    }

    var subtitle: String {
        switch self {
        case .artikel: return "İsmin artikelini seç"
        case .wordToTr: return "Almanca kelimenin anlamı"
        case .trToWord: return "Türkçe kelimenin Almancası"
        case .sentence: return "Almanca cümlenin Türkçesi"
        case .cloze: return "Cümledeki eksik kelime"
        case .order: return "Kelimeleri doğru sıraya diz"
        case .listen: return "Kelime, cümle, sayı ve saat dinle"
        case .hoeren: return "Diyalog, anons, telefon mesajı · 2 kez"
        case .write: return "Kelime, dikte ve düzeltme yaz"
        case .plural: return "die … hangi çoğul?"
        case .verbs: return "er-formu, haben / sein + Partizip II"
        case .grammar: return "22 A1 gramer konusu"
        case .numbers: return "Sayılar, saatler, sıra sayıları"
        case .reading: return "20 metin, sınav tipi sorular"
        case .daily: return "Durumlar ve sık yapılan hatalar"
        }
    }

    var icon: String {
        switch self {
        case .artikel: return "textformat"
        case .wordToTr: return "character.book.closed"
        case .trToWord: return "arrow.left.arrow.right"
        case .sentence: return "text.quote"
        case .cloze: return "square.dashed"
        case .order: return "square.stack.3d.up"
        case .listen: return "ear"
        case .hoeren: return "headphones"
        case .write: return "pencil"
        case .plural: return "square.on.square"
        case .verbs: return "clock.arrow.circlepath"
        case .grammar: return "books.vertical"
        case .numbers: return "number"
        case .reading: return "doc.text"
        case .daily: return "bubble.left.and.bubble.right"
        }
    }
}

enum A1Kind {
    case choice
    case order
    case typing
}

struct A1Question: Identifiable {
    let id: String
    let mode: A1Mode
    let kind: A1Kind
    let label: String
    var theme: Int? = nil
    var topic: Int? = nil
    let prompt: String
    var detail: String? = nil
    var context: String? = nil
    var speakFirst: String? = nil
    var speakAfter: String? = nil
    var dialog: [A1Line]? = nil
    var options: [String] = []
    let answer: String
    var accepted: [String] = []
    var explanation: String? = nil
}

private func a1Core(_ token: String) -> String {
    token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…"))
}

func a1Normalize(_ text: String) -> String {
    let lowered = text.lowercased()
    let cleaned = lowered.unicodeScalars.map { scalar -> String in
        ".,!?;:„“\"()–…".unicodeScalars.contains(scalar) ? " " : String(scalar)
    }.joined()
    return cleaned.split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
}

func a1GermanNumber(_ n: Int) -> String {
    let ones = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn",
                "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"]
    let tens = ["", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
    if n < 20 { return ones[n] }
    if n < 100 {
        let unit = n % 10
        let ten = tens[n / 10]
        if unit == 0 { return ten }
        return (unit == 1 ? "ein" : ones[unit]) + "und" + ten
    }
    if n < 1000 {
        let hundreds = n / 100
        let rest = n % 100
        let head = (hundreds == 1 ? "ein" : ones[hundreds]) + "hundert"
        return rest == 0 ? head : head + a1GermanNumber(rest)
    }
    if n < 1_000_000 {
        var head = a1GermanNumber(n / 1000)
        if head.hasSuffix("eins") { head = String(head.dropLast()) }
        let rest = n % 1000
        head += "tausend"
        return rest == 0 ? head : head + a1GermanNumber(rest)
    }
    return "\(n)"
}

/// 1998 → neunzehnhundertachtundneunzig, 2024 → zweitausendvierundzwanzig
func a1Year(_ year: Int) -> String {
    if year >= 1100 && year < 2000 {
        let rest = year % 100
        return a1GermanNumber(year / 100) + "hundert" + (rest == 0 ? "" : a1GermanNumber(rest))
    }
    return a1GermanNumber(year)
}

/// 3,50 € → drei Euro fünfzig
func a1Price(_ euro: Int, _ cent: Int) -> String {
    let e = euro == 1 ? "ein Euro" : "\(a1GermanNumber(euro)) Euro"
    return cent == 0 ? e : "\(e) \(a1GermanNumber(cent))"
}

/// Building blocks of a number below 1000: 347 → drei · hundert · sieben · und · vierzig
func a1NumberPieces(_ n: Int) -> [String] {
    var pieces: [String] = []
    let hundreds = n / 100
    let rest = n % 100
    if hundreds > 0 { pieces += [hundreds == 1 ? "ein" : a1GermanNumber(hundreds), "hundert"] }
    if rest > 0 {
        if rest < 20 || rest % 10 == 0 {
            pieces.append(a1GermanNumber(rest))
        } else {
            let unit = rest % 10
            pieces += [unit == 1 ? "ein" : a1GermanNumber(unit), "und", a1GermanNumber(rest - unit)]
        }
    }
    if pieces.isEmpty { pieces = ["null"] }
    return pieces
}

/// Accepted spellings: "hundert" for "einhundert", "tausend" for "eintausend".
func a1NumberAlternatives(_ word: String) -> [String] {
    var result: [String] = []
    if word.hasPrefix("einhundert") { result.append(String(word.dropFirst(3))) }
    if word.hasPrefix("eintausend") { result.append(String(word.dropFirst(3))) }
    return result
}

private func a1Ordinal(_ n: Int) -> String {
    switch n {
    case 1: return "erste"
    case 3: return "dritte"
    case 7: return "siebte"
    case 8: return "achte"
    default: return n < 20 ? a1GermanNumber(n) + "te" : a1GermanNumber(n) + "ste"
    }
}

private func a1HourWord(_ h: Int) -> String {
    let hour = ((h - 1) % 12 + 12) % 12 + 1
    return hour == 1 ? "eins" : a1GermanNumber(hour)
}

private func a1TimePhrase(_ h: Int, _ m: Int) -> String {
    let now = a1HourWord(h)
    let next = a1HourWord(h + 1)
    switch m {
    case 0: return (h % 12 == 1 ? "ein" : now) + " Uhr"
    case 5: return "fünf nach \(now)"
    case 10: return "zehn nach \(now)"
    case 15: return "Viertel nach \(now)"
    case 20: return "zwanzig nach \(now)"
    case 25: return "fünf vor halb \(next)"
    case 30: return "halb \(next)"
    case 35: return "fünf nach halb \(next)"
    case 40: return "zwanzig vor \(next)"
    case 45: return "Viertel vor \(next)"
    case 50: return "zehn vor \(next)"
    default: return "fünf vor \(next)"
    }
}

/// Builds every question once. Ids are stable, so answered questions are never asked again.
struct A1BankBuilder {
    static let coreTheme = 15
    let content: A1Content
    private let allExampleTr: [String]
    private var out: [A1Question] = []

    init(content: A1Content) {
        self.content = content
        allExampleTr = content.words.flatMap { $0.ex.map(\.tr) }
    }

    private func themeName(_ id: Int) -> String {
        id < content.themes.count ? content.themes[id].de : "A1"
    }

    private func topicName(_ id: Int) -> String {
        content.grammar.first { $0.id == id }?.de ?? "Grammatik"
    }

    /// Up to `count` items from `ordered` that differ from `correct` and from each other.
    private func distinct(_ correct: String, _ ordered: [String], count: Int = 3) -> [String] {
        var used: Set<String> = [a1Normalize(correct)]
        var result: [String] = []
        for item in ordered {
            let key = a1Normalize(item)
            if key.isEmpty || used.contains(key) { continue }
            used.insert(key)
            result.append(item)
            if result.count == count { break }
        }
        return result
    }

    private func options(_ correct: String, _ wrong: [String]) -> [String] {
        ([correct] + wrong).shuffled()
    }

    /// Same-theme candidates first, then the rest.
    private func candidates(for word: A1Word, _ value: (A1Word) -> String?) -> [String] {
        let pool = content.words.filter { $0.id != word.id && $0.group == word.group }
        let near = pool.filter { $0.theme == word.theme }.shuffled().compactMap(value)
        let far = pool.filter { $0.theme != word.theme }.shuffled().compactMap(value)
        return near + far
    }

    private func exampleCandidates(for word: A1Word) -> [String] {
        let near = content.words.filter { $0.theme == word.theme && $0.id != word.id }.flatMap { $0.ex.map(\.tr) }.shuffled()
        let far = (0..<16).compactMap { _ in allExampleTr.randomElement() }
        return Array(near.prefix(12)) + far
    }

    private func wordInfo(_ w: A1Word) -> String {
        var text = "\(w.withArticle) [\(w.pron)] = \(w.tr)"
        if let first = w.ex.first { text += "\n\(first.de) — \(first.tr)" }
        return text
    }

    mutating func build() -> [A1Question] {
        out = []
        addWords()
        addSentences()
        addVerbs()
        addConjugation()
        addCaseDrills()
        addGrammarItems()
        addNumbers()
        addReading()
        addDaily()
        addHoeren()
        return out
    }

    private mutating func addHoeren() {
        let parts = [1: "Teil 1 · Kısa diyalog", 2: "Teil 2 · Anons", 3: "Teil 3 · Telefon mesajı"]
        let names = [0: "Kadın", 1: "Erkek", 2: "Anons"]
        for (index, item) in content.hoeren.enumerated() {
            guard let correct = item.options.first else { continue }
            let isTrueFalse = Set(item.options) == ["Richtig", "Falsch"]
            let transcript = item.lines.map { "\(names[$0.s] ?? "–"): \($0.t)" }.joined(separator: "\n")
            out.append(A1Question(id: "hr-\(index)", mode: .hoeren, kind: .choice, label: "Hören Teil \(item.part)", topic: nil,
                                  prompt: item.q, detail: parts[item.part], dialog: item.lines,
                                  options: isTrueFalse ? ["Richtig", "Falsch"] : item.options.shuffled(), answer: correct,
                                  explanation: "\(transcript)\n\nTürkçesi: \(item.tr)"))
        }
    }

    // MARK: words
    private mutating func addWords() {
        for w in content.words {
            let label = themeName(w.theme)
            if w.isNoun {
                var why = "\(w.type) \(w.de) [\(w.pron)] · \(w.tr)"
                if let pl = w.plural { why += " · Çoğul: die \(pl)" }
                out.append(A1Question(id: "art-\(w.id)", mode: .artikel, kind: .choice, label: label, theme: w.theme, topic: 4,
                                      prompt: "___ \(w.de)", detail: w.tr, speakAfter: w.withArticle,
                                      options: ["der", "die", "das"], answer: w.type, explanation: why))
            }
            let trWrong = distinct(w.tr, candidates(for: w) { $0.tr })
            if trWrong.count == 3 {
                out.append(A1Question(id: "w2t-\(w.id)", mode: .wordToTr, kind: .choice, label: label, theme: w.theme,
                                      prompt: w.withArticle, detail: "[\(w.pron)]", speakAfter: w.withArticle,
                                      options: options(w.tr, trWrong), answer: w.tr, explanation: wordInfo(w)))
                out.append(A1Question(id: "lw-\(w.id)", mode: .listen, kind: .choice, label: label, theme: w.theme,
                                      prompt: "Dinle: bu kelime ne demek?", speakFirst: w.withArticle,
                                      options: options(w.tr, trWrong), answer: w.tr, explanation: wordInfo(w)))
            }
            let deWrong = distinct(w.withArticle, candidates(for: w) { $0.withArticle })
            if deWrong.count == 3 {
                out.append(A1Question(id: "t2w-\(w.id)", mode: .trToWord, kind: .choice, label: label, theme: w.theme,
                                      prompt: w.tr, speakAfter: w.withArticle,
                                      options: options(w.withArticle, deWrong), answer: w.withArticle, explanation: wordInfo(w)))
            }
            let simple = !w.de.contains(",") && !w.de.contains("/") && !w.de.contains("(") && !w.de.contains("…")
            if simple {
                out.append(A1Question(id: "wr-\(w.id)", mode: .write, kind: .typing, label: label, theme: w.theme,
                                      prompt: w.tr, detail: w.isNoun || w.type == "pl" ? "Artikeliyle birlikte yaz" : "Almancasını yaz",
                                      speakAfter: w.withArticle, answer: w.withArticle, explanation: wordInfo(w)))
            }
            if w.isNoun, let pl = w.plural {
                let fake = pluralDistractors(w.de, real: pl).map { "die \($0)" }
                let wrong = distinct("die \(pl)", fake)
                if wrong.count >= 2 {
                    out.append(A1Question(id: "pl-\(w.id)", mode: .plural, kind: .choice, label: label, theme: w.theme, topic: 5,
                                          prompt: "\(w.type) \(w.de) → çoğulu?", detail: w.tr, speakAfter: "die \(pl)",
                                          options: options("die \(pl)", wrong), answer: "die \(pl)",
                                          explanation: "\(w.type) \(w.de) → die \(pl). Çoğulda artikel hep „die“."))
                }
            }
        }
    }

    private func umlaut(_ word: String) -> String {
        var chars = Array(word)
        var i = chars.count - 1
        while i >= 0 {
            let c = chars[i]
            if c == "u", i > 0, chars[i - 1] == "a" {
                chars[i - 1] = "ä"
                return String(chars)
            }
            if c == "a" || c == "o" || c == "u" {
                chars[i] = c == "a" ? "ä" : (c == "o" ? "ö" : "ü")
                return String(chars)
            }
            i -= 1
        }
        return word
    }

    private func pluralDistractors(_ s: String, real: String) -> [String] {
        let u = umlaut(s)
        let base = s.hasSuffix("e") ? String(s.dropLast()) : s
        return [s + "e", s + "en", s + "n", s + "er", s + "s", u + "e", u + "er", u, s, base + "en", s + "nen"]
            .filter { $0 != real }.shuffled()
    }

    // MARK: sentences
    private mutating func addSentences() {
        let allInfinitives = content.words.filter { $0.type == "verb" && !$0.de.contains(" ") }.map(\.de)
        let allErForms = content.words.compactMap { w -> String? in
            guard let er = w.er else { return nil }
            let parts = er.split(separator: " ")
            return parts.count == 2 ? String(parts[1]) : nil
        }
        let allPartizips = content.words.compactMap { w -> String? in
            guard let p = w.perfekt else { return nil }
            let parts = p.split(separator: " ")
            return parts.count == 2 ? String(parts[1]) : nil
        }
        let nounForms = content.words.filter { $0.isNoun && !$0.de.contains(" ") }.map(\.de)
        let smallWords = content.words.filter { $0.type == "word" && !$0.de.contains(" ") && !$0.de.contains(",") }.map(\.de)

        for w in content.words {
            let label = themeName(w.theme)
            let pool = exampleCandidates(for: w)
            for (index, ex) in w.ex.enumerated() {
                let key = "\(w.id)-\(index)"
                let info = "\(ex.de)\n[\(ex.pron)]\n\(ex.tr)"
                let wrong = distinct(ex.tr, pool)
                if wrong.count == 3 {
                    out.append(A1Question(id: "sen-\(key)", mode: .sentence, kind: .choice, label: label, theme: w.theme,
                                          prompt: ex.de, detail: "[\(ex.pron)]", speakAfter: ex.de,
                                          options: options(ex.tr, wrong), answer: ex.tr, explanation: info))
                    out.append(A1Question(id: "ls-\(key)", mode: .listen, kind: .choice, label: label, theme: w.theme,
                                          prompt: "Dinle: cümle ne anlama geliyor?", speakFirst: ex.de,
                                          options: options(ex.tr, distinct(ex.tr, pool.shuffled())), answer: ex.tr, explanation: info))
                }
                let tokens = ex.de.split(separator: " ").map(String.init)
                if tokens.count >= 3 && tokens.count <= 10 {
                    var shuffled = tokens.shuffled()
                    var tries = 0
                    while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
                    out.append(A1Question(id: "ord-\(key)", mode: .order, kind: .order, label: label, theme: w.theme, topic: 10,
                                          prompt: ex.tr, detail: "Kelimeleri doğru sıraya diz", speakAfter: ex.de,
                                          options: shuffled, answer: tokens.joined(separator: " "), explanation: info))
                }
                if tokens.count <= 8 {
                    out.append(A1Question(id: "dik-\(key)", mode: .write, kind: .typing, label: label, theme: w.theme,
                                          prompt: "Dikte: duyduğun cümleyi yaz", detail: ex.tr, speakFirst: ex.de,
                                          answer: ex.de, explanation: info))
                }
                if let cloze = makeCloze(w, ex, tokens: tokens, infinitives: allInfinitives, erForms: allErForms,
                                         partizips: allPartizips, nouns: nounForms, small: smallWords) {
                    out.append(A1Question(id: "clz-\(key)", mode: .cloze, kind: .choice, label: label, theme: w.theme,
                                          prompt: cloze.prompt, detail: ex.tr, speakAfter: ex.de,
                                          options: options(cloze.answer, cloze.wrong), answer: cloze.answer, explanation: info))
                }
            }
        }
        for text in content.texts {
            for (index, line) in text.de.enumerated() {
                let tokens = line.split(separator: " ").map(String.init)
                guard tokens.count >= 3 && tokens.count <= 11 else { continue }
                var shuffled = tokens.shuffled()
                var tries = 0
                while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
                out.append(A1Question(id: "ordt-\(text.id)-\(index)", mode: .order, kind: .order, label: "Text \(text.id): \(text.title)",
                                      topic: 10, prompt: "Metinden bir cümle kur", detail: text.titleTr, speakAfter: line,
                                      options: shuffled, answer: tokens.joined(separator: " "), explanation: line))
                if tokens.count <= 9 {
                    out.append(A1Question(id: "dikt-\(text.id)-\(index)", mode: .write, kind: .typing, label: "Text \(text.id): \(text.title)",
                                          prompt: "Dikte: duyduğun cümleyi yaz", detail: text.titleTr, speakFirst: line,
                                          answer: line, explanation: line))
                }
            }
        }
    }

    private func matchCase(_ word: String, like model: String) -> String {
        guard let first = model.first, let wFirst = word.first else { return word }
        if first.isUppercase && !wFirst.isUppercase { return wFirst.uppercased() + word.dropFirst() }
        if !first.isUppercase && wFirst.isUppercase { return wFirst.lowercased() + word.dropFirst() }
        return word
    }

    private func makeCloze(_ w: A1Word, _ ex: A1Example, tokens: [String], infinitives: [String], erForms: [String],
                           partizips: [String], nouns: [String], small: [String]) -> (prompt: String, answer: String, wrong: [String])? {
        var forms: [(String, [String])] = []
        if w.isNoun || w.type == "pl" {
            forms.append((w.de, nouns))
            if let pl = w.plural, pl != w.de { forms.append((pl, nouns)) }
        } else if w.type == "verb" {
            forms.append((w.de, infinitives))
            if let er = w.er {
                let parts = er.split(separator: " ")
                if parts.count == 2 { forms.append((String(parts[1]), erForms)) }
            }
            if let p = w.perfekt {
                let parts = p.split(separator: " ")
                if parts.count == 2 { forms.append((String(parts[1]), partizips)) }
            }
        } else if !w.de.contains(" ") && !w.de.contains(",") {
            forms.append((w.de, small))
        }
        for (form, pool) in forms where !form.contains(" ") {
            guard let index = tokens.firstIndex(where: { a1Core($0).lowercased() == form.lowercased() }) else { continue }
            let original = a1Core(tokens[index])
            let wrong = distinct(original, pool.shuffled().map { matchCase($0, like: original) })
            guard wrong.count == 3 else { continue }
            var blanked = tokens
            if let range = blanked[index].range(of: original) {
                blanked[index].replaceSubrange(range, with: "_____")
            }
            return (blanked.joined(separator: " "), original, wrong)
        }
        return nil
    }

    // MARK: verbs
    private mutating func addVerbs() {
        for w in content.words where w.type == "verb" {
            let label = themeName(w.theme)
            let stem: String = {
                if w.de.hasSuffix("en") { return String(w.de.dropLast(2)) }
                if w.de.hasSuffix("n") { return String(w.de.dropLast()) }
                return w.de
            }()
            if let p = w.perfekt {
                let parts = p.split(separator: " ").map(String.init)
                if parts.count == 2 {
                    let aux = parts[0]
                    let part = parts[1]
                    var wrong: [String] = []
                    if aux == "hat" || aux == "ist" {
                        wrong.append("\(aux == "hat" ? "ist" : "hat") \(part)")
                    }
                    let fakeParts = ["ge\(stem)t", "ge\(stem)en", "\(stem)t", "ge\(w.de)", "\(w.de)t"].filter { $0 != part }.shuffled()
                    for fake in fakeParts {
                        wrong.append("\(aux) \(fake)")
                        if aux == "hat" || aux == "ist" { wrong.append("\(aux == "hat" ? "ist" : "hat") \(fake)") }
                    }
                    let picked = distinct("er \(p)", wrong.map { "er \($0)" })
                    if picked.count == 3 {
                        out.append(A1Question(id: "pf-\(w.id)", mode: .verbs, kind: .choice, label: label, theme: w.theme, topic: 15,
                                              prompt: "\(w.de) → Perfekt (er)", detail: w.tr, speakAfter: "er \(p)",
                                              options: options("er \(p)", picked), answer: "er \(p)",
                                              explanation: "\(w.de): \(w.er ?? "") · \(p). Hareket/değişim fiilleri ve bleiben → ist."))
                    }
                }
            }
            if let er = w.er {
                let parts = er.split(separator: " ").map(String.init)
                if parts.count == 2 && parts[0] == "er" {
                    let fake = ["\(stem)t", "\(stem)et", w.de, "\(stem)st", "\(stem)e"].filter { $0 != parts[1] }.map { "er \($0)" }
                    let wrong = distinct(er, fake.shuffled())
                    if wrong.count == 3 {
                        out.append(A1Question(id: "er-\(w.id)", mode: .verbs, kind: .choice, label: label, theme: w.theme, topic: 3,
                                              prompt: "\(w.de) → er / sie / es …?", detail: w.tr, speakAfter: er,
                                              options: options(er, wrong), answer: er,
                                              explanation: "\(w.de): \(er) · \(w.perfekt ?? "")"))
                    }
                }
            }
        }
    }

    private static let persons = ["ich", "du", "er / sie / es", "wir", "ihr", "sie / Sie"]

    private static func regular(_ verb: String) -> [String] {
        let stem = String(verb.dropLast(verb.hasSuffix("en") ? 2 : 1))
        let ending = verb.hasSuffix("en") ? "en" : "n"
        let needsE = stem.hasSuffix("t") || stem.hasSuffix("d")
        let sibilant = stem.hasSuffix("s") || stem.hasSuffix("ß") || stem.hasSuffix("z")
        let e = needsE ? "e" : ""
        return [stem + "e", stem + (sibilant ? "t" : e + "st"), stem + e + "t", stem + ending, stem + e + "t", stem + ending]
    }

    private static let tables: [(verb: String, forms: [String], topic: Int)] = {
        var list: [(verb: String, forms: [String], topic: Int)] = [
            ("sein", ["bin", "bist", "ist", "sind", "seid", "sind"], 1),
            ("haben", ["habe", "hast", "hat", "haben", "habt", "haben"], 1),
            ("sprechen", ["spreche", "sprichst", "spricht", "sprechen", "sprecht", "sprechen"], 3),
            ("essen", ["esse", "isst", "isst", "essen", "esst", "essen"], 3),
            ("nehmen", ["nehme", "nimmst", "nimmt", "nehmen", "nehmt", "nehmen"], 3),
            ("lesen", ["lese", "liest", "liest", "lesen", "lest", "lesen"], 3),
            ("sehen", ["sehe", "siehst", "sieht", "sehen", "seht", "sehen"], 3),
            ("geben", ["gebe", "gibst", "gibt", "geben", "gebt", "geben"], 3),
            ("helfen", ["helfe", "hilfst", "hilft", "helfen", "helft", "helfen"], 3),
            ("fahren", ["fahre", "fährst", "fährt", "fahren", "fahrt", "fahren"], 3),
            ("schlafen", ["schlafe", "schläfst", "schläft", "schlafen", "schlaft", "schlafen"], 3),
            ("laufen", ["laufe", "läufst", "läuft", "laufen", "lauft", "laufen"], 3),
            ("tragen", ["trage", "trägst", "trägt", "tragen", "tragt", "tragen"], 3),
            ("wissen", ["weiß", "weißt", "weiß", "wissen", "wisst", "wissen"], 3),
            ("können", ["kann", "kannst", "kann", "können", "könnt", "können"], 12),
            ("müssen", ["muss", "musst", "muss", "müssen", "müsst", "müssen"], 12),
            ("wollen", ["will", "willst", "will", "wollen", "wollt", "wollen"], 12),
            ("dürfen", ["darf", "darfst", "darf", "dürfen", "dürft", "dürfen"], 12),
            ("sollen", ["soll", "sollst", "soll", "sollen", "sollt", "sollen"], 12),
            ("möchten", ["möchte", "möchtest", "möchte", "möchten", "möchtet", "möchten"], 12),
            ("sein (Präteritum)", ["war", "warst", "war", "waren", "wart", "waren"], 16),
            ("haben (Präteritum)", ["hatte", "hattest", "hatte", "hatten", "hattet", "hatten"], 16),
        ]
        let regularVerbs = ["wohnen", "arbeiten", "heißen", "kommen", "machen", "spielen", "lernen", "kaufen", "trinken",
                            "gehen", "kochen", "hören", "brauchen", "fragen", "suchen", "schreiben", "bleiben", "singen",
                            "schwimmen", "bezahlen", "besuchen", "kosten", "finden", "warten", "reisen", "tanzen", "sagen",
                            "zeigen", "lieben", "glauben", "studieren", "telefonieren", "antworten", "duschen", "parken"]
        for verb in regularVerbs { list.append((verb: verb, forms: A1BankBuilder.regular(verb), topic: 2)) }
        return list
    }()

    private mutating func addConjugation() {
        for table in A1BankBuilder.tables {
            for (index, person) in A1BankBuilder.persons.enumerated() {
                let correct = table.forms[index]
                let wrong = distinct(correct, table.forms.shuffled())
                let extra = distinct(correct, (wrong + [table.verb, correct + "t", correct + "n"]).shuffled())
                let picked = wrong.count == 3 ? wrong : extra
                guard picked.count == 3 else { continue }
                out.append(A1Question(id: "cj-\(table.verb)-\(index)", mode: .grammar, kind: .choice, label: topicName(table.topic),
                                      topic: table.topic, prompt: "\(person) _____  (\(table.verb))",
                                      speakAfter: "\(person.components(separatedBy: " / ").first ?? person) \(correct)",
                                      options: options(correct, picked), answer: correct,
                                      explanation: "\(table.verb): " + zip(A1BankBuilder.persons, table.forms).map { "\($0) \($1)" }.joined(separator: " · ")))
            }
        }
    }

    // MARK: Akkusativ, Dativ, possessive, kein
    private mutating func addCaseDrills() {
        let objectThemes: Set<Int> = [4, 5, 6, 7]
        let people = content.words.filter { $0.isNoun && ($0.theme == 1 || $0.theme == 8) }
        for w in content.words where w.isNoun && !w.de.contains(" ") {
            let label = themeName(w.theme)
            if objectThemes.contains(w.theme) {
                let indefinite = w.type == "der" ? "einen" : (w.type == "die" ? "eine" : "ein")
                out.append(A1Question(id: "akk-\(w.id)", mode: .grammar, kind: .choice, label: topicName(6), theme: w.theme, topic: 6,
                                      prompt: "Ich brauche _____ \(w.de).", detail: "\(w.tr) (\(w.type))", speakAfter: "Ich brauche \(indefinite) \(w.de).",
                                      options: ["ein", "eine", "einen", "einem"], answer: indefinite,
                                      explanation: "brauchen + Akkusativ: \(w.type) \(w.de) → \(indefinite) \(w.de). Sadece eril değişir (ein → einen)."))
                let negative = "k" + indefinite
                out.append(A1Question(id: "kein-\(w.id)", mode: .grammar, kind: .choice, label: topicName(11), theme: w.theme, topic: 11,
                                      prompt: "Ich habe _____ \(w.de).", detail: "\(w.tr) (\(w.type))", speakAfter: "Ich habe \(negative) \(w.de).",
                                      options: ["kein", "keine", "keinen", "nicht"], answer: negative,
                                      explanation: "haben + Akkusativ: \(w.type) \(w.de) → \(negative) \(w.de). Artikelsiz/ein'li isim kein ile olumsuz olur."))
                let definite = w.type == "der" ? "den" : w.type
                out.append(A1Question(id: "akd-\(w.id)", mode: .grammar, kind: .choice, label: topicName(6), theme: w.theme, topic: 6,
                                      prompt: "Ich suche _____ \(w.de).", detail: "\(w.tr) (\(w.type))", speakAfter: "Ich suche \(definite) \(w.de).",
                                      options: (Array(["der", "den", "die", "das", "dem"].filter { $0 != definite }.shuffled().prefix(3)) + [definite]).shuffled(),
                                      answer: definite,
                                      explanation: "suchen + Akkusativ: \(w.type) → \(definite). der → den; die ve das değişmez."))
            }
        }
        for w in people where !w.de.contains(" ") {
            let dative = w.type == "die" ? "der" : "dem"
            out.append(A1Question(id: "dat-\(w.id)", mode: .grammar, kind: .choice, label: topicName(7), theme: w.theme, topic: 7,
                                  prompt: "Ich spreche mit _____ \(w.de).", detail: "\(w.tr) (\(w.type))", speakAfter: "Ich spreche mit \(dative) \(w.de).",
                                  options: ["dem", "der", "den", "die"], answer: dative,
                                  explanation: "mit + Dativ: der/das → dem, die → der."))
            let owners: [(String, String)] = [("ich", "mein"), ("du", "dein"), ("er", "sein"), ("sie", "ihr"), ("wir", "unser"), ("ihr", "euer"), ("Sie", "Ihr")]
            for (index, owner) in owners.enumerated() {
                let feminine = w.type == "die"
                let base = owner.1
                let correct = feminine ? (base == "euer" ? "eure" : base + "e") : base
                let accusative = base == "euer" ? "euren" : base + "en"
                let otherBase = owners[(index + 2) % owners.count].1
                let wrong = distinct(correct, [feminine ? base : base + "e", accusative, otherBase + (feminine ? "e" : "")])
                out.append(A1Question(id: "pos-\(w.id)-\(index)", mode: .grammar, kind: .choice, label: topicName(9), theme: w.theme, topic: 9,
                                      prompt: "(\(owner.0)) Das ist _____ \(w.de).", detail: "\(w.tr) (\(w.type))",
                                      speakAfter: "Das ist \(correct) \(w.de).", options: options(correct, wrong), answer: correct,
                                      explanation: "\(owner.0) → \(base). \(w.type) \(w.de) → \(correct) \(w.de)."))
            }
        }
    }

    private mutating func addGrammarItems() {
        for (index, item) in content.grammarItems.enumerated() {
            guard let correct = item.options.first else { continue }
            out.append(A1Question(id: "gr-\(index)", mode: .grammar, kind: .choice, label: topicName(item.topic), topic: item.topic,
                                  prompt: item.q, speakAfter: item.q.replacingOccurrences(of: "___", with: correct.replacingOccurrences(of: " … ", with: " ")),
                                  options: item.options.shuffled(), answer: correct, explanation: item.why))
        }
    }

    // MARK: numbers, time, dates
    private mutating func addNumbers() {
        for n in 0...999 {
            let word = a1GermanNumber(n)
            var near = [n + 1, n - 1, n + 10, n - 10, n + 100, n - 100]
            let swapped = (n / 100) * 100 + (n % 10) * 10 + (n / 10) % 10
            near.insert(swapped, at: 0)
            let valid = near.filter { $0 >= 0 && $0 <= 999 && $0 != n }
            let wrongWords = distinct(word, valid.map(a1GermanNumber))
            let wrongDigits = distinct("\(n)", valid.map { "\($0)" })
            out.append(A1Question(id: "num-\(n)", mode: .numbers, kind: .choice, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: "\(n)", detail: "Almancası hangisi?", speakAfter: word,
                                  options: options(word, wrongWords), answer: word, explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "lnum-\(n)", mode: .listen, kind: .choice, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: "Dinle: hangi sayı?", speakFirst: "\(n)",
                                  options: options("\(n)", wrongDigits), answer: "\(n)", explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "wnum-\(n)", mode: .write, kind: .typing, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: "\(n)", detail: "Sayıyı Almanca yaz (bitişik)", speakAfter: word, answer: word,
                                  accepted: a1NumberAlternatives(word), explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "numr-\(n)", mode: .numbers, kind: .choice, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: word, detail: "Bu hangi sayı?", speakAfter: word,
                                  options: options("\(n)", wrongDigits), answer: "\(n)", explanation: "\(word) = \(n)"))
            out.append(A1Question(id: "numd-\(n)", mode: .write, kind: .typing, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: "Dinle ve sayıyı rakamla yaz", detail: "Örnek: 347", speakFirst: word, answer: "\(n)",
                                  explanation: "\(word) = \(n)"))
            let pieces = a1NumberPieces(n)
            if pieces.count >= 3 {
                var shuffled = pieces.shuffled()
                var tries = 0
                while shuffled == pieces && tries < 5 { shuffled.shuffle(); tries += 1 }
                out.append(A1Question(id: "nb-\(n)", mode: .numbers, kind: .order, label: "Zahlen bauen", theme: 3, topic: 19,
                                      prompt: "\(n)", detail: "Parçaları sırala: önce yüzler, sonra birler + und + onlar",
                                      speakAfter: word, options: shuffled, answer: pieces.joined(separator: " "),
                                      explanation: "\(n) = \(word)\nAlmancada birler basamağı onlardan önce söylenir: 47 = sieben-und-vierzig."))
            }
        }
        addBigNumbers()
        for h in 1...12 {
            for m in stride(from: 0, through: 55, by: 5) {
                let correct = a1TimePhrase(h, m)
                let clock = String(format: "%d:%02d", h, m)
                var fakes = [a1TimePhrase(h + 1, m), a1TimePhrase(h - 1 + 12, m), a1TimePhrase(h, (60 - m) % 60)]
                fakes += [a1TimePhrase(h, (m + 30) % 60), a1TimePhrase(h + 1, (m + 15) % 60)]
                let wrong = distinct(correct, fakes)
                if wrong.count == 3 {
                    out.append(A1Question(id: "tm-\(h)-\(m)", mode: .numbers, kind: .choice, label: "Uhrzeit", theme: 3, topic: 19,
                                          prompt: "Saat \(clock) — günlük konuşmada?", speakAfter: "Es ist \(correct).",
                                          options: options(correct, wrong), answer: correct,
                                          explanation: "\(clock) = \(correct). Dikkat: halb + sonraki saat (halb neun = 8:30)."))
                }
                let clockWrong = distinct(clock, [String(format: "%d:%02d", h % 12 + 1, m), String(format: "%d:%02d", (h + 10) % 12 + 1, m),
                                                  String(format: "%d:%02d", h, (60 - m) % 60), String(format: "%d:%02d", h, (m + 30) % 60)])
                if clockWrong.count == 3 {
                    out.append(A1Question(id: "tmr-\(h)-\(m)", mode: .listen, kind: .choice, label: "Uhrzeit", theme: 3, topic: 19,
                                          prompt: "Dinle: saat kaç?", speakFirst: "Es ist \(correct).",
                                          options: options(clock, clockWrong), answer: clock, explanation: "\(correct) = \(clock)"))
                }
            }
        }
        for h in 0...23 {
            for m in stride(from: 0, through: 55, by: 5) {
                let official = m == 0 ? "\(h == 1 ? "ein" : a1GermanNumber(h)) Uhr" : "\(h == 1 ? "ein" : a1GermanNumber(h)) Uhr \(a1GermanNumber(m))"
                let clock = String(format: "%02d:%02d", h, m)
                let wrong = distinct(clock, [String(format: "%02d:%02d", m < 24 ? m : (h + 1) % 24, m < 24 ? h : m),
                                             String(format: "%02d:%02d", (h + 1) % 24, m), String(format: "%02d:%02d", (h + 12) % 24, m),
                                             String(format: "%02d:%02d", h, (m + 10) % 60)])
                guard wrong.count == 3 else { continue }
                out.append(A1Question(id: "tmo-\(h)-\(m)", mode: .numbers, kind: .choice, label: "Uhrzeit (resmî)", theme: 3, topic: 19,
                                      prompt: "„\(official)“", detail: "Tren/radyo saati – hangisi?", speakAfter: official,
                                      options: options(clock, wrong), answer: clock, explanation: "\(official) = \(clock)"))
            }
        }
        let months = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
        for day in 1...31 {
            let month = months[(day * 5) % 12]
            let correct = a1Ordinal(day)
            let wrong = distinct(correct, [a1GermanNumber(day), a1GermanNumber(day) + "ste", a1GermanNumber(day) + "te",
                                           a1Ordinal(day % 31 + 1), a1GermanNumber(day) + "e"])
            out.append(A1Question(id: "ord-day-\(day)", mode: .numbers, kind: .choice, label: "Datum", theme: 3, topic: 19,
                                  prompt: "Heute ist der _____ \(month).  (\(day).)", speakAfter: "Heute ist der \(correct) \(month).",
                                  options: options(correct, wrong), answer: correct,
                                  explanation: "\(day). = der \(correct). 1.–19. → -te (erste, dritte, siebte), 20. ve sonrası → -ste."))
            let dative = correct + "n"
            out.append(A1Question(id: "ord-am-\(day)", mode: .numbers, kind: .choice, label: "Datum", theme: 3, topic: 19,
                                  prompt: "Ich habe am _____ \(month) Geburtstag.  (\(day).)", speakAfter: "Ich habe am \(dative) \(month) Geburtstag.",
                                  options: options(dative, distinct(dative, [correct, a1GermanNumber(day) + "en", a1Ordinal(day % 31 + 1) + "n", a1GermanNumber(day)])),
                                  answer: dative, explanation: "am + sıra sayısı -en: am \(dative) \(month)."))
        }
    }

    private mutating func addBigNumbers() {
        // Thousands: rents, prices, distances.
        let samples = [1000, 1200, 1500, 2000, 2500, 3400, 5000, 7800, 10_000, 12_500, 15_000, 20_000, 25_000, 50_000,
                       75_300, 100_000, 250_000, 1050, 1999, 4321, 6060, 8888, 9100, 11_111, 30_400, 64_000, 99_999]
        for n in samples {
            let word = a1GermanNumber(n)
            let wrong = distinct(word, [n * 10, n / 10, n + 1000, n + 100, n - 100].filter { $0 > 0 && $0 < 1_000_000 }.map(a1GermanNumber))
            guard wrong.count == 3 else { continue }
            out.append(A1Question(id: "big-\(n)", mode: .numbers, kind: .choice, label: "Große Zahlen", theme: 3, topic: 19,
                                  prompt: n.formatted(.number.locale(Locale(identifier: "de_DE"))), detail: "Almancası hangisi?", speakAfter: word,
                                  options: options(word, wrong), answer: word, explanation: "\(n) = \(word)"))
        }
        // Years: Ich bin 1998 geboren.
        for year in stride(from: 1950, through: 2030, by: 1) {
            let word = a1Year(year)
            let wrong = distinct(word, [a1GermanNumber(year), a1Year(year + 10), a1Year(year - 1), a1Year(year + 1), "tausend" + a1GermanNumber(year % 1000)])
            guard wrong.count == 3 else { continue }
            out.append(A1Question(id: "yr-\(year)", mode: .numbers, kind: .choice, label: "Jahreszahlen", theme: 3, topic: 19,
                                  prompt: "Ich bin \(year) geboren.", detail: "Yıl nasıl okunur?", speakAfter: "Ich bin \(word) geboren.",
                                  options: options(word, wrong), answer: word,
                                  explanation: "\(year) = \(word). 1100–1999 arası yıllar „yüzler“le okunur (neunzehnhundert…), 2000'den sonrası normal sayı gibi."))
            if year % 4 == 0 {
                out.append(A1Question(id: "lyr-\(year)", mode: .listen, kind: .choice, label: "Jahreszahlen", theme: 3, topic: 19,
                                      prompt: "Dinle: hangi yıl?", speakFirst: "Ich bin \(word) geboren.",
                                      options: options("\(year)", distinct("\(year)", ["\(year + 1)", "\(year - 10)", "\(year + 20)", "\(year - 1)"])),
                                      answer: "\(year)", explanation: "\(word) = \(year)"))
            }
        }
        // Prices.
        let cents = [0, 10, 20, 49, 50, 75, 80, 90, 95, 99]
        for euro in 1...30 {
            let cent = cents[(euro * 7) % cents.count]
            let price = String(format: "%d,%02d €", euro, cent)
            let word = a1Price(euro, cent)
            let wrong = distinct(word, [a1Price(euro + 1, cent), a1Price(euro, (cent + 30) % 100), a1Price(cent > 0 && cent < 31 ? cent : euro + 10, euro % 100),
                                        a1Price(max(1, euro - 1), cent)])
            guard wrong.count == 3 else { continue }
            out.append(A1Question(id: "pr-\(euro)", mode: .numbers, kind: .choice, label: "Preise", theme: 3, topic: 19,
                                  prompt: "Das kostet \(price)", detail: "Fiyat nasıl söylenir?", speakAfter: "Das kostet \(word).",
                                  options: options(word, wrong), answer: word, explanation: "\(price) = \(word)"))
            let digits = distinct(price, [String(format: "%d,%02d €", euro + 1, cent), String(format: "%d,%02d €", euro, (cent + 30) % 100),
                                          String(format: "%d,%02d €", max(1, euro - 1), cent)])
            out.append(A1Question(id: "lpr-\(euro)", mode: .listen, kind: .choice, label: "Preise", theme: 3, topic: 19,
                                  prompt: "Dinle: ne kadar?", speakFirst: "Das kostet \(word).",
                                  options: options(price, digits), answer: price, explanation: "\(word) = \(price)"))
        }
    }

    // MARK: reading and daily situations
    private mutating func addReading() {
        for text in content.texts {
            let context = text.de.joined(separator: " ")
            for (index, item) in text.questions.enumerated() {
                guard let correct = item.options.first else { continue }
                let isTrueFalse = Set(item.options) == ["Richtig", "Falsch"]
                out.append(A1Question(id: "rd-\(text.id)-\(index)", mode: .reading, kind: .choice, label: "Text \(text.id): \(text.title)",
                                      prompt: item.q, context: context, speakAfter: context,
                                      options: isTrueFalse ? ["Richtig", "Falsch"] : item.options.shuffled(), answer: correct,
                                      explanation: "Türkçesi: \(text.tr)"))
            }
        }
    }

    private mutating func addDaily() {
        for (index, item) in content.situations.enumerated() {
            guard let correct = item.options.first else { continue }
            out.append(A1Question(id: "sit-\(index)", mode: .daily, kind: .choice, label: "Was sagst du?", topic: 22,
                                  prompt: item.q, detail: "Ne dersin?", speakAfter: correct,
                                  options: item.options.shuffled(), answer: correct, explanation: correct))
        }
        for (index, item) in content.mistakes.enumerated() {
            out.append(A1Question(id: "fx-\(index)", mode: .daily, kind: .choice, label: "Finde den Fehler", topic: 10,
                                  prompt: "Hangi cümle doğru?", speakAfter: item.right,
                                  options: [item.right, item.wrong].shuffled(), answer: item.right,
                                  explanation: "✗ \(item.wrong)\n✓ \(item.right)\n\(item.why)"))
            out.append(A1Question(id: "fxw-\(index)", mode: .write, kind: .typing, label: "Finde den Fehler", topic: 10,
                                  prompt: item.wrong, detail: "Hatayı bul, cümleyi doğru yaz", speakAfter: item.right,
                                  answer: item.right, explanation: item.why))
        }
    }
}

// MARK: - Progress

struct A1SavedState: Codable {
    var seen: Set<String> = []
    var correct: Set<String> = []
    var wrong: [String] = []
    var bestSprint = 0
    var exams: [Int] = []
    var streak = 0
    var lastDay = ""
    var today = 0

    static let key = "a1Progress"
    static let changed = Notification.Name("A1ProgressChanged")

    static func load() -> A1SavedState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(A1SavedState.self, from: data) else { return A1SavedState() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: A1SavedState.key)
        }
    }

    func merged(with other: A1SavedState) -> A1SavedState {
        var result = self
        result.seen.formUnion(other.seen)
        result.correct.formUnion(other.correct)
        for id in other.wrong where !result.wrong.contains(id) && !result.correct.contains(id) { result.wrong.append(id) }
        result.bestSprint = max(bestSprint, other.bestSprint)
        result.exams = exams + other.exams
        result.streak = max(streak, other.streak)
        return result
    }
}

final class A1Model: ObservableObject {
    @Published private(set) var content: A1Content?
    @Published private(set) var questions: [A1Question] = []
    @Published private(set) var ready = false
    private(set) var byID: [String: A1Question] = [:]
    private var modeTotals: [A1Mode: Int] = [:]
    private var a1Total = 0
    @Published private(set) var state: A1SavedState
    private var observer: NSObjectProtocol?

    init() {
        state = A1SavedState.load()
        observer = NotificationCenter.default.addObserver(forName: A1SavedState.changed, object: nil, queue: .main) { [weak self] _ in
            self?.state = A1SavedState.load()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = A1Content.load()
            var built: [A1Question] = []
            if let loaded {
                var builder = A1BankBuilder(content: loaded)
                built = builder.build()
            }
            var map: [String: A1Question] = [:]
            var totals: [A1Mode: Int] = [:]
            var a1 = 0
            for q in built {
                map[q.id] = q
                if !A1Model.isCore(q) {
                    totals[q.mode, default: 0] += 1
                    a1 += 1
                }
            }
            DispatchQueue.main.async {
                self.content = loaded
                self.byID = map
                self.modeTotals = totals
                self.a1Total = a1
                self.questions = built
                self.ready = true
            }
        }
    }

    /// Questions about the extra frequent-word list (not part of the A1 PDF).
    static func isCore(_ q: A1Question) -> Bool { q.theme == A1BankBuilder.coreTheme }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var total: Int { a1Total }
    var learned: Int {
        state.correct.reduce(0) { count, id in
            guard let q = byID[id], !A1Model.isCore(q) else { return count }
            return count + 1
        }
    }
    var coreTotal: Int { questions.count - a1Total }
    var coreLearned: Int { max(0, state.correct.count - learned) }
    var readiness: Double { total == 0 ? 0 : Double(learned) / Double(total) }

    func totalFor(_ mode: A1Mode) -> Int { modeTotals[mode] ?? 0 }

    func seenCount(_ mode: A1Mode) -> Int {
        state.seen.reduce(0) { count, id in
            guard let q = byID[id], q.mode == mode, !A1Model.isCore(q) else { return count }
            return count + 1
        }
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func record(_ q: A1Question, correct: Bool) {
        var s = state
        let today = A1Model.dayString(Date())
        if s.lastDay != today {
            let yesterday = A1Model.dayString(Date().addingTimeInterval(-86_400))
            s.streak = s.lastDay == yesterday ? s.streak + 1 : 1
            s.lastDay = today
            s.today = 0
        }
        s.today += 1
        s.seen.insert(q.id)
        if correct {
            s.correct.insert(q.id)
            s.wrong.removeAll { $0 == q.id }
        } else if !s.wrong.contains(q.id) {
            s.wrong.append(q.id)
        }
        state = s
        s.save()
    }

    func saveSprint(_ score: Int) {
        guard score > state.bestSprint else { return }
        state.bestSprint = score
        state.save()
    }

    func saveExam(_ score: Int) {
        state.exams.append(score)
        state.save()
    }

    func reset(_ mode: A1Mode) {
        var s = state
        s.seen = s.seen.filter { byID[$0]?.mode != mode }
        s.correct = s.correct.filter { byID[$0]?.mode != mode }
        s.wrong.removeAll { byID[$0]?.mode == mode }
        state = s
        s.save()
    }

    /// Never-seen questions only, so the same question is not asked twice.
    func session(mode: A1Mode? = nil, theme: Int? = nil, topic: Int? = nil, count: Int = 20) -> [A1Question] {
        let pool = questions.filter { q in
            (mode == nil || q.mode == mode) && (topic == nil || q.topic == topic) &&
                (theme == nil ? !A1Model.isCore(q) : q.theme == theme) && !state.seen.contains(q.id)
        }
        if mode != nil { return Array(pool.shuffled().prefix(count)) }
        // Mixed: spread the questions over the different games.
        var buckets = Dictionary(grouping: pool.shuffled(), by: \.mode).values.map { Array($0) }
        var result: [A1Question] = []
        while result.count < count && !buckets.isEmpty {
            buckets.shuffle()
            for i in buckets.indices where !buckets[i].isEmpty && result.count < count {
                result.append(buckets[i].removeFirst())
            }
            buckets.removeAll { $0.isEmpty }
        }
        return result.shuffled()
    }

    func mistakeSession(count: Int = 20) -> [A1Question] {
        Array(state.wrong.compactMap { byID[$0] }.shuffled().prefix(count))
    }

    /// Exam rehearsal: listening, reading, writing and grammar like the Goethe/telc A1 modules.
    func examSession() -> [A1Question] {
        func take(_ mode: A1Mode, _ n: Int) -> [A1Question] {
            let pool = questions.filter { $0.mode == mode && !A1Model.isCore($0) }
            let unseen = pool.filter { !state.seen.contains($0.id) }.shuffled()
            let any = pool.shuffled()
            return Array((unseen.count >= n ? unseen : any).prefix(n))
        }
        return take(.hoeren, 6) + take(.listen, 3) + take(.reading, 6) + take(.write, 4) + take(.grammar, 5) +
            take(.cloze, 2) + take(.daily, 2) + take(.sentence, 2)
    }
}

// MARK: - Speech

final class A1Speaker {
    static let shared = A1Speaker()
    private let synth = AVSpeechSynthesizer()

    /// German voices, best quality first (enhanced/premium voices if the user downloaded them).
    private lazy var germanVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("de") }
        .sorted { $0.quality.rawValue > $1.quality.rawValue }

    /// Speaker -1 = default voice, 0 = woman, 1 = man, 2 = announcer.
    /// Without a second voice on the device, the pitch tells the speakers apart.
    private func voice(for speaker: Int) -> (AVSpeechSynthesisVoice?, Float) {
        let fallback = AVSpeechSynthesisVoice(language: "de-DE")
        let female = germanVoices.first { $0.gender == .female }
        let male = germanVoices.first { $0.gender == .male }
        switch speaker {
        case 0:
            if let female { return (female, 1.0) }
            return (fallback, 1.15)
        case 1:
            if let male { return (male, 1.0) }
            return (fallback, 0.8)
        case 2:
            if let male { return (male, 0.9) }
            return (fallback, 0.7)
        default:
            return (fallback, 1.0)
        }
    }

    func say(_ text: String, slow: Bool = false, times: Int = 1) {
        play([A1Line(s: -1, t: text)], slow: slow, times: times)
    }

    /// Plays the lines in order; `times: 2` repeats everything like in the exam.
    func play(_ lines: [A1Line], slow: Bool = false, times: Int = 1) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        for round in 0..<max(1, times) {
            for (index, line) in lines.enumerated() {
                let utterance = AVSpeechUtterance(string: line.t)
                let (chosenVoice, pitch) = voice(for: line.s)
                utterance.voice = chosenVoice
                utterance.pitchMultiplier = pitch
                utterance.rate = slow ? 0.32 : 0.46
                let lastLine = index == lines.count - 1
                utterance.postUtteranceDelay = lastLine ? (round < times - 1 ? 2.0 : 0) : 0.5
                synth.speak(utterance)
            }
        }
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

struct A1SpeakButton: View {
    let text: String
    var slow = false

    var body: some View {
        Button {
            A1Speaker.shared.say(text, slow: slow)
        } label: {
            Image(systemName: slow ? "tortoise.fill" : "speaker.wave.2.fill")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(slow ? "Yavaş dinle" : "Dinle")
    }
}

func a1ArticleColor(_ type: String) -> Color {
    switch type {
    case "der": return .blue
    case "die": return .red
    case "das": return .green
    case "pl": return .orange
    default: return .primary
    }
}

private let a1Accent = Color(red: 0.18, green: 0.48, blue: 0.36)

// MARK: - Home

enum A1Route: Hashable {
    case mode(A1Mode)
    case mixed
    case exam
    case mistakes
    case sprint
    case match(Int?)
    case themes
    case theme(Int)
    case themeQuiz(Int)
    case grammarList
    case grammar(Int)
    case grammarQuiz(Int)
    case texts
    case text(Int)
    case wordList
    case numbersLearn
}

struct A1HomeView: View {
    @StateObject private var model = A1Model()

    var body: some View {
        NavigationStack {
            List {
                if !model.ready {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Sorular hazırlanıyor…")
                    }
                } else if model.content == nil {
                    Text("A1 içeriği yüklenemedi.")
                } else {
                    overview
                    Section("Hızlı başla") {
                        NavigationLink(value: A1Route.mixed) {
                            Label("Karışık 20 soru", systemImage: "shuffle")
                        }
                        NavigationLink(value: A1Route.exam) {
                            Label("Sınav provası (30 soru, 100 puan)", systemImage: "graduationcap")
                        }
                        NavigationLink(value: A1Route.mistakes) {
                            Label("Hatalarım (\(model.state.wrong.count))", systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(model.state.wrong.isEmpty)
                    }
                    Section {
                        ForEach(A1Mode.allCases) { mode in
                            NavigationLink(value: A1Route.mode(mode)) { modeRow(mode) }
                        }
                    } header: {
                        Text("Oyunlar ve sorular")
                    } footer: {
                        Text("Gördüğün soru bir daha sorulmaz. Yanlışların „Hatalarım“da toplanır.")
                    }
                    Section("Hız oyunları") {
                        NavigationLink(value: A1Route.sprint) {
                            Label("Artikel yarışı · 60 sn (rekor \(model.state.bestSprint))", systemImage: "timer")
                        }
                        NavigationLink(value: A1Route.match(nil)) {
                            Label("Kelime eşleştirme", systemImage: "square.grid.2x2")
                        }
                    }
                    Section {
                        NavigationLink(value: A1Route.wordList) {
                            Label("Kelime listesi (\(model.content?.words.count ?? 0) kelime)", systemImage: "textformat.abc")
                        }
                        NavigationLink(value: A1Route.themeQuiz(A1BankBuilder.coreTheme)) {
                            Label("Ek kelimelerden 20 soru (\(model.coreLearned)/\(model.coreTotal))", systemImage: "play.circle")
                        }
                    } header: {
                        Text("En sık 2000+ kelime")
                    } footer: {
                        Text("A1 kelimeleri ve sık kullanılan ek kelimeler: artikel, okunuş, Türkçe ve örnek cümle.")
                    }
                    Section("Çalışma kitabı") {
                        NavigationLink(value: A1Route.themes) {
                            Label("Kelime temaları", systemImage: "list.bullet.rectangle")
                        }
                        NavigationLink(value: A1Route.grammarList) {
                            Label("22 gramer konusu", systemImage: "books.vertical")
                        }
                        NavigationLink(value: A1Route.texts) {
                            Label("20 okuma metni", systemImage: "doc.richtext")
                        }
                        NavigationLink(value: A1Route.numbersLearn) {
                            Label("Sayıları öğren (yazılış kuralları)", systemImage: "number.circle")
                        }
                    }
                }
            }
            .navigationTitle("A1 Hazırlık")
            .navigationDestination(for: A1Route.self) { route in
                destination(route)
            }
            .tint(a1Accent)
        }
        .environmentObject(model)
    }

    private var overview: some View {
        Section("A1 hazırlığın") {
            ProgressView(value: model.readiness) {
                HStack {
                    Text("Öğrenilen sorular").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(model.learned) / \(model.total)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                stat("\(Int((model.readiness * 100).rounded()))%", "hazırlık")
                stat("\(model.state.streak)", "gün seri")
                stat("\(model.state.lastDay == todayString ? model.state.today : 0)", "bugün")
                stat(model.state.exams.last.map { "\($0)" } ?? "–", "son sınav")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func modeRow(_ mode: A1Mode) -> some View {
        let total = model.totalFor(mode)
        let seen = model.seenCount(mode)
        return HStack(spacing: 12) {
            Image(systemName: mode.icon)
                .foregroundStyle(a1Accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                Text(mode.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(seen)/\(total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func destination(_ route: A1Route) -> some View {
        switch route {
        case .mode(let mode):
            A1QuizView(title: mode.title, resetMode: mode) { model.session(mode: mode) }
        case .mixed:
            A1QuizView(title: "Karışık") { model.session() }
        case .exam:
            A1QuizView(title: "Sınav provası", exam: true) { model.examSession() }
        case .mistakes:
            A1QuizView(title: "Hatalarım", review: true) { model.mistakeSession() }
        case .sprint:
            A1SprintView()
        case .match(let theme):
            A1MatchView(theme: theme)
        case .themes:
            A1ThemesView()
        case .theme(let id):
            A1ThemeView(themeID: id)
        case .themeQuiz(let id):
            A1QuizView(title: model.content?.themes[id].de ?? "Tema") { model.session(theme: id) }
        case .grammarList:
            A1GrammarListView()
        case .grammar(let id):
            A1GrammarView(topicID: id)
        case .grammarQuiz(let id):
            A1QuizView(title: "Gramer \(id)") { model.session(topic: id) }
        case .texts:
            A1TextsView()
        case .text(let id):
            A1TextView(textID: id)
        case .wordList:
            A1WordListView()
        case .numbersLearn:
            A1NumbersLearnView()
        }
    }
}

// MARK: - Quiz

struct A1QuizView: View {
    @EnvironmentObject private var model: A1Model
    let title: String
    var exam = false
    var review = false
    var resetMode: A1Mode? = nil
    let makeSession: () -> [A1Question]

    init(title: String, exam: Bool = false, review: Bool = false, resetMode: A1Mode? = nil,
         makeSession: @escaping () -> [A1Question]) {
        self.title = title
        self.exam = exam
        self.review = review
        self.resetMode = resetMode
        self.makeSession = makeSession
    }

    @State private var session: [A1Question] = []
    @State private var started = false
    @State private var index = 0
    @State private var picked: String?
    @State private var typed = ""
    @State private var order: [Int] = []
    @State private var revealed = false
    @State private var wasCorrect = false
    @State private var score = 0
    @State private var missed: [A1Question] = []
    @State private var showText = false
    @State private var examSaved = false
    @FocusState private var typingFocused: Bool

    var body: some View {
        Group {
            if !started {
                ProgressView()
            } else if session.isEmpty {
                emptyState
            } else if index >= session.count {
                summary
            } else {
                question(session[index])
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { A1Speaker.shared.stop() }
        .onAppear {
            if !started {
                session = makeSession()
                started = true
                playIfNeeded()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(a1Accent)
            Text(review ? "Tekrar edilecek hatan yok." : "Bu bölümdeki tüm soruları gördün!")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            if let mode = resetMode {
                Text("İstersen bu oyunu sıfırlayıp baştan çözebilirsin. Yanlışların „Hatalarım“da duruyor.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Bu oyunu sıfırla ve baştan başla") {
                    model.reset(mode)
                    restart()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }

    private var summary: some View {
        let total = session.count
        let points = total == 0 ? 0 : Int((Double(score) / Double(total) * 100).rounded())
        return List {
            Section {
                VStack(spacing: 8) {
                    if exam {
                        Text("\(points) / 100 puan").font(.largeTitle.bold())
                        Text(points >= 60 ? "Geçtin! (en az 60)" : "Geçme notu 60 – biraz daha çalış.")
                            .foregroundStyle(points >= 60 ? a1Accent : .orange)
                    } else {
                        Text("\(score) / \(total) doğru").font(.largeTitle.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                Button {
                    restart()
                } label: {
                    Label("Yeni sorularla devam et", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            if !missed.isEmpty {
                Section("Yanlışların (Hatalarım'a eklendi)") {
                    ForEach(missed) { q in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(q.prompt).font(.subheadline)
                            Text("✓ \(q.answer)").font(.subheadline.bold()).foregroundStyle(a1Accent)
                        }
                    }
                }
            }
        }
        .onAppear {
            if exam && !examSaved {
                examSaved = true
                model.saveExam(points)
            }
        }
    }

    private func restart() {
        session = makeSession()
        index = 0
        score = 0
        missed = []
        examSaved = false
        resetAnswer()
        playIfNeeded()
    }

    private func resetAnswer() {
        picked = nil
        typed = ""
        order = []
        revealed = false
        wasCorrect = false
        showText = false
    }

    private func playIfNeeded() {
        guard index < session.count else { return }
        let q = session[index]
        guard q.dialog != nil || q.speakFirst != nil else { return }
        let times = q.mode == .listen || q.mode == .hoeren ? 2 : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { play(q, times: times) }
    }

    private func play(_ q: A1Question, slow: Bool = false, times: Int = 1) {
        if let dialog = q.dialog {
            A1Speaker.shared.play(dialog, slow: slow, times: times)
        } else if let text = q.speakFirst {
            A1Speaker.shared.say(text, slow: slow, times: times)
        }
    }

    private func question(_ q: A1Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView(value: Double(index), total: Double(session.count))
                HStack {
                    Text("Soru \(index + 1) / \(session.count)").font(.caption.monospacedDigit())
                    Spacer()
                    Text(q.label).font(.caption).lineLimit(1)
                }
                .foregroundStyle(.secondary)
                promptCard(q)
                switch q.kind {
                case .choice: choiceButtons(q)
                case .order: orderArea(q)
                case .typing: typingArea(q)
                }
                if revealed { feedback(q) }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func promptCard(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.mode.title.uppercased()).font(.caption2.bold()).foregroundStyle(a1Accent)
            if let context = q.context {
                DisclosureGroup(isExpanded: $showText) {
                    Text(context).font(.callout).padding(.top, 4)
                } label: {
                    Label("Metni oku", systemImage: "doc.text")
                }
                .onAppear { showText = true }
            }
            if q.dialog != nil || q.speakFirst != nil {
                HStack {
                    Button {
                        play(q)
                    } label: {
                        Label("Dinle", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        play(q, slow: true)
                    } label: {
                        Label("Yavaş", systemImage: "tortoise.fill")
                    }
                    .buttonStyle(.bordered)
                }
                if q.mode == .listen || q.mode == .hoeren {
                    Text("Sınavdaki gibi ses otomatik olarak iki kez çalınır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(q.prompt)
                .font(q.prompt.count < 40 ? Font.title2.bold() : Font.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
            if let detail = q.detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(a1Accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }

    private func choiceButtons(_ q: A1Question) -> some View {
        VStack(spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                Button {
                    guard !revealed else { return }
                    picked = option
                    check(q, correct: option == q.answer)
                } label: {
                    HStack {
                        Text(option)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(q.mode == .artikel ? a1ArticleColor(option) : Color.primary)
                            .font(q.mode == .artikel ? Font.title3.bold() : Font.body)
                        Spacer()
                        if revealed && option == q.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(a1Accent)
                        } else if revealed && option == picked {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .background(optionBackground(q, option), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func optionBackground(_ q: A1Question, _ option: String) -> Color {
        if revealed && option == q.answer { return a1Accent.opacity(0.22) }
        if revealed && option == picked { return Color.red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private func orderArea(_ q: A1Question) -> some View {
        let chosen = order.map { q.options[$0] }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 12) {
            Text(chosen.isEmpty ? "Kelimelere dokun…" : chosen)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { item in
                    let used = order.contains(item.offset)
                    Button {
                        guard !revealed else { return }
                        if let position = order.firstIndex(of: item.offset) {
                            order.remove(at: position)
                        } else {
                            order.append(item.offset)
                        }
                    } label: {
                        Text(item.element)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(used ? Color(.tertiarySystemFill) : a1Accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(used ? Color.secondary : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !revealed {
                HStack {
                    Button("Temizle") { order = [] }
                        .buttonStyle(.bordered)
                        .disabled(order.isEmpty)
                    Button {
                        check(q, correct: chosen == q.answer)
                    } label: {
                        Text("Kontrol et").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(order.count != q.options.count)
                }
            }
        }
    }

    private func typingArea(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Almanca yaz…", text: $typed, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .focused($typingFocused)
                .disabled(revealed)
            HStack(spacing: 6) {
                ForEach(["ä", "ö", "ü", "ß", "Ä", "Ö", "Ü"], id: \.self) { letter in
                    Button(letter) { typed += letter }
                        .buttonStyle(.bordered)
                        .disabled(revealed)
                }
            }
            if !revealed {
                Button {
                    typingFocused = false
                    let answer = a1Normalize(typed)
                    let ok = ([q.answer] + q.accepted).contains { a1Normalize($0) == answer }
                    picked = typed
                    check(q, correct: ok)
                } label: {
                    Text("Kontrol et").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func check(_ q: A1Question, correct: Bool) {
        revealed = true
        wasCorrect = correct
        if correct {
            score += 1
        } else {
            missed.append(q)
        }
        model.record(q, correct: correct)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(correct ? .success : .error)
    }

    private func feedback(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(wasCorrect ? "Doğru!" : "Yanlış", systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(wasCorrect ? a1Accent : .red)
            if !wasCorrect {
                Text("Doğru cevap: \(q.answer)").font(.body.bold())
            }
            if let explanation = q.explanation {
                Text(explanation).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if q.dialog != nil || q.speakAfter != nil || q.speakFirst != nil {
                    Button {
                        if let speak = q.speakAfter {
                            A1Speaker.shared.say(speak)
                        } else {
                            play(q)
                        }
                    } label: {
                        Label("Dinle", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    A1Speaker.shared.stop()
                    index += 1
                    resetAnswer()
                    playIfNeeded()
                } label: {
                    Text(index + 1 < session.count ? "Devam" : "Sonucu gör").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((wasCorrect ? a1Accent : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Games

struct A1SprintView: View {
    @EnvironmentObject private var model: A1Model
    @State private var nouns: [A1Word] = []
    @State private var current = 0
    @State private var score = 0
    @State private var remaining = 60
    @State private var running = false
    @State private var finished = false
    @State private var flash: Color?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Label("\(remaining) sn", systemImage: "timer").font(.title3.monospacedDigit())
                Spacer()
                Text("Puan: \(score)").font(.title3.bold().monospacedDigit())
            }
            Spacer()
            if running, current < nouns.count {
                let word = nouns[current]
                VStack(spacing: 8) {
                    Text(word.de).font(.system(size: 40, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    Text(word.tr).foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background((flash ?? Color.clear).opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
                HStack(spacing: 12) {
                    ForEach(["der", "die", "das"], id: \.self) { article in
                        Button {
                            answer(article)
                        } label: {
                            Text(article).font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(a1ArticleColor(article))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text(finished ? "Süre bitti! \(score) puan" : "60 saniyede kaç artikel bilebilirsin?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Rekor: \(model.state.bestSprint)").foregroundStyle(.secondary)
                    Text("Doğru: +1 · Yanlış: –1").font(.footnote).foregroundStyle(.secondary)
                    Button(finished ? "Tekrar oyna" : "Başla", action: start)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            Spacer()
        }
        .padding(20)
        .navigationTitle("Artikel yarışı")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard running else { return }
            remaining -= 1
            if remaining <= 0 {
                running = false
                finished = true
                model.saveSprint(score)
            }
        }
    }

    private func start() {
        guard let words = model.content?.words else { return }
        nouns = words.filter(\.isNoun).shuffled()
        current = 0
        score = 0
        remaining = 60
        finished = false
        running = true
    }

    private func answer(_ article: String) {
        let word = nouns[current]
        let ok = word.type == article
        score = max(0, score + (ok ? 1 : -1))
        flash = ok ? .green : .red
        if !ok { A1Speaker.shared.say(word.withArticle) }
        current = (current + 1) % nouns.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flash = nil }
    }
}

struct A1MatchView: View {
    @EnvironmentObject private var model: A1Model
    let theme: Int?
    @State private var pairs: [A1Word] = []
    @State private var right: [A1Word] = []
    @State private var selectedLeft: Int?
    @State private var done: Set<Int> = []
    @State private var wrongFlash: Int?
    @State private var rounds = 0
    @State private var errors = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Almanca kelimeyi ve Türkçesini eşleştir").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    ForEach(pairs) { word in
                        tile(word.withArticle, active: selectedLeft == word.id, gone: done.contains(word.id), color: a1ArticleColor(word.type)) {
                            selectedLeft = word.id
                            A1Speaker.shared.say(word.withArticle)
                        }
                    }
                }
                VStack(spacing: 10) {
                    ForEach(right) { word in
                        tile(word.tr, active: wrongFlash == word.id, gone: done.contains(word.id), color: .primary) {
                            match(word)
                        }
                    }
                }
            }
            Text("Tur: \(rounds) · Hata: \(errors)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .navigationTitle("Eşleştirme")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if pairs.isEmpty { newRound() } }
    }

    private func tile(_ text: String, active: Bool, gone: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 6)
                .background(active ? a1Accent.opacity(0.3) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(gone ? 0.15 : 1)
        .disabled(gone)
    }

    private func match(_ word: A1Word) {
        guard let left = selectedLeft else { return }
        if left == word.id {
            done.insert(word.id)
            selectedLeft = nil
            if done.count == pairs.count {
                rounds += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { newRound() }
            }
        } else {
            errors += 1
            wrongFlash = word.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { wrongFlash = nil }
        }
    }

    private func newRound() {
        guard let words = model.content?.words else { return }
        let pool = words.filter { theme == nil || $0.theme == theme }
        var seenMeanings: Set<String> = []
        var picked: [A1Word] = []
        for word in pool.shuffled() where !seenMeanings.contains(word.tr) {
            seenMeanings.insert(word.tr)
            picked.append(word)
            if picked.count == 5 { break }
        }
        pairs = picked
        right = picked.shuffled()
        done = []
        selectedLeft = nil
    }
}

// MARK: - Workbook

struct A1ThemesView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        List(model.content?.themes ?? []) { theme in
            NavigationLink(value: A1Route.theme(theme.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d  ", theme.id + 1) + theme.de)
                    Text("\(theme.tr) · \(model.content?.words.filter { $0.theme == theme.id }.count ?? 0) kelime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Kelime temaları")
    }
}

struct A1ThemeView: View {
    @EnvironmentObject private var model: A1Model
    let themeID: Int

    var body: some View {
        let words = model.content?.words.filter { $0.theme == themeID } ?? []
        List {
            Section {
                NavigationLink(value: A1Route.themeQuiz(themeID)) {
                    Label("Bu temadan 20 soru", systemImage: "play.circle.fill")
                }
                NavigationLink(value: A1Route.match(themeID)) {
                    Label("Bu temayla eşleştirme", systemImage: "square.grid.2x2")
                }
            }
            Section("Kelimeler") {
                ForEach(words) { word in
                    DisclosureGroup {
                        ForEach(Array(word.ex.enumerated()), id: \.offset) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.element.de)
                                    Text("[\(item.element.pron)]").font(.caption).foregroundStyle(.secondary)
                                    Text(item.element.tr).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                A1SpeakButton(text: item.element.de)
                            }
                        }
                        if let er = word.er {
                            Text("\(er) · \(word.perfekt ?? "")").font(.caption)
                        }
                        if let pl = word.plural {
                            Text("Çoğul: die \(pl)").font(.caption)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.withArticle).font(.body.weight(.semibold)).foregroundStyle(a1ArticleColor(word.type))
                                Text("[\(word.pron)] · \(word.tr)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            A1SpeakButton(text: word.withArticle)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.content?.themes[themeID].de ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct A1GrammarListView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        List(model.content?.grammar ?? []) { topic in
            NavigationLink(value: A1Route.grammar(topic.id)) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(topic.id). \(topic.de)")
                        Text(topic.tr).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(model.questions.filter { $0.topic == topic.id }.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Gramer konuları")
    }
}

struct A1GrammarView: View {
    @EnvironmentObject private var model: A1Model
    let topicID: Int

    var body: some View {
        if let topic = model.content?.grammar.first(where: { $0.id == topicID }) {
            List {
                Section("Kural") {
                    Text(topic.rule)
                }
                Section("Örnekler") {
                    ForEach(topic.examples, id: \.self) { example in
                        HStack {
                            Text(example)
                            Spacer()
                            A1SpeakButton(text: example.components(separatedBy: " – ").first ?? example)
                        }
                    }
                }
                Section {
                    NavigationLink(value: A1Route.grammarQuiz(topicID)) {
                        Label("Bu konudan alıştırma (\(model.questions.filter { $0.topic == topicID }.count) soru)", systemImage: "play.circle.fill")
                    }
                }
            }
            .navigationTitle(topic.de)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct A1TextsView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        List(model.content?.texts ?? []) { text in
            NavigationLink(value: A1Route.text(text.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text \(text.id): \(text.title)")
                    Text(text.titleTr).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Okuma metinleri")
    }
}

struct A1TextView: View {
    @EnvironmentObject private var model: A1Model
    let textID: Int
    @State private var showTurkish = false

    var body: some View {
        if let text = model.content?.texts.first(where: { $0.id == textID }) {
            List {
                Section {
                    Button {
                        A1Speaker.shared.say(text.de.joined(separator: " "))
                    } label: {
                        Label("Tüm metni dinle", systemImage: "speaker.wave.2.fill")
                    }
                    ForEach(Array(text.de.enumerated()), id: \.offset) { item in
                        HStack {
                            Text(item.element)
                            Spacer()
                            A1SpeakButton(text: item.element)
                        }
                    }
                }
                Section {
                    Toggle("Türkçesini göster", isOn: $showTurkish)
                    if showTurkish { Text(text.tr).foregroundStyle(.secondary) }
                }
                Section {
                    NavigationLink(value: A1Route.mode(.reading)) {
                        Label("Okuma sorularını çöz", systemImage: "play.circle.fill")
                    }
                }
            }
            .navigationTitle(text.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct A1WordListView: View {
    @EnvironmentObject private var model: A1Model
    @State private var search = ""
    @State private var filter = "all"

    var body: some View {
        let words = filtered
        List {
            Picker("Tür", selection: $filter) {
                Text("Tümü").tag("all")
                Text("İsim").tag("noun")
                Text("Fiil").tag("verb")
                Text("Diğer").tag("word")
            }
            .pickerStyle(.segmented)
            Section("\(words.count) kelime") {
                ForEach(words) { word in
                    A1WordRow(word: word)
                }
            }
        }
        .searchable(text: $search, prompt: "Almanca veya Türkçe ara")
        .navigationTitle("Kelime listesi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [A1Word] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (model.content?.words ?? [])
            .filter { filter == "all" || $0.group == filter }
            .filter { query.isEmpty || $0.de.localizedStandardContains(query) || $0.tr.localizedStandardContains(query) }
            .sorted { $0.de.localizedCaseInsensitiveCompare($1.de) == .orderedAscending }
    }
}

struct A1WordRow: View {
    let word: A1Word

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(word.withArticle).font(.body.weight(.semibold)).foregroundStyle(a1ArticleColor(word.type))
                    if word.theme != A1BankBuilder.coreTheme {
                        Text("A1")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(a1Accent.opacity(0.2), in: Capsule())
                    }
                }
                Text("[\(word.pron)] · \(word.tr)").font(.caption).foregroundStyle(.secondary)
                if let pl = word.plural {
                    Text("Çoğul: die \(pl)").font(.caption2).foregroundStyle(.secondary)
                }
                if let er = word.er {
                    Text("\(er) · \(word.perfekt ?? "")").font(.caption2).foregroundStyle(.secondary)
                }
                if let ex = word.ex.first {
                    Text(ex.de).font(.callout).padding(.top, 2)
                    Text("[\(ex.pron)]").font(.caption2).foregroundStyle(.secondary)
                    Text(ex.tr).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack {
                A1SpeakButton(text: word.withArticle)
                if let ex = word.ex.first {
                    A1SpeakButton(text: ex.de, slow: true)
                }
            }
        }
    }
}

struct A1NumbersLearnView: View {
    @State private var input = "347"

    private var number: Int? {
        guard let n = Int(input.filter(\.isNumber)), n < 1_000_000 else { return nil }
        return n
    }

    var body: some View {
        List {
            Section {
                TextField("Bir sayı yaz", text: $input)
                    .keyboardType(.numberPad)
                    .font(.title2.monospacedDigit())
                if let n = number {
                    HStack {
                        Text(a1GermanNumber(n)).font(.title3.bold()).foregroundStyle(a1Accent)
                        Spacer()
                        A1SpeakButton(text: a1GermanNumber(n))
                        A1SpeakButton(text: a1GermanNumber(n), slow: true)
                    }
                    if n < 1000 {
                        Text(a1NumberPieces(n).joined(separator: " · ")).font(.callout).foregroundStyle(.secondary)
                    }
                    if n >= 1100 && n < 2000 {
                        Text("Yıl olarak: \(a1Year(n))").font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    Text("0 ile 999 999 arasında bir sayı yaz.").foregroundStyle(.secondary)
                }
            } header: {
                Text("Sayı çevirici")
            } footer: {
                Text("Herhangi bir sayı yaz, Almancasını gör ve dinle.")
            }
            rule("1. 0–12: ezberle", "Bu sayılar özel kelimelerdir.", Array(0...12))
            rule("2. 13–19: birler + zehn", "drei + zehn = dreizehn. Dikkat: sechzehn (sechs değil), siebzehn (sieben değil).", Array(13...19))
            rule("3. Onlar: -zig", "zwanzig, vierzig, fünfzig … Dikkat: dreißig (-ßig), sechzig, siebzig.", [20, 30, 40, 50, 60, 70, 80, 90])
            rule("4. 21–99: birler + und + onlar", "Türkçenin tersi! 47 = sieben-und-vierzig („yedi ve kırk“). 1 → ein: einundzwanzig.", [21, 34, 47, 58, 65, 76, 89, 99])
            rule("5. Yüzler: … hundert …", "347 = dreihundert + siebenundvierzig. 100 = (ein)hundert. Hepsi bitişik yazılır.", [100, 101, 115, 230, 347, 508, 999])
            rule("6. Binler: … tausend …", "2500 = zweitausend + fünfhundert. 1000 = (ein)tausend.", [1000, 2500, 10_000, 12_345, 100_000])
            Section {
                ForEach([1990, 1998, 2000, 2010, 2024], id: \.self) { year in
                    row("\(year)", a1Year(year))
                }
            } header: {
                Text("7. Yıllar")
            } footer: {
                Text("1100–1999: neunzehnhundert… (on dokuz yüz…). 2000'den sonra: zweitausend… „Ich bin 1998 geboren.“ – „in“ kullanılmaz.")
            }
            Section {
                row("1,00 €", a1Price(1, 0))
                row("3,50 €", a1Price(3, 50))
                row("12,99 €", a1Price(12, 99))
                row("0,80 €", "achtzig Cent")
            } header: {
                Text("8. Fiyatlar")
            } footer: {
                Text("Virgülden sonrası „Cent“ denmeden söylenir: drei Euro fünfzig.")
            }
            Section {
                row("0171 345 682", "null eins sieben eins – drei vier fünf – sechs acht zwei")
                row("030 12 34 56", "null drei null – zwölf vierunddreißig sechsundfünfzig")
            } header: {
                Text("9. Telefon numaraları")
            } footer: {
                Text("Genelde rakam rakam söylenir; bazen ikişer ikişer. „zwei“ yerine telefonda „zwo“ da denir.")
            }
        }
        .navigationTitle("Sayıları öğren")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    private func rule(_ title: String, _ text: String, _ numbers: [Int]) -> some View {
        Section {
            ForEach(numbers, id: \.self) { n in
                row(n.formatted(.number.locale(Locale(identifier: "de_DE"))), a1GermanNumber(n))
            }
        } header: {
            Text(title)
        } footer: {
            Text(text)
        }
    }

    private func row(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).font(.body.monospacedDigit()).frame(minWidth: 70, alignment: .leading)
            Text(right).foregroundStyle(a1Accent)
            Spacer()
            A1SpeakButton(text: right)
        }
    }
}
