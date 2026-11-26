import SwiftUI

// MARK: - Unit words

/// One word a unit teaches: A1 the words on the unit's cards (pictures + extra words), A2+ the unit's own word list.
struct UnitDrillWord {
    let de: String
    let art: String?
    let meaning: String
    /// An example sentence (A1 words have one), for "use it in a sentence".
    var example: A1Example? = nil
    var full: String { art.map { "\($0) \(de)" } ?? de }
}

/// How far each path word is learned, step by step:
/// 0 new → 1 recognised (meaning) → 2 recalled (German word, listening, article) → 3 written → 4 used in a sentence.
/// A right answer moves the word one step up and further away for review; a wrong one a step down, back today.
enum WordMastery {
    static let changed = Notification.Name("WordMasteryChanged")
    /// Days until the word comes back after reaching a stage.
    private static let intervals = [0, 1, 2, 4, 7]
    /// Stage from which a word counts as learned in the unit's progress.
    static let learnedStage = 3

    private struct Entry: Codable {
        var stage: Int
        var due: String
    }

    private static var memory: [String: [String: Entry]] = [:]
    private static func key(_ level: String) -> String { "wordMastery.\(level.lowercased())" }

    private static func entries(_ level: String) -> [String: Entry] {
        if let known = memory[level] { return known }
        let loaded = UserDefaults.standard.data(forKey: key(level))
            .flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
        memory[level] = loaded
        return loaded
    }

    static func stage(_ level: String, _ word: String) -> Int { entries(level)[word]?.stage ?? 0 }

    static func isDue(_ level: String, _ word: String) -> Bool {
        guard let entry = entries(level)[word] else { return true }
        return entry.due <= A1Model.dayString(Date())
    }

    /// Ids of word-practice questions carry the word: "um<kind>|<level>|<der Bahnhof>".
    static func questionID(_ kind: String, _ level: String, _ word: String) -> String { "um\(kind)|\(level)|\(word)" }

    /// Called for every answered question (A1Model.record); only word-practice questions change anything.
    static func record(_ questionID: String, correct: Bool) {
        guard questionID.hasPrefix("um") else { return }
        let parts = questionID.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return }
        let level = parts[1], word = parts[2]
        var all = entries(level)
        var entry = all[word] ?? Entry(stage: 0, due: "")
        entry.stage = correct ? min(4, entry.stage + 1) : max(0, entry.stage - 1)
        entry.due = ReviewStore.day(correct ? intervals[entry.stage] : 0)
        all[word] = entry
        memory[level] = all
        if let data = try? JSONEncoder().encode(all) { UserDefaults.standard.set(data, forKey: key(level)) }
        NotificationCenter.default.post(name: changed, object: nil)
    }

    /// Words of a unit at the "learned" stage or above, and how many words it has.
    static func progress(_ level: String, _ words: [UnitDrillWord]) -> (learned: Int, total: Int) {
        (words.filter { stage(level, $0.full) >= learnedStage }.count, words.count)
    }

    /// The Words step is done when 70 % of the unit's words reached the "written" stage.
    static func unitDone(_ level: String, _ words: [UnitDrillWord]) -> Bool {
        let p = progress(level, words)
        return p.total > 0 && Double(p.learned) >= Double(p.total) * 0.7
    }
}

extension A1Model {
    /// Exactly the words the unit's Words page shows, so practice and the unit test never ask words the learner
    /// has not met in this unit.
    func unitDrillWords(_ unit: LearningUnit) -> [UnitDrillWord] {
        if let vocab = unit.vocab, vocab.count >= 4 {
            return vocab.map { UnitDrillWord(de: $0.de, art: $0.art, meaning: $0.meaning) }
        }
        let all = content?.words ?? []
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var picked = (unit.pictures ?? []).compactMap { byID[$0] }
        if picked.isEmpty { picked = Array(all.filter { unit.themes.contains($0.theme) && $0.isNoun }.prefix(16)) }
        picked += (unit.extra ?? []).compactMap { byID[$0] }
        return picked.map { UnitDrillWord(de: $0.de, art: $0.isNoun ? $0.type : nil, meaning: $0.mean.text, example: $0.ex.first) }
    }

