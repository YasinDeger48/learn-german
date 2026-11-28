import SwiftUI

// MARK: - Content (Resources/content/verbs_<level>.json, made by tools/verblab.py from ChatGPT answers)

struct VerbSentence: Decodable, Hashable {
    /// Tense of an example: praesens, praeteritum, perfekt, futur (nil for questions and phrases).
    let t: String?
    let de: String
    let tr: String
    let en: String?
    let note: String?
    /// Other learner languages (tools/translate.py adds them).
    var es: String?, fr: String?, it: String?, ku: String?, ar: String?

    var meaning: String { localText(tr: tr, en: en, es: es, fr: fr, it: it, ku: ku, ar: ar) }
}

struct VerbEntry: Decodable, Identifiable, Hashable {
    let v: String
    let tr: String
    let en: String
    let praesens: [String]
    let praeteritum: [String]
    let perfekt: String
    let futur: String
    let imperativ: [String]
    let trennbar: Bool
    let reflexiv: Bool
    let rektion: String?
    let examples: [VerbSentence]
    let questions: [VerbSentence]
    let common: [VerbSentence]
    let complex: [VerbSentence]
    var es: String?, fr: String?, it: String?, ku: String?, ar: String?

    var id: String { v }
    var meaning: String { localText(tr: tr, en: en, es: es, fr: fr, it: it, ku: ku, ar: ar) }

    static let persons = ["ich", "du", "er/sie/es", "wir", "ihr", "sie/Sie"]

    /// "ist gegangen" → bin/bist/ist/sind/seid/sind gegangen.
    var perfektForms: [String] {
        let parts = perfekt.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return Array(repeating: perfekt, count: 6) }
        let aux = parts[0] == "ist" ? ["bin", "bist", "ist", "sind", "seid", "sind"] : ["habe", "hast", "hat", "haben", "habt", "haben"]
        return aux.map { "\($0) \(parts[1])" }
    }

    /// "wird gehen" → werde/wirst/wird/werden/werdet/werden gehen.
    var futurForms: [String] {
        let rest = futur.split(separator: " ", maxSplits: 1).dropFirst().joined()
        return ["werde", "wirst", "wird", "werden", "werdet", "werden"].map { "\($0) \(rest)" }
    }
}

private struct VerbFile: Decodable {
    let verbs: [VerbEntry]
}

enum VerbBank {
    private static var cache: [String: [VerbEntry]] = [:]

    static func verbs(_ level: String) -> [VerbEntry] {
        if let list = cache[level] { return list }
        let list = Bundled.decode(VerbFile.self, "verbs_\(level.lowercased())")?.verbs ?? []
        cache[level] = list
        return list
    }

    static func verb(_ infinitive: String) -> VerbEntry? {
        for level in LevelModels.practiceLevels {
            if let found = verbs(level).first(where: { $0.v == infinitive }) { return found }
        }
        return nil
    }
}

enum VerbTense: String, CaseIterable, Identifiable {
    case praesens, praeteritum, perfekt, futur, imperativ

    var id: String { rawValue }
    var title: String {
        switch self {
        case .praesens: return "Präsens"
        case .praeteritum: return "Präteritum"
        case .perfekt: return "Perfekt"
        case .futur: return "Futur"
        case .imperativ: return "Imperativ"
        }
    }

    func forms(_ verb: VerbEntry) -> [(person: String, form: String)] {
        switch self {
        case .praesens: return zip(VerbEntry.persons, verb.praesens).map { ($0, $1) }
        case .praeteritum: return zip(VerbEntry.persons, verb.praeteritum).map { ($0, $1) }
        case .perfekt: return zip(VerbEntry.persons, verb.perfektForms).map { ($0, $1) }
        case .futur: return zip(VerbEntry.persons, verb.futurForms).map { ($0, $1) }
        case .imperativ: return zip(["du", "ihr", "Sie"], verb.imperativ).map { ($0, $1) }
        }
    }
}

// MARK: - List

struct VerbLabHomeView: View {
    @EnvironmentObject private var model: A1Model
    @State private var search = ""

