import Foundation

// MARK: - Questions

enum A1Mode: String, CaseIterable, Identifiable, Hashable {
    case artikel, wordToTr, trToWord, sentence, cloze, order, listen, hoeren, write, plural, verbs, grammar, numbers, reading, daily

    var id: String { rawValue }

    var title: String { t("mode.\(rawValue).title") }

    var subtitle: String { t("mode.\(rawValue).sub") }

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

/// Builds every question once. Ids are stable, so answered questions are never asked again.
struct A1BankBuilder {
    static let coreTheme = 15
    let content: A1Content
    private let allExampleTr: [String]
    private var out: [A1Question] = []

    /// Level-specific generators (numbers, conjugation tables, case drills) only run for A1.
    let level: String

    init(content: A1Content, level: String = "A1") {
        self.content = content
        self.level = level
        allExampleTr = content.words.flatMap { $0.ex.map { $0.mean.text } }
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
        let near = content.words.filter { $0.theme == word.theme && $0.id != word.id }.flatMap { $0.ex.map { $0.mean.text } }.shuffled()
        let far = (0..<16).compactMap { _ in allExampleTr.randomElement() }
        return Array(near.prefix(12)) + far
    }

    private func wordInfo(_ w: A1Word) -> String {
        var text = "\(w.withArticle)\(a1Pron(w.pron)) = \(w.mean.text)"
        if let first = w.ex.first { text += "\n\(first.de) — \(first.mean.text)" }
        return text
    }

    mutating func build() -> [A1Question] {
        out = []
        addWords()
        addSentences()
        addVerbs()
        if level == "A1" {
            addConjugation()
            addCaseDrills()
        }
        addGrammarItems()
        if level == "A1" { addNumbers() }
        addReading()
        addDaily()
        addHoeren()
        if level != "A1" {
            // Word questions carry A1 topic numbers; only grammar items belong to this level's topics.
            for i in out.indices where !out[i].id.hasPrefix("gr-") { out[i].topic = nil }
        }
        return out
    }

    private mutating func addHoeren() {
        let parts = [1: t("hoeren.part1"), 2: t("hoeren.part2"), 3: t("hoeren.part3")]
        let names = [0: t("hoeren.woman"), 1: t("hoeren.man"), 2: t("hoeren.announcer")]
        for (index, item) in content.hoeren.enumerated() {
            guard let correct = item.options.first else { continue }
            let isTrueFalse = Set(item.options) == ["Richtig", "Falsch"]
            let transcript = item.lines.map { "\(names[$0.s] ?? "–"): \($0.t)" }.joined(separator: "\n")
            out.append(A1Question(id: "hr-\(index)", mode: .hoeren, kind: .choice, label: "Hören Teil \(item.part)", topic: nil,
                                  prompt: item.q, detail: parts[item.part], dialog: item.lines,
                                  options: isTrueFalse ? ["Richtig", "Falsch"] : item.options.shuffled(), answer: correct,
                                  explanation: "\(transcript)\n\n\(t("q.translation")): \(item.trans.text)"))
        }
    }