    /// A practice round that follows each word's stage: new words are recognised, known ones recalled, then
    /// written, then used in a sentence. Words not learned yet and words due again come first; about one in five
    /// questions repeats a due word of an earlier unit of the level.
    func unitWordSession(_ unit: LearningUnit, count: Int = 16) -> [A1Question] {
        let words = unitDrillWords(unit)
        guard words.count >= 4 else { return [] }
        let level = unit.level
        func rank(_ word: UnitDrillWord) -> Int {
            let due = WordMastery.isDue(level, word.full)
            if WordMastery.stage(level, word.full) >= 4 { return due ? 2 : 3 }
            return due ? 0 : 1
        }
        let ordered = words.shuffled().sorted { rank($0) < rank($1) }
        let earlier = UnitBank.units(level).filter { $0.number < unit.number }.flatMap { unitDrillWords($0) }
            .filter { WordMastery.stage(level, $0.full) > 0 && WordMastery.isDue(level, $0.full) }
            .shuffled()
        let reviewCount = min(earlier.count, count / 5)
        var out = ordered.prefix(count - reviewCount).map { wordQuestion($0, unit: unit, pool: words) }
        out += earlier.prefix(reviewCount).map { wordQuestion($0, unit: unit, pool: earlier.count >= 4 ? earlier : words + earlier) }
        return out.shuffled()
    }

    /// The question for a word at its current stage. Wrong options come from the same pool of words.
    private func wordQuestion(_ word: UnitDrillWord, unit: LearningUnit, pool: [UnitDrillWord]) -> A1Question {
        let level = unit.level
        let label = unit.title.text
        let others = pool.filter { $0.full != word.full }
        let info = "\(word.full) = \(word.meaning)"
        func id(_ kind: String) -> String { WordMastery.questionID(kind, level, word.full) }
        func choices(_ right: String, _ wrong: [String]) -> [String] {
            ([right] + Array(Set(wrong.filter { $0 != right })).shuffled().prefix(3)).shuffled()
        }
        let meaningQuestion = A1Question(id: id("m"), mode: .wordToTr, kind: .choice, label: label, prompt: word.full,
                                         speakAfter: word.full, options: choices(word.meaning, others.map(\.meaning)),
                                         answer: word.meaning, explanation: info)
        let writeQuestion = A1Question(id: id("w"), mode: .write, kind: .typing, label: label, prompt: word.meaning,
                                       detail: t("q.writeWord"), speakAfter: word.full, answer: word.full, explanation: info)
        switch WordMastery.stage(level, word.full) {
        case 0:
            return meaningQuestion
        case 1:
            var kinds = ["recall", "listen"]
            if word.art != nil { kinds.append("article") }
            switch kinds.randomElement() ?? "recall" {
            case "listen":
                return A1Question(id: id("l"), mode: .listen, kind: .choice, label: label, prompt: t("q.listenWord"),
                                  speakFirst: word.full, options: choices(word.full, others.map(\.full)), answer: word.full,
                                  explanation: info)
            case "article":
                return A1Question(id: id("a"), mode: .artikel, kind: .choice, label: label, prompt: "___ \(word.de)",
                                  detail: word.meaning, speakAfter: word.full, options: ["der", "die", "das"],
                                  answer: word.art ?? "der", explanation: word.full)
            default:
                return A1Question(id: id("r"), mode: .trToWord, kind: .choice, label: label, prompt: word.meaning,
                                  speakAfter: word.full, options: choices(word.full, others.map(\.full)), answer: word.full,
                                  explanation: info)
            }
        case 2:
            return writeQuestion
        default:
            return sentenceQuestion(word, label: label, others: others, id: id("s")) ?? writeQuestion
        }
    }

    /// Stage 3+: the word in its example sentence — a gap to fill (nouns, exact form) or the sentence to put in order.
    private func sentenceQuestion(_ word: UnitDrillWord, label: String, others: [UnitDrillWord], id: String) -> A1Question? {
        guard let example = word.example else { return nil }
        let punctuation = CharacterSet(charactersIn: ".,!?;:„“\"()")
        let tokens = example.de.split(separator: " ").map(String.init)
        if word.art != nil, let hit = tokens.firstIndex(where: { $0.trimmingCharacters(in: punctuation).lowercased() == word.de.lowercased() }) {
            var gapped = tokens
            gapped[hit] = tokens[hit].replacingOccurrences(of: tokens[hit].trimmingCharacters(in: punctuation), with: "_____")
            let wrong = others.filter { $0.art != nil }.map(\.de)
            let options = ([word.de] + Array(Set(wrong.filter { $0 != word.de })).shuffled().prefix(3)).shuffled()
            guard options.count == 4 else { return nil }
            return A1Question(id: id, mode: .cloze, kind: .choice, label: label, prompt: gapped.joined(separator: " "),
                              detail: example.mean.text, speakAfter: example.de, options: options, answer: word.de,
                              explanation: "\(example.de)\n\(word.full) = \(word.meaning)")
        }
        guard (3...9).contains(tokens.count) else { return nil }
        var shuffled = tokens.shuffled()
        var tries = 0
        while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
        return A1Question(id: id, mode: .order, kind: .order, label: label, prompt: example.mean.text,
                          detail: t("q.orderWords"), speakAfter: example.de, options: shuffled,
                          answer: tokens.joined(separator: " "), explanation: "\(example.de)\n\(word.full) = \(word.meaning)")
    }
}