    var body: some View {
        let all = VerbBank.verbs(model.level)
        let shown = search.isEmpty ? all : all.filter {
            $0.v.localizedCaseInsensitiveContains(search) || $0.meaning.localizedCaseInsensitiveContains(search)
        }
        List {
            if all.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("verb.empty")).font(.headline)
                    Text(t("verb.emptySub")).font(.subheadline).foregroundColor(DS.muted)
                }
                .padding(.vertical, 8)
            } else {
                Section {
                    ForEach(shown) { verb in
                        NavigationLink(value: AppRoute.verb(verb.v)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verb.v).font(.headline)
                                    Text(verb.meaning).font(.subheadline).foregroundColor(DS.muted)
                                }
                                Spacer()
                                Text(verb.perfekt).font(.caption).foregroundColor(DS.muted)
                            }
                        }
                    }
                } footer: {
                    Text(t("verb.count", all.count))
                }
            }
        }
        .searchable(text: $search, prompt: t("verb.search"))
        .navigationTitle(t("verb.title"))
        .adBanner()
    }
}

// MARK: - One verb

struct VerbDetailView: View {
    let verb: VerbEntry
    @State private var tense: VerbTense = .praesens
    @State private var section = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Picker(t("verb.tense"), selection: $tense) {
                    ForEach(VerbTense.allCases) { Text($0 == .imperativ ? "Imp." : $0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                table

                Picker("", selection: $section) {
                    Text(t("verb.examples")).tag(0)
                    Text(t("verb.questions")).tag(1)
                    Text(t("verb.common")).tag(2)
                    Text(t("verb.complex")).tag(3)
                }
                .pickerStyle(.segmented)
                VStack(spacing: 10) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in sentenceCard(sentence) }
                }

                NavigationLink(value: AppRoute.verbGame(verb.v)) {
                    Label(t("verb.play"), systemImage: "gamecontroller.fill")
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
        .navigationTitle(verb.v)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sentences: [VerbSentence] {
        switch section {
        case 0: return verb.examples
        case 1: return verb.questions
        case 2: return verb.common
        default: return verb.complex
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verb.v).font(DS.display(34)).foregroundColor(DS.ink)
                Text(verb.meaning).font(DS.text(17)).foregroundColor(DS.muted)
                HStack(spacing: 6) {
                    chip("Perfekt: \(verb.perfekt)")
                    if verb.trennbar { chip(t("verb.separable")) }
                    if verb.reflexiv { chip(t("verb.reflexive")) }
                }
                if let rektion = verb.rektion, !rektion.isEmpty {
                    Text(rektion).font(.footnote).foregroundColor(DS.muted)
                }
            }
            Spacer(minLength: 0)
            A1SpeakButton(text: verb.v)
        }
        .speaksOnTap(verb.v)
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundColor(DS.ink)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(DS.chip, in: Capsule())
    }