    // MARK: words
    private mutating func addWords() {
        for w in content.words {
            let label = themeName(w.theme)
            if w.isNoun {
                var why = "\(w.type) \(w.de)\(a1Pron(w.pron)) · \(w.mean.text)"
                if let pl = w.plural { why += " · " + t("word.plural", pl) }
                out.append(A1Question(id: "art-\(w.id)", mode: .artikel, kind: .choice, label: label, theme: w.theme, topic: 4,
                                      prompt: "___ \(w.de)", detail: w.mean.text, speakAfter: w.withArticle,
                                      options: ["der", "die", "das"], answer: w.type, explanation: why))
            }
            let meaning = w.mean.text
            let trWrong = distinct(meaning, candidates(for: w) { $0.mean.text })
            if trWrong.count == 3 {
                out.append(A1Question(id: "w2t-\(w.id)", mode: .wordToTr, kind: .choice, label: label, theme: w.theme,
                                      prompt: w.withArticle, detail: a1PronDetail(w.pron), speakAfter: w.withArticle,
                                      options: options(meaning, trWrong), answer: meaning, explanation: wordInfo(w)))
                out.append(A1Question(id: "lw-\(w.id)", mode: .listen, kind: .choice, label: label, theme: w.theme,
                                      prompt: t("q.listenWord"), speakFirst: w.withArticle,
                                      options: options(meaning, trWrong), answer: meaning, explanation: wordInfo(w)))
            }
            let deWrong = distinct(w.withArticle, candidates(for: w) { $0.withArticle })
            if deWrong.count == 3 {
                out.append(A1Question(id: "t2w-\(w.id)", mode: .trToWord, kind: .choice, label: label, theme: w.theme,
                                      prompt: meaning, speakAfter: w.withArticle,
                                      options: options(w.withArticle, deWrong), answer: w.withArticle, explanation: wordInfo(w)))
            }
            let simple = !w.de.contains(",") && !w.de.contains("/") && !w.de.contains("(") && !w.de.contains("…")
            if simple {
                out.append(A1Question(id: "wr-\(w.id)", mode: .write, kind: .typing, label: label, theme: w.theme,
                                      prompt: meaning, detail: w.isNoun || w.type == "pl" ? t("q.writeWithArticle") : t("q.writeGerman"),
                                      speakAfter: w.withArticle, answer: w.withArticle, explanation: wordInfo(w)))
            }
            if w.isNoun, let pl = w.plural {
                let fake = pluralDistractors(w.de, real: pl).map { "die \($0)" }
                let wrong = distinct("die \(pl)", fake)
                if wrong.count >= 2 {
                    out.append(A1Question(id: "pl-\(w.id)", mode: .plural, kind: .choice, label: label, theme: w.theme, topic: 5,
                                          prompt: t("q.pluralOf", "\(w.type) \(w.de)"), detail: meaning, speakAfter: "die \(pl)",
                                          options: options("die \(pl)", wrong), answer: "die \(pl)",
                                          explanation: "\(w.type) \(w.de) → die \(pl). " + t("q.pluralWhy")))
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
                let exMean = ex.mean.text
                let info = "\(ex.de)\(a1PronLine(ex.pron))\n\(exMean)"
                let wrong = distinct(exMean, pool)
                if wrong.count == 3 {
                    out.append(A1Question(id: "sen-\(key)", mode: .sentence, kind: .choice, label: label, theme: w.theme,
                                          prompt: ex.de, detail: a1PronDetail(ex.pron), speakAfter: ex.de,
                                          options: options(exMean, wrong), answer: exMean, explanation: info))
                    out.append(A1Question(id: "ls-\(key)", mode: .listen, kind: .choice, label: label, theme: w.theme,
                                          prompt: t("q.listenSentence"), speakFirst: ex.de,
                                          options: options(exMean, distinct(exMean, pool.shuffled())), answer: exMean, explanation: info))
                }
                let tokens = ex.de.split(separator: " ").map(String.init)
                if tokens.count >= 3 && tokens.count <= 10 {
                    var shuffled = tokens.shuffled()
                    var tries = 0
                    while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
                    out.append(A1Question(id: "ord-\(key)", mode: .order, kind: .order, label: label, theme: w.theme, topic: 10,
                                          prompt: exMean, detail: t("q.orderWords"), speakAfter: ex.de,
                                          options: shuffled, answer: tokens.joined(separator: " "), explanation: info))
                }
                if tokens.count <= 8 {
                    out.append(A1Question(id: "dik-\(key)", mode: .write, kind: .typing, label: label, theme: w.theme,
                                          prompt: t("q.dictation"), detail: exMean, speakFirst: ex.de,
                                          answer: ex.de, explanation: info))
                }
                if let cloze = makeCloze(w, ex, tokens: tokens, infinitives: allInfinitives, erForms: allErForms,
                                         partizips: allPartizips, nouns: nounForms, small: smallWords) {
                    out.append(A1Question(id: "clz-\(key)", mode: .cloze, kind: .choice, label: label, theme: w.theme,
                                          prompt: cloze.prompt, detail: exMean, speakAfter: ex.de,
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
                                      topic: 10, prompt: t("q.orderFromText"), detail: text.titleL.text, speakAfter: line,
                                      options: shuffled, answer: tokens.joined(separator: " "), explanation: line))
                if tokens.count <= 9 {
                    out.append(A1Question(id: "dikt-\(text.id)-\(index)", mode: .write, kind: .typing, label: "Text \(text.id): \(text.title)",
                                          prompt: t("q.dictation"), detail: text.titleL.text, speakFirst: line,
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
                                              prompt: "\(w.de) → Perfekt (er)", detail: w.mean.text, speakAfter: "er \(p)",
                                              options: options("er \(p)", picked), answer: "er \(p)",
                                              explanation: "\(w.de): \(w.er ?? "") · \(p). " + t("q.perfektWhy")))
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
                                              prompt: "\(w.de) → er / sie / es …?", detail: w.mean.text, speakAfter: er,
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
                                      prompt: "Ich brauche _____ \(w.de).", detail: "\(w.mean.text) (\(w.type))", speakAfter: "Ich brauche \(indefinite) \(w.de).",
                                      options: ["ein", "eine", "einen", "einem"], answer: indefinite,
                                      explanation: "brauchen + Akkusativ: \(w.type) \(w.de) → \(indefinite) \(w.de). " + t("q.akkWhy")))
                let negative = "k" + indefinite
                out.append(A1Question(id: "kein-\(w.id)", mode: .grammar, kind: .choice, label: topicName(11), theme: w.theme, topic: 11,
                                      prompt: "Ich habe _____ \(w.de).", detail: "\(w.mean.text) (\(w.type))", speakAfter: "Ich habe \(negative) \(w.de).",
                                      options: ["kein", "keine", "keinen", "nicht"], answer: negative,
                                      explanation: "haben + Akkusativ: \(w.type) \(w.de) → \(negative) \(w.de). " + t("q.keinWhy")))
                let definite = w.type == "der" ? "den" : w.type
                out.append(A1Question(id: "akd-\(w.id)", mode: .grammar, kind: .choice, label: topicName(6), theme: w.theme, topic: 6,
                                      prompt: "Ich suche _____ \(w.de).", detail: "\(w.mean.text) (\(w.type))", speakAfter: "Ich suche \(definite) \(w.de).",
                                      options: (Array(["der", "den", "die", "das", "dem"].filter { $0 != definite }.shuffled().prefix(3)) + [definite]).shuffled(),
                                      answer: definite,
                                      explanation: "suchen + Akkusativ: \(w.type) → \(definite). " + t("q.akkDefWhy")))
            }
        }
        for w in people where !w.de.contains(" ") {
            let dative = w.type == "die" ? "der" : "dem"
            out.append(A1Question(id: "dat-\(w.id)", mode: .grammar, kind: .choice, label: topicName(7), theme: w.theme, topic: 7,
                                  prompt: "Ich spreche mit _____ \(w.de).", detail: "\(w.mean.text) (\(w.type))", speakAfter: "Ich spreche mit \(dative) \(w.de).",
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
                                      prompt: "(\(owner.0)) Das ist _____ \(w.de).", detail: "\(w.mean.text) (\(w.type))",
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
                                  options: item.options.shuffled(), answer: correct, explanation: item.why.text))
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
                                  prompt: "\(n)", detail: t("q.whichGerman"), speakAfter: word,
                                  options: options(word, wrongWords), answer: word, explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "lnum-\(n)", mode: .listen, kind: .choice, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: t("q.listenNumber"), speakFirst: "\(n)",
                                  options: options("\(n)", wrongDigits), answer: "\(n)", explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "wnum-\(n)", mode: .write, kind: .typing, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: "\(n)", detail: t("q.writeNumber"), speakAfter: word, answer: word,
                                  accepted: a1NumberAlternatives(word), explanation: "\(n) = \(word)"))
            out.append(A1Question(id: "numr-\(n)", mode: .numbers, kind: .choice, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: word, detail: t("q.whichNumber"), speakAfter: word,
                                  options: options("\(n)", wrongDigits), answer: "\(n)", explanation: "\(word) = \(n)"))
            out.append(A1Question(id: "numd-\(n)", mode: .write, kind: .typing, label: "Zahlen", theme: 3, topic: 19,
                                  prompt: t("q.listenDigits"), detail: t("q.example347"), speakFirst: word, answer: "\(n)",
                                  explanation: "\(word) = \(n)"))
            let pieces = a1NumberPieces(n)
            if pieces.count >= 3 {
                var shuffled = pieces.shuffled()
                var tries = 0
                while shuffled == pieces && tries < 5 { shuffled.shuffle(); tries += 1 }
                out.append(A1Question(id: "nb-\(n)", mode: .numbers, kind: .order, label: "Zahlen bauen", theme: 3, topic: 19,
                                      prompt: "\(n)", detail: t("q.numberPieces"),
                                      speakAfter: word, options: shuffled, answer: pieces.joined(separator: " "),
                                      explanation: "\(n) = \(word)\n" + t("q.numberPiecesWhy")))
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
                                          prompt: t("q.timeEveryday", clock), speakAfter: "Es ist \(correct).",
                                          options: options(correct, wrong), answer: correct,
                                          explanation: "\(clock) = \(correct). " + t("q.halbWhy")))
                }
                let clockWrong = distinct(clock, [String(format: "%d:%02d", h % 12 + 1, m), String(format: "%d:%02d", (h + 10) % 12 + 1, m),
                                                  String(format: "%d:%02d", h, (60 - m) % 60), String(format: "%d:%02d", h, (m + 30) % 60)])
                if clockWrong.count == 3 {
                    out.append(A1Question(id: "tmr-\(h)-\(m)", mode: .listen, kind: .choice, label: "Uhrzeit", theme: 3, topic: 19,
                                          prompt: t("q.listenTime"), speakFirst: "Es ist \(correct).",
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
                out.append(A1Question(id: "tmo-\(h)-\(m)", mode: .numbers, kind: .choice, label: "Uhrzeit (offiziell)", theme: 3, topic: 19,
                                      prompt: "„\(official)“", detail: t("q.officialTime"), speakAfter: official,
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
                                  explanation: "\(day). = der \(correct). " + t("q.ordinalWhy")))
            let dative = correct + "n"
            out.append(A1Question(id: "ord-am-\(day)", mode: .numbers, kind: .choice, label: "Datum", theme: 3, topic: 19,
                                  prompt: "Ich habe am _____ \(month) Geburtstag.  (\(day).)", speakAfter: "Ich habe am \(dative) \(month) Geburtstag.",
                                  options: options(dative, distinct(dative, [correct, a1GermanNumber(day) + "en", a1Ordinal(day % 31 + 1) + "n", a1GermanNumber(day)])),
                                  answer: dative, explanation: t("q.amWhy", "am \(dative) \(month)")))
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
                                  prompt: n.formatted(.number.locale(Locale(identifier: "de_DE"))), detail: t("q.whichGerman"), speakAfter: word,
                                  options: options(word, wrong), answer: word, explanation: "\(n) = \(word)"))
        }
        // Years: Ich bin 1998 geboren.
        for year in stride(from: 1950, through: 2030, by: 1) {
            let word = a1Year(year)
            let wrong = distinct(word, [a1GermanNumber(year), a1Year(year + 10), a1Year(year - 1), a1Year(year + 1), "tausend" + a1GermanNumber(year % 1000)])
            guard wrong.count == 3 else { continue }
            out.append(A1Question(id: "yr-\(year)", mode: .numbers, kind: .choice, label: "Jahreszahlen", theme: 3, topic: 19,
                                  prompt: "Ich bin \(year) geboren.", detail: t("q.yearHow"), speakAfter: "Ich bin \(word) geboren.",
                                  options: options(word, wrong), answer: word,
                                  explanation: "\(year) = \(word). " + t("q.yearWhy")))
            if year % 4 == 0 {
                out.append(A1Question(id: "lyr-\(year)", mode: .listen, kind: .choice, label: "Jahreszahlen", theme: 3, topic: 19,
                                      prompt: t("q.listenYear"), speakFirst: "Ich bin \(word) geboren.",
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
                                  prompt: "Das kostet \(price)", detail: t("q.priceHow"), speakAfter: "Das kostet \(word).",
                                  options: options(word, wrong), answer: word, explanation: "\(price) = \(word)"))
            let digits = distinct(price, [String(format: "%d,%02d €", euro + 1, cent), String(format: "%d,%02d €", euro, (cent + 30) % 100),
                                          String(format: "%d,%02d €", max(1, euro - 1), cent)])
            out.append(A1Question(id: "lpr-\(euro)", mode: .listen, kind: .choice, label: "Preise", theme: 3, topic: 19,
                                  prompt: t("q.listenPrice"), speakFirst: "Das kostet \(word).",
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
                                      explanation: "\(t("q.translation")): \(text.trans.text)"))
            }
        }
    }

    private mutating func addDaily() {
        for (index, item) in content.situations.enumerated() {
            guard let correct = item.options.first else { continue }
            out.append(A1Question(id: "sit-\(index)", mode: .daily, kind: .choice, label: "Was sagst du?", topic: 22,
                                  prompt: item.q.text, detail: t("q.whatSay"), speakAfter: correct,
                                  options: item.options.shuffled(), answer: correct, explanation: correct))
        }
        for (index, item) in content.mistakes.enumerated() {
            out.append(A1Question(id: "fx-\(index)", mode: .daily, kind: .choice, label: "Finde den Fehler", topic: 10,
                                  prompt: t("q.whichCorrect"), speakAfter: item.right,
                                  options: [item.right, item.wrong].shuffled(), answer: item.right,
                                  explanation: "✗ \(item.wrong)\n✓ \(item.right)\n\(item.why.text)"))
            out.append(A1Question(id: "fxw-\(index)", mode: .write, kind: .typing, label: "Finde den Fehler", topic: 10,
                                  prompt: item.wrong, detail: t("q.fixWrite"), speakAfter: item.right,
                                  answer: item.right, explanation: item.why.text))
        }
    }
}

// MARK: - Pronunciation helpers

/// The Turkish-letter pronunciation only helps Turkish speakers; other languages get audio (IPA later).
func a1ShowsPron() -> Bool { Localizer.shared.language == .tr }
func a1Pron(_ p: String) -> String { a1ShowsPron() && !p.isEmpty ? " [\(p)]" : "" }
func a1PronLine(_ p: String) -> String { a1ShowsPron() && !p.isEmpty ? "\n[\(p)]" : "" }
func a1PronDetail(_ p: String) -> String? { a1ShowsPron() && !p.isEmpty ? "[\(p)]" : nil }