// MARK: - Unit stories

/// Path stories (Resources/content/stories_a1.json, made by tools/stories.py from ChatGPT answers): written with the
/// unit's words only. Stored like daily texts, so the reading screen, its quiz and the word bubble work the same.
enum StoryBank {
    private struct File: Decodable {
        let texts: [DailyText]
        let units: [String: [String]]
    }

    private static let file: File? = Bundled.decode(File.self, "stories_a1")

    static func stories(_ unit: String) -> [DailyText] {
        (file?.units[unit] ?? []).compactMap { id in file?.texts.first { $0.id == id } }
    }

    static func text(id: String) -> DailyText? { file?.texts.first { $0.id == id } }
}

/// The unit's reading step when it has stories: its stories first (made for this unit), then the daily text.
struct UnitStoriesView: View {
    @EnvironmentObject private var daily: DailyModel
    let unit: LearningUnit
    let stories: [DailyText]
    let dailyText: DailyText?

    var body: some View {
        List {
            Section {
                ForEach(stories) { story in row(story, icon: story.paragraphs.first?.contains(": ") == true ? "bubble.left.and.bubble.right.fill" : "book.fill") }
            } footer: {
                Text(t("unit.storiesNote"))
            }
            if let dailyText {
                Section { row(dailyText, icon: "newspaper.fill") }
            }
        }
        .navigationTitle(t("unit.step.text"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ text: DailyText, icon: String) -> some View {
        NavigationLink {
            DailyReadingView(text: text).onAppear { UnitStore.mark(.text, unit.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: daily.isCompleted(text) ? "checkmark.circle.fill" : icon)
                    .foregroundColor(daily.isCompleted(text) ? DS.success : DS.goldDeep)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.title).font(.headline)
                    Text("\(text.level) · " + t("exam.minutes", text.minutes)).font(.caption).foregroundColor(DS.muted)
                }
            }
        }
    }
}

// MARK: - Unit grammar

extension A1Model {
    /// The unit's grammar questions, chosen so their sentences use words the learner already met: words of this
    /// and earlier units of the level and the basic A1 lists (important verbs, adjectives, small words).
    /// Questions with the fewest new words come first; the new words that are left get their meaning in the
    /// explanation. Before the unit that teaches the accusative, no question whose answer is an accusative form.
    func unitGrammarSession(_ unit: LearningUnit, count: Int = 8) -> [A1Question] {
        let per = max(2, count / max(1, unit.grammar.count))
        let early = Self.beforeAccusative(unit)
        let known = knownWordKeys(upTo: unit)
        let dictionary = wordForms()
        var out: [A1Question] = []
        for topic in unit.grammar {
            let candidates = questions
                .filter { $0.topic == topic && $0.mode == .grammar }
                .filter { !early || !Self.accusativeAnswers.contains($0.answer.lowercased()) }
                .map { q -> (A1Question, [A1Word]) in (q, newWords(in: q.prompt, known: known, dictionary: dictionary)) }
                .shuffled()
                .sorted { $0.1.count < $1.1.count }
            for (question, unknown) in candidates.prefix(per) {
                var q = question
                if !unknown.isEmpty {
                    let list = unknown.map { "\($0.isNoun ? "\($0.type) " : "")\($0.de) = \($0.mean.text)" }.joined(separator: "\n")
                    q.explanation = [q.explanation, t("grammar.newWords") + "\n" + list].compactMap { $0 }.joined(separator: "\n\n")
                }
                out.append(q)
            }
            // Case drills with the unit's own picture words, so the rule is practised on words the learner knows.
            out += caseDrills(topic: topic, nouns: cardNouns(upTo: unit), count: per)
        }
        return Array(out.shuffled().prefix(count + 4))
    }