    private var table: some View {
        VStack(spacing: 0) {
            ForEach(Array(tense.forms(verb).enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider() }
                Button {
                    A1Speaker.shared.say(tense == .imperativ ? row.form : "\(row.person.components(separatedBy: "/").first ?? row.person) \(row.form)")
                } label: {
                    HStack {
                        Text(row.person).font(DS.text(15)).foregroundColor(DS.muted).frame(width: 92, alignment: .leading)
                        Text(row.form).font(DS.text(17, .semibold)).foregroundColor(DS.ink)
                        Spacer()
                        Image(systemName: "speaker.wave.2").font(.caption).foregroundColor(DS.muted)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sentenceCard(_ sentence: VerbSentence) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                if let tenseName = sentence.t.flatMap({ VerbTense(rawValue: $0)?.title }) {
                    Text(tenseName.uppercased()).font(.caption2.weight(.bold)).foregroundColor(DS.goldDeep)
                }
                Text(sentence.de).font(DS.text(17, .semibold)).foregroundColor(DS.ink)
                Text(sentence.meaning).font(DS.text(14)).foregroundColor(DS.muted)
                if let note = sentence.note, !note.isEmpty {
                    Label(note, systemImage: "lightbulb").font(.caption).foregroundColor(DS.accent)
                }
            }
            Spacer(minLength: 0)
            A1SpeakButton(text: sentence.de)
        }
        .padding(14)
        .speaksOnTap(sentence.de)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - The game

/// Ten questions made from one verb's data: forms in every tense, which tense a sentence is in,
/// meanings, and putting a question / a complex sentence in the right order.
enum VerbGame {
    static func questions(_ verb: VerbEntry, others: [VerbEntry]) -> [A1Question] {
        var out: [A1Question] = []
        let label = "\(verb.v) · \(verb.meaning)"
        func choice(_ id: String, _ prompt: String, _ detail: String?, _ answer: String, _ wrong: [String], speak: String? = nil, why: String? = nil) {
            let options = Array(([answer] + Array(Set(wrong.filter { $0 != answer })).shuffled().prefix(3)).shuffled())
            guard options.count >= 3 else { return }
            out.append(A1Question(id: "vl-\(verb.v)-\(id)", mode: .verbs, kind: .choice, label: label, prompt: prompt, detail: detail,
                                  speakAfter: speak, options: options, answer: answer, explanation: why))
        }
        // Forms: two persons in Präsens, one in Präteritum, the Perfekt and the Futur.
        guard verb.praesens.count >= 6, verb.praeteritum.count >= 6 else { return out }
        let persons = Array(0..<6).shuffled()
        for (n, p) in persons.prefix(2).enumerated() {
            choice("pr\(n)", "\(VerbEntry.persons[p]) ___", "Präsens · \(verb.v)", verb.praesens[p], verb.praesens + verb.praeteritum,
                   speak: "\(VerbEntry.persons[p].components(separatedBy: "/")[0]) \(verb.praesens[p])")
        }
        let p = persons[2]
        choice("pt", "\(VerbEntry.persons[p]) ___", "Präteritum · \(verb.v)", verb.praeteritum[p], verb.praeteritum + verb.praesens)
        let otherPerfekt = others.map(\.perfekt).filter { $0 != verb.perfekt }.shuffled().prefix(6)
        let swapped = verb.perfekt.hasPrefix("ist ") ? "hat " + verb.perfekt.dropFirst(4) : "ist " + verb.perfekt.dropFirst(4)
        choice("pf", "Perfekt: \(verb.v) (er)", nil, verb.perfekt, [String(swapped)] + otherPerfekt, speak: "er \(verb.perfekt)")
        let p2 = persons[3]
        choice("fu", "\(VerbEntry.persons[p2]) ___ (Futur)", verb.v, verb.futurForms[p2], verb.futurForms + verb.perfektForms)
        // Which tense?
        for (n, ex) in verb.examples.shuffled().prefix(2).enumerated() {
            if let tense = ex.t.flatMap(VerbTense.init(rawValue:)) {
                choice("tn\(n)", ex.de, t("verb.whichTense"), tense.title,
                       ["Präsens", "Präteritum", "Perfekt", "Futur"], speak: ex.de, why: ex.meaning)
            }
        }
        // Meaning of a common phrase.
        if let phrase = verb.common.randomElement() {
            let wrong = others.flatMap(\.common).map(\.meaning).shuffled().prefix(5)
            choice("cm", phrase.de, t("verb.meaningOf"), phrase.meaning, Array(wrong), speak: phrase.de)
        }
        // Word order: a question and a complex sentence.
        for (id, sentence) in [("oq", verb.questions.randomElement()), ("oc", verb.complex.randomElement())] {
            guard let sentence else { continue }
            let tokens = sentence.de.split(separator: " ").map(String.init)
            guard tokens.count >= 3 && tokens.count <= 12 else { continue }
            var shuffled = tokens.shuffled()
            var tries = 0
            while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
            out.append(A1Question(id: "vl-\(verb.v)-\(id)", mode: .order, kind: .order, label: label, prompt: sentence.meaning,
                                  detail: t("q.orderWords"), speakAfter: sentence.de, options: shuffled,
                                  answer: tokens.joined(separator: " "), explanation: sentence.note))
        }
        return out
    }
}