    /// Concrete nouns (the picture-card words) of this and earlier units: safe in "Ich sehe …" / "neben …" sentences.
    private func cardNouns(upTo unit: LearningUnit) -> [UnitDrillWord] {
        let all = content?.words ?? []
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return UnitBank.units(unit.level).filter { $0.number <= unit.number }
            .flatMap { ($0.pictures ?? []).compactMap { byID[$0] } }
            .filter { $0.isNoun && !$0.de.contains(" ") }
            .map { UnitDrillWord(de: $0.de, art: $0.type, meaning: $0.mean.text) }
    }

    /// Generated drills for the A1 case topics: articles (4), Nominativ & Akkusativ (6), Dativ (7), possessives (9).
    /// Each question names the rule in a short formula ("sehen + Akkusativ: der → den").
    private func caseDrills(topic: Int, nouns: [UnitDrillWord], count: Int) -> [A1Question] {
        guard [4, 6, 7, 9].contains(topic), nouns.count >= 3 else { return [] }
        let label = content?.grammar.first { $0.id == topic }?.de ?? ""
        var out: [A1Question] = []
        for word in nouns.shuffled().prefix(count) {
            guard let art = word.art else { continue }
            func question(_ kind: String, _ prompt: String, _ options: [String], _ answer: String, _ rule: String) -> A1Question {
                A1Question(id: "gc\(topic)\(kind)-\(word.de)", mode: .grammar, kind: .choice, label: label, topic: topic,
                           prompt: prompt, detail: word.meaning, speakAfter: prompt.replacingOccurrences(of: "___", with: answer),
                           options: options.shuffled(), answer: answer, explanation: "\(word.full) · \(rule)")
            }
            let indefinite = art == "die" ? "eine" : "ein"
            switch (topic, Bool.random()) {
            case (4, true):
                out.append(question("n", "___ \(word.de) ist neu.", ["Der", "Die", "Das"], art.capitalized,
                                    "Nominativ: der · die · das"))
            case (4, false):
                out.append(question("i", "Das ist ___ \(word.de).", ["ein", "eine", "einen"], indefinite,
                                    "ein (der, das) · eine (die)"))
            case (6, true):
                let akk = art == "der" ? "den" : art
                out.append(question("a", "Ich sehe ___ \(word.de).", ["der", "den", "die", "das"], akk,
                                    "sehen + Akkusativ (Wen? Was?): der → den · die → die · das → das"))
            case (6, false):
                let akk = art == "der" ? "einen" : indefinite
                out.append(question("b", "Ich brauche ___ \(word.de).", ["ein", "einen", "eine"], akk,
                                    "brauchen + Akkusativ: ein → einen (der) · eine · ein"))
            case (7, _):
                let dat = art == "die" ? "der" : "dem"
                out.append(question("d", "Die Tasche ist neben ___ \(word.de).", ["dem", "den", "der", "die"], dat,
                                    "neben (Wo?) + Dativ: der → dem · das → dem · die → der"))
            default:
                let poss = art == "die" ? "meine" : "mein"
                out.append(question("p", "Das ist ___ \(word.de).", ["mein", "meine", "meinen"], poss,
                                    "mein (der, das) · meine (die)"))
            }
        }
        return out
    }

    /// Lower-case German words the learner has met by this unit.
    private func knownWordKeys(upTo unit: LearningUnit) -> Set<String> {
        var known = Set<String>()
        for earlier in UnitBank.units(unit.level) where earlier.number <= unit.number {
            for word in unitDrillWords(earlier) { known.insert(word.de.lowercased()) }
        }
        // Basic lists of A1 (important verbs, adjectives, question and small words): taught all along.
        for word in content?.words ?? [] where (12...14).contains(word.theme) { known.insert(word.de.lowercased()) }
        return known
    }

    /// Level words by their written forms (word and plural), to recognise them in a sentence.
    private func wordForms() -> [String: A1Word] {
        var forms: [String: A1Word] = [:]
        for word in content?.words ?? [] where !word.de.contains(" ") && word.theme != A1BankBuilder.coreTheme {
            forms[word.de.lowercased()] = word
            if let plural = word.plural, !plural.isEmpty, !plural.contains(" ") { forms[plural.lowercased()] = word }
        }
        return forms
    }

    /// Level words in the sentence the learner has not met yet (names and inflected forms are not counted).
    private func newWords(in sentence: String, known: Set<String>, dictionary: [String: A1Word]) -> [A1Word] {
        let punctuation = CharacterSet(charactersIn: ".,!?;:„“\"()_")
        var result: [A1Word] = []
        for token in sentence.split(separator: " ") {
            let core = token.trimmingCharacters(in: punctuation).lowercased()
            guard core.count > 2, let word = dictionary[core], !known.contains(word.de.lowercased()),
                  !result.contains(where: { $0.id == word.id }) else { continue }
            result.append(word)
        }
        return result
    }

    /// A1 topic "Nominativ & Akkusativ" (a1.json grammar id 6): units before the one that teaches it get no
    /// questions whose answer is an accusative form ("seinen Onkel" in unit 2 came before the accusative).
    private static let accusativeTopic = 6
    private static let accusativeAnswers: Set<String> = ["einen", "keinen", "meinen", "deinen", "seinen", "ihren",
                                                          "unseren", "euren", "den", "ihn"]

    private static func beforeAccusative(_ unit: LearningUnit) -> Bool {
        guard unit.level == "A1",
              let teaching = UnitBank.units("A1").first(where: { $0.grammar.contains(accusativeTopic) }) else { return false }
        return unit.number < teaching.number
    }
}

/// The unit's grammar step: first a short rule and examples for each topic, then the practice.
struct UnitGrammarIntroView: View {
    @EnvironmentObject private var model: A1Model
    let unit: LearningUnit

    var body: some View {
        let topics = unit.grammar.compactMap { id in model.content?.grammar.first { $0.id == id } }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("unit.grammarIntro")).font(.subheadline).foregroundColor(DS.muted)
                ForEach(topics, id: \.id) { topic in
                    GrammarRuleCard(topic: topic)
                }
                NavigationLink {
                    A1QuizView(title: t("unit.step.grammar"), onFinish: { _, _ in UnitStore.mark(.grammar, unit.id) }) {
                        model.unitGrammarSession(unit)
                    }
                } label: {
                    Text(t("unit.grammarStart"))
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("unit.step.grammar"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A grammar topic explained: title, then the rule line by line — a line of "a · b · c" (a small table such as
/// "ich bin · du bist …") becomes a row of chips, with any lead text before its colon kept as text — and the
/// examples to listen to. Used on the path's grammar step and in Practice → Grammar.
struct GrammarRuleCard: View {
    let topic: A1GrammarTopic

    private var lines: [String] {
        topic.rule.text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.onGold)
                    .frame(width: 36, height: 36)
                    .background(DS.gold, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(topic.name.text).font(.system(size: 18, weight: .bold)).foregroundColor(DS.ink)
                    Text(topic.de).font(.caption.weight(.semibold)).foregroundColor(DS.muted)
                }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                ruleLine(line)
            }
            if !topic.examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("workbook.examples").uppercased()).font(.caption2.weight(.bold)).foregroundColor(DS.muted)
                    ForEach(topic.examples, id: \.self) { example in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.de).font(.system(size: 16, weight: .semibold)).foregroundColor(DS.ink)
                                Text(example.mean.text).font(.footnote).foregroundColor(DS.muted)
                            }
                            Spacer(minLength: 0)
                            A1SpeakButton(text: example.de)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.ground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func ruleLine(_ line: String) -> some View {
        if line.contains(" · ") {
            let colon = line.range(of: ": ")
            let firstDot = line.range(of: " · ")
            let hasLead = colon != nil && firstDot != nil && colon!.lowerBound < firstDot!.lowerBound
            let lead = hasLead ? String(line[..<colon!.lowerBound]) : nil
            let table = hasLead ? String(line[colon!.upperBound...]) : line
            VStack(alignment: .leading, spacing: 6) {
                if let lead {
                    Text(lead + ":").font(.system(size: 15)).foregroundColor(DS.ink).fixedSize(horizontal: false, vertical: true)
                }
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(table.components(separatedBy: " · ").enumerated()), id: \.offset) { _, part in
                        Text(part)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DS.gold.opacity(0.18), in: Capsule())
                    }
                }
            }
        } else {
            Text(line).font(.system(size: 15)).foregroundColor(DS.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}
