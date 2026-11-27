import SwiftUI

// MARK: - Tembel Mod (lazy mode)
// The learner only watches and listens: a slide show over the app, Lina reads every slide aloud and the next one
// comes when she has finished AND there was time to read everything on it (long slides stay longer).
// Design: https://claude.ai/artifact/6zFB7bGLPD61mYDWeeKBKs (owner's choice: name "Tembel Mod", the whole level).

enum LazyTopic: String, CaseIterable, Identifiable {
    case words, articles, meaning, plural, verbs, questions, must

    var id: String { rawValue }
    var title: String { t("lazy.topic.\(rawValue)") }
    var sub: String { t("lazy.topicSub.\(rawValue)") }
    /// The guessing games: the answer shows after a pause.
    var isGame: Bool { self == .articles || self == .meaning || self == .plural }
    /// Topics built from the level's nouns (the word pool applies to them).
    var usesNouns: Bool { self == .words || isGame }

    var icon: String {
        switch self {
        case .words: return "character.book.closed.fill"
        case .articles: return "questionmark.bubble.fill"
        case .meaning: return "lightbulb.fill"
        case .plural: return "square.on.square.fill"
        case .verbs: return "bolt.fill"
        case .questions: return "bubble.left.and.bubble.right.fill"
        case .must: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .words: return Color(red: 0.36, green: 0.55, blue: 0.96)
        case .articles: return Color(red: 0.94, green: 0.36, blue: 0.40)
        case .meaning: return Color(red: 0.98, green: 0.66, blue: 0.13)
        case .plural: return Color(red: 0.13, green: 0.71, blue: 0.62)
        case .verbs: return Color(red: 0.55, green: 0.36, blue: 0.94)
        case .questions: return Color(red: 0.11, green: 0.62, blue: 0.86)
        case .must: return Color(red: 0.85, green: 0.47, blue: 0.13)
        }
    }
}

/// What the learner chose in the setup sheet.
struct LazyConfig: Identifiable {
    let id = UUID()
    let level: String
    let topics: Set<LazyTopic>
    /// 0 = endless.
    let minutes: Int
    /// The learner's own word pool (word ids) for the noun topics; nil = all nouns of the level.
    var pool: Set<Int>? = nil
}

/// The learner's own word pool per level (Tembel Mod → "My pool"), kept on the phone.
enum LazyPool {
    private static func key(_ level: String) -> String { "lazy.pool.\(level.uppercased())" }
    private static func useKey(_ level: String) -> String { "lazy.usePool.\(level.uppercased())" }

    static func ids(_ level: String) -> Set<Int> { Set(UserDefaults.standard.array(forKey: key(level)) as? [Int] ?? []) }
    static func save(_ ids: Set<Int>, level: String) { UserDefaults.standard.set(Array(ids).sorted(), forKey: key(level)) }
    static func isOn(_ level: String) -> Bool { UserDefaults.standard.bool(forKey: useKey(level)) }
    static func setOn(_ on: Bool, level: String) { UserDefaults.standard.set(on, forKey: useKey(level)) }
}

enum LazySlide {
    case noun(A1Word, picture: String?)
    case examples(A1Word)
    case verb(VerbEntry)
    case verbExamples(VerbEntry)
    case article(A1Word, picture: String?)
    /// Guess what the word means; the meaning shows after a pause.
    case meaning(A1Word, picture: String?)
    /// Guess the plural; it shows after a pause.
    case plural(A1Word, picture: String?)
    case question(VerbSentence, verb: VerbEntry)
    case must(MemorizeSheet, MemorizeRow)

    /// A guessing slide: the answer shows after a pause.
    var isGuess: Bool {
        switch self {
        case .article, .meaning, .plural: return true
        default: return false
        }
    }

    /// Lina reads it only when the answer shows (reading it first would give the answer away).
    var readsAtReveal: Bool {
        switch self {
        case .article, .plural: return true
        default: return false
        }
    }

    /// German lines Lina reads (the translations are on screen; the reading voice is German).
    var lines: [String] {
        switch self {
        case .noun(let word, _):
            var out = [word.withArticle]
            if let plural = word.plural, !plural.isEmpty { out.append("die \(plural)") }
            return out
        case .examples(let word):
            return word.ex.prefix(3).map(\.de)
        case .verb(let verb):
            var out = [verb.v]
            for (person, form) in zip(["ich", "du", "er"], verb.praesens) { out.append("\(person) \(form)") }
            if let past = verb.praeteritum.first { out.append("ich \(past)") }
            out.append("er \(verb.perfekt)")
            out.append("er \(verb.futur)")
            return out
        case .verbExamples(let verb):
            return verb.examples.prefix(4).map(\.de)
        case .article(let word, _):
            return [word.withArticle]  // read when the answer shows
        case .meaning(let word, _):
            return [word.withArticle]
        case .plural(let word, _):
            return ["die \(word.plural ?? "")"]  // read when the answer shows
        case .question(let sentence, _):
            return [sentence.de]
        case .must(_, let row):
            return [row.x ?? row.a]
        }
    }

    /// Seconds to read everything on the slide at normal speed: longer slides stay longer (owner's feedback).
    var readingSeconds: Double {
        let chars: Int
        switch self {
        case .noun(let word, _):
            chars = word.withArticle.count + (word.plural?.count ?? 0) + word.mean.text.count + 20
        case .examples(let word):
            chars = word.ex.prefix(3).reduce(0) { $0 + $1.de.count + $1.mean.text.count }
        case .verb(let verb):
            chars = verb.v.count + verb.meaning.count + verb.praesens.joined().count + 60
        case .verbExamples(let verb):
            chars = verb.examples.prefix(4).reduce(0) { $0 + $1.de.count + $1.meaning.count }
        case .article(let word, _), .meaning(let word, _):
            chars = word.de.count + word.mean.text.count + 40
        case .plural(let word, _):
            chars = word.de.count + (word.plural?.count ?? 0) + word.mean.text.count + 40
        case .question(let sentence, let verb):
            chars = sentence.de.count + sentence.meaning.count + verb.v.count + verb.meaning.count
        case .must(let sheet, let row):
            chars = sheet.title.text.count + row.q.text.count + row.a.count + (row.x?.count ?? 0)
        }
        return min(28, max(7, 4 + Double(chars) / 12))
    }
}

/// One slide and the word it belongs to: Tembel Mod stays on one word for a few slides (owner's feedback: no
/// jumping from one thing to another), e.g. die Kerze: guess the article → the word → its sentences.
struct LazyCard {
    let slide: LazySlide
    let focus: String
    let step: Int
    let steps: Int
}

/// Builds the session from what the app already has: level nouns (with pictures where there are), the verb lab
/// and the "Mutlaka bil" sheets. Each word is a block of slides; nouns and verbs take turns.
enum LazyDeck {
    static func make(_ config: LazyConfig, content: A1Content?) -> [LazyCard] {
        let level = config.level
        let topics = config.topics
        var nounBlocks: [[LazySlide]] = []
        if topics.contains(where: \.usesNouns) {
            var nouns = (content?.words ?? []).filter(\.isNoun)
            if let pool = config.pool, !pool.isEmpty { nouns = nouns.filter { pool.contains($0.id) } }
            // One word, several steps: der/die/das? → what does it mean? → the word → its plural? → its sentences.
            for word in nouns.shuffled().prefix(120) {
                let picture = picture(for: word, level: level)
                var block: [LazySlide] = []
                if topics.contains(.articles) { block.append(.article(word, picture: picture)) }
                if topics.contains(.meaning) { block.append(.meaning(word, picture: picture)) }
                if topics.contains(.words) { block.append(.noun(word, picture: picture)) }
                if topics.contains(.plural), let plural = word.plural, !plural.isEmpty, plural != "-" {
                    block.append(.plural(word, picture: picture))
                }
                if topics.contains(.words), !word.ex.isEmpty { block.append(.examples(word)) }
                if !block.isEmpty { nounBlocks.append(block) }
            }
        }
        var verbBlocks: [[LazySlide]] = []
        if topics.contains(.verbs) || topics.contains(.questions) {
            for verb in VerbBank.verbs(level).shuffled().prefix(80) {
                var block: [LazySlide] = []
                if topics.contains(.verbs) {
                    block.append(.verb(verb))
                    if !verb.examples.isEmpty { block.append(.verbExamples(verb)) }
                }
                if topics.contains(.questions), let question = verb.questions.first {
                    block.append(.question(question, verb: verb))
                }
                if !block.isEmpty { verbBlocks.append(block) }
            }
        }
        var mustBlocks: [[LazySlide]] = []
        if topics.contains(.must) {
            mustBlocks = MemorizeBank.sheets(upTo: level).flatMap { sheet in sheet.rows.map { [LazySlide.must(sheet, $0)] } }
                .shuffled().prefix(40).map { $0 }
        }
        // Nouns and verbs take turns; a must-know phrase after every third word.
        var blocks: [[LazySlide]] = []
        var n = 0, v = 0, m = 0
        while n < nounBlocks.count || v < verbBlocks.count || m < mustBlocks.count {
            if n < nounBlocks.count { blocks.append(nounBlocks[n]); n += 1 }
            if v < verbBlocks.count { blocks.append(verbBlocks[v]); v += 1 }
            if m < mustBlocks.count, blocks.count % 3 == 0 || (n >= nounBlocks.count && v >= verbBlocks.count) {
                blocks.append(mustBlocks[m]); m += 1
            }
        }
        return blocks.flatMap { block in
            block.enumerated().map { step, slide in LazyCard(slide: slide, focus: focus(of: block[0]), step: step, steps: block.count) }
        }
    }

    private static func focus(of slide: LazySlide) -> String {
        switch slide {
        case .noun(let word, _), .examples(let word), .article(let word, _): return word.withArticle
        case .meaning(let word, _), .plural(let word, _): return word.withArticle
        case .verb(let verb), .verbExamples(let verb), .question(_, let verb): return verb.v
        case .must(let sheet, _): return sheet.title.text
        }
    }

    private static func picture(for word: A1Word, level: String) -> String? {
        let card = "wp-\(level.lowercased())-\(word.id)"
        if Covers.exists(card) { return card }
        var s = word.de.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { s = s.replacingOccurrences(of: from, with: to) }
        let noun = "wv-" + s.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "-")
        return Covers.exists(noun) ? noun : nil
    }
}

// MARK: - Entry card and setup

/// The setup sheet: what to watch (big tiles in the middle, the guessing games first), how long (a slider), and
/// which words (all nouns of the level or the learner's own pool).
struct LazySetupView: View {
    let level: String
    let words: [A1Word]
    let themes: [A1Theme]
    let start: (LazyConfig) -> Void
    @AppStorage("lazy.topics") private var topicsRaw = "articles,meaning,words,verbs"
    @AppStorage("lazy.minutes") private var minutes = 10
    @State private var pool: Set<Int> = []
    @State private var usePool = false

    private var topics: Set<LazyTopic> { Set(topicsRaw.split(separator: ",").compactMap { LazyTopic(rawValue: String($0)) }) }
    private var nouns: [A1Word] { words.filter(\.isNoun) }
    private var poolActive: Bool { usePool && !pool.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        LinaAvatar(size: 84, mood: .happy)
                        Text(t("lazy.setupTitle")).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(DS.ink)
                        Text(t("lazy.setupSub")).font(.subheadline).foregroundColor(DS.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                    section(t("lazy.games")) {
                        topicGrid(LazyTopic.allCases.filter(\.isGame))
                    }
                    section(t("lazy.watch")) {
                        topicGrid(LazyTopic.allCases.filter { !$0.isGame })
                    }
                    section(t("lazy.duration")) { durationCard }
                    if topics.contains(where: \.usesNouns) {
                        section(t("lazy.poolTitle")) { poolCard }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
            .background(DS.ground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { startButton }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(t("lazy.title"))
        }
        .onAppear {
            pool = LazyPool.ids(level)
            usePool = LazyPool.isOn(level)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.system(size: 12, weight: .heavy)).tracking(1.4).foregroundColor(DS.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func topicGrid(_ list: [LazyTopic]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(list) { topicTile($0) }
        }
    }

    private func topicTile(_ topic: LazyTopic) -> some View {
        let on = topics.contains(topic)
        return Button {
            var set = topics
            if on { set.remove(topic) } else { set.insert(topic) }
            topicsRaw = LazyTopic.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(on ? .white : topic.color)
                        .frame(width: 42, height: 42)
                        .background(on ? topic.color : topic.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer(minLength: 0)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(on ? topic.color : DS.hairline)
                }
                Text(topic.title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(DS.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text(topic.sub).font(.caption).foregroundColor(DS.muted)
                    .lineLimit(3).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? topic.color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Free: up to 10 minutes; Pro: up to 60 or endless.
    private var maxMinutes: Int { ProStore.isProNow ? 60 : 10 }

    /// Any number of minutes (1–60) with a slider, or endless.
    private var durationCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(minutes == 0 ? "∞" : "\(minutes)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(DS.ink)
                Text(minutes == 0 ? t("lazy.endless") : t("lazy.minuteUnit")).font(.headline).foregroundColor(DS.muted)
                Spacer()
                Button {
                    minutes = minutes == 0 ? 10 : 0
                } label: {
                    Label(t("lazy.endless"), systemImage: ProStore.isProNow ? "infinity" : "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(minutes == 0 ? DS.ground : DS.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(minutes == 0 ? DS.ink : DS.chip, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!ProStore.isProNow)
                .accessibilityAddTraits(minutes == 0 ? .isSelected : [])
            }
            Slider(value: Binding(get: { Double(min(maxMinutes, max(1, minutes))) }, set: { minutes = Int($0.rounded()) }),
                   in: 1...Double(maxMinutes), step: 1)
                .tint(DS.gold)
                .disabled(minutes == 0)
                .opacity(minutes == 0 ? 0.4 : 1)
                .accessibilityLabel(t("lazy.duration"))
                .accessibilityValue(t("lazy.minutes", max(1, minutes)))
            HStack {
                Text(t("lazy.minutes", 1)); Spacer(); Text(t("lazy.minutes", maxMinutes / 2)); Spacer(); Text(t("lazy.minutes", maxMinutes))
            }
            .font(.caption2).foregroundColor(DS.muted)
            if !ProStore.isProNow {
                HStack(spacing: 6) {
                    ProChip()
                    Text(t("lazy.proLonger")).font(.caption).foregroundColor(DS.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// All nouns of the level, or the learner's own pool (picked word by word).
    private var poolCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                poolChoice(false, t("lazy.poolAll", level), "\(nouns.count)")
                poolChoice(true, t("lazy.poolMine"), "\(pool.count)")
            }
            NavigationLink {
                LazyPoolView(level: level, nouns: nouns, themes: themes, pool: $pool)
                    .onDisappear {
                        LazyPool.save(pool, level: level)
                        if !pool.isEmpty { usePool = true; LazyPool.setOn(true, level: level) }
                    }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(pool.isEmpty ? t("lazy.poolCreate") : t("lazy.poolEdit"))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(DS.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            if usePool && pool.isEmpty {
                Text(t("lazy.poolEmpty")).font(.caption).foregroundColor(DS.error)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func poolChoice(_ mine: Bool, _ title: String, _ count: String) -> some View {
        let on = usePool == mine
        return Button {
            usePool = mine
            LazyPool.setOn(mine, level: level)
        } label: {
            VStack(spacing: 2) {
                Text(count).font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            }
            .foregroundColor(on ? DS.ground : DS.ink)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(on ? DS.ink : DS.chip, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var startButton: some View {
        Button {
            // A choice made while Pro (or free for all) is kept to the free limit without it.
            let allowed = ProStore.isProNow ? minutes : min(max(1, minutes), maxMinutes)
            start(LazyConfig(level: level, topics: topics, minutes: allowed, pool: poolActive ? pool : nil))
        } label: {
            Label(t("lazy.start"), systemImage: "play.fill")
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(DS.onGold)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(DS.gold, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(topics.isEmpty)
        .opacity(topics.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(DS.ground.opacity(0.96).ignoresSafeArea())
    }
}

/// Picking the learner's own pool: every noun of the level, searchable, by theme, tap to add or remove.
struct LazyPoolView: View {
    let level: String
    let nouns: [A1Word]
    let themes: [A1Theme]
    @Binding var pool: Set<Int>
    @State private var search = ""
    @State private var theme: Int?
    @State private var article: String?
    /// true: only the words the learner added; false: every noun of the level, to add more.
    @State private var onlyMine = true
    /// The pool when "mine" was opened, so a word unticked by mistake stays on screen to tick again.
    @State private var listed: Set<Int> = []
    @State private var started = false

    private var shown: [A1Word] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return nouns.filter { word in
            (!onlyMine || listed.contains(word.id))
                && (theme == nil || word.theme == theme)
                && (article == nil || word.type == article)
                && (query.isEmpty || word.de.lowercased().contains(query) || word.mean.text.lowercased().contains(query))
        }
    }

    private var usedThemes: [A1Theme] {
        let ids = Set(nouns.map(\.theme))
        return themes.filter { ids.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $onlyMine) {
                    Text(t("lazy.poolShowMine", pool.count)).tag(true)
                    Text(t("lazy.poolShowAll")).tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: onlyMine) { mine in if mine { listed = pool } }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip(t("lazy.poolAllThemes"), on: theme == nil && article == nil) { theme = nil; article = nil }
                        ForEach(["der", "die", "das"], id: \.self) { art in
                            chip(art, on: article == art, color: a1ArticleColor(art)) { article = article == art ? nil : art }
                        }
                        ForEach(usedThemes) { item in
                            chip(item.name.text, on: theme == item.id) { theme = theme == item.id ? nil : item.id }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                if !onlyMine {
                    HStack {
                        Button(t("lazy.poolAddShown", shown.count)) { pool.formUnion(shown.map(\.id)) }
                        Spacer()
                        Button(t("lazy.poolRemoveShown"), role: .destructive) { pool.subtract(shown.map(\.id)) }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
            Section(t("lazy.poolCount", pool.count)) {
                if onlyMine && listed.isEmpty {
                    Text(t("lazy.poolNoneYet")).font(.subheadline).foregroundColor(DS.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(shown) { word in
                    let on = pool.contains(word.id)
                    Button {
                        if on { pool.remove(word.id) } else { pool.insert(word.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Text(word.type).font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                                .frame(minWidth: 36, minHeight: 24)
                                .background(a1ArticleColor(word.type), in: Capsule())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(word.de).font(.system(size: 16, weight: .semibold)).foregroundColor(DS.ink)
                                Text(word.mean.text).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(on ? DS.success : DS.hairline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .searchable(text: $search, prompt: t("lazy.poolSearch"))
        .onAppear {
            // The first time: an empty pool opens on "add words", a filled one on the learner's own words.
            guard !started else { return }
            started = true
            listed = pool
            onlyMine = !pool.isEmpty
        }
        .navigationTitle(t("lazy.poolMine"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ title: String, on: Bool, color: Color = DS.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .bold))
                .foregroundColor(on ? .white : DS.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(on ? color : DS.chip, in: Capsule())
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Player

struct LazyPlayerView: View {
    let config: LazyConfig
    @EnvironmentObject private var model: A1Model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var deck: [LazyCard] = []
    @State private var index = 0
    @State private var elapsed: Double = 0          // on this slide
    @State private var watched: Double = 0          // whole session, seconds
    @State private var playing = true
    @State private var speedIndex = 1
    @State private var showTranslation = true
    @State private var caption = ""
    @State private var narrationEnded = false
    @State private var revealed = false
    @State private var finished = false
    @State private var slidesSeen = 0
    @AppStorage("lazy.muted") private var muted = false
    private let clock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private static let speeds: [Double] = [0.8, 1, 1.25]

    private static let ink = Color(red: 0.055, green: 0.059, blue: 0.047)
    private static let soft = Color(red: 0.42, green: 0.41, blue: 0.38)
    private static let paper = Color(red: 1, green: 0.992, blue: 0.965)
    private static let sand = Color(red: 0.957, green: 0.937, blue: 0.878)

    private var card: LazyCard? { deck.indices.contains(index) ? deck[index] : nil }
    private var slide: LazySlide? { card?.slide }
    private var speed: Double { Self.speeds[speedIndex] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if finished {
                    endCard
                } else if let slide {
                    ScrollView {
                        slideView(slide)
                            .id(index)
                            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                              removal: .opacity))
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            .padding(.bottom, 12)
                    }
                    captionStrip
                    controls
                } else {
                    Spacer()
                }
            }
            .background(Self.paper, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .environment(\.colorScheme, .light)
        .onAppear(perform: begin)
        .onDisappear {
            A1Speaker.shared.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(clock) { _ in tick() }
    }

    // MARK: Parts

    private var topBar: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(red: 0.91, green: 0.886, blue: 0.816))
                    Capsule().fill(Self.ink)
                        .frame(width: proxy.size.width * CGFloat(min(1, elapsed / max(1, readingTime))))
                }
            }
            .frame(height: 4)
            HStack(spacing: 10) {
                LinaAvatar(size: 38, mood: .calm)
                VStack(alignment: .leading, spacing: 2) {
                    // The word this block is about, and which of its slides this is.
                    Text(topTitle).font(.system(size: 17, weight: .heavy)).foregroundColor(Self.ink).lineLimit(1)
                    HStack(spacing: 4) {
                        if let card, card.steps > 1 {
                            ForEach(0..<card.steps, id: \.self) { step in
                                Capsule().fill(step <= card.step ? DS.gold : Color(red: 0.88, green: 0.85, blue: 0.77))
                                    .frame(width: step == card.step ? 16 : 8, height: 6)
                            }
                        }
                        Text(statusLine).font(.caption).foregroundColor(Self.soft).lineLimit(1)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundColor(Self.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("common.close"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    /// The word of this block; on an article question only the noun until the answer shows (it gave it away).
    private var topTitle: String {
        if let slide, case .article(let word, _) = slide, !revealed { return word.de }
        return card?.focus ?? t("lazy.title")
    }

    private var statusLine: String {
        var parts = ["\(config.level)", t("lazy.slide", slidesSeen + 1)]
        if config.minutes > 0 {
            parts.append(t("lazy.left", max(1, Int(ceil((Double(config.minutes) * 60 - watched) / 60)))))
        }
        return parts.joined(separator: " · ")
    }

    private var captionStrip: some View {
        HStack(spacing: 12) {
            SoundBars(active: playing && !narrationEnded && !reduceMotion)
            VStack(alignment: .leading, spacing: 1) {
                Text(t("lazy.reading")).font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundColor(DS.gold)
                Text(caption).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Self.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            roundButton(Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 15, weight: .bold)),
                        muted ? t("lazy.unmute") : t("lazy.mute")) {
                muted.toggle()
                if muted {
                    A1Speaker.shared.stop()
                    narrationEnded = true
                }
            }
            .accessibilityAddTraits(muted ? .isSelected : [])
            roundButton(Text(["0.8x", "1x", "1.25x"][speedIndex]).font(.system(size: 14, weight: .bold)), t("lazy.speed")) {
                speedIndex = (speedIndex + 1) % Self.speeds.count
            }
            roundButton(Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)), t("lazy.prev")) { move(-1) }
            Button { togglePlay() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Self.ink)
                    .frame(width: 64, height: 64)
                    .background(DS.gold, in: Circle())
                    .shadow(color: Color(red: 0.79, green: 0.60, blue: 0.12), radius: 0, y: 5)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(playing ? t("lazy.pause") : t("lazy.play"))
            roundButton(Image(systemName: "chevron.right").font(.system(size: 17, weight: .bold)), t("lazy.next")) { move(1) }
            roundButton(Text("TR").font(.system(size: 13, weight: .heavy)).foregroundColor(showTranslation ? Self.ink : Self.soft),
                        t("lazy.translation")) { showTranslation.toggle() }
                .accessibilityAddTraits(showTranslation ? .isSelected : [])
        }
        .padding(.vertical, 14)
    }

    private func roundButton<Face: View>(_ label: Face, _ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label.foregroundColor(Self.ink)
                .frame(width: 46, height: 46)
                .background(Self.sand, in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(name)
    }

    private var endCard: some View {
        VStack(spacing: 12) {
            Spacer()
            LinaAvatar(size: 120, mood: .happy)
            Text(t("lazy.done")).font(.system(size: 28, weight: .heavy)).foregroundColor(Self.ink)
            Text(t("lazy.doneSub", slidesSeen)).font(.body).foregroundColor(Self.soft)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text(t("match.finish")).font(.system(size: 16, weight: .bold)).foregroundColor(Self.ink)
                        .frame(maxWidth: .infinity, minHeight: 54).background(Self.sand, in: Capsule())
                }
                Button {
                    finished = false
                    watched = 0
                    showSlide()
                } label: {
                    Text(t("lazy.again")).font(.system(size: 16, weight: .heavy)).foregroundColor(Self.ink)
                        .frame(maxWidth: .infinity, minHeight: 54).background(DS.gold, in: Capsule())
                }
            }
            .buttonStyle(.pressable)
            .padding(.top, 10)
            Spacer()
        }
        .padding(24)
    }

    // MARK: Slides

    @ViewBuilder
    private func slideView(_ slide: LazySlide) -> some View {
        switch slide {
        case .noun(let word, let picture):
            VStack(spacing: 6) {
                kind(t("lazy.kind.word"))
                if let picture, let image = Covers.image(picture) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
                        .padding(.top, 6)
                }
                HStack(spacing: 10) {
                    Text(word.type).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(a1ArticleColor(word.type), in: Capsule())
                    Text(word.de).font(.system(size: 38, weight: .heavy)).foregroundColor(Self.ink).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.top, 10)
                if let plural = word.plural, !plural.isEmpty {
                    Text(t("lazy.plural", "die \(plural)")).font(.subheadline).foregroundColor(Self.soft)
                }
                if showTranslation {
                    Text(word.mean.text).font(.system(size: 22, weight: .semibold)).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21))
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

        case .examples(let word):
            VStack(spacing: 10) {
                kind(t("lazy.kind.examples"))
                HStack(spacing: 8) {
                    Text(word.type).font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(a1ArticleColor(word.type), in: Capsule())
                    Text(word.de).font(.system(size: 26, weight: .heavy)).foregroundColor(Self.ink)
                }
                ForEach(Array(word.ex.prefix(3).enumerated()), id: \.offset) { _, ex in
                    exampleBox(ex.de, ex.mean.text)
                }
            }
            .frame(maxWidth: .infinity)

        case .verbExamples(let verb):
            VStack(spacing: 10) {
                kind(t("lazy.kind.examples"))
                Text(verb.v).font(.system(size: 26, weight: .heavy)).foregroundColor(Self.ink)
                ForEach(Array(verb.examples.prefix(4).enumerated()), id: \.offset) { _, ex in
                    VStack(alignment: .leading, spacing: 4) {
                        if let tense = ex.t {
                            Text(tense.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1.2).foregroundColor(DS.goldDeep)
                        }
                        exampleBox(ex.de, ex.meaning)
                    }
                }
            }
            .frame(maxWidth: .infinity)

        case .verb(let verb):
            VStack(spacing: 10) {
                kind(t("lazy.kind.verb"))
                Text(verb.v).font(.system(size: 40, weight: .heavy)).foregroundColor(Self.ink)
                if showTranslation { Text(verb.meaning).font(.title3).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21)) }
                tenseBox("PRÄSENS", color: DS.der, fill: Color(red: 0.918, green: 0.941, blue: 1)) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), alignment: .leading, spacing: 4) {
                        ForEach(0..<min(6, verb.praesens.count), id: \.self) { i in
                            (Text(["ich", "du", "er", "wir", "ihr", "sie"][i] + " ") + Text(verb.praesens[i]).bold())
                                .font(.system(size: 14)).foregroundColor(Self.ink)
                        }
                    }
                }
                HStack(spacing: 8) {
                    tenseBox("PRÄTERITUM", color: Color(red: 0.71, green: 0.33, blue: 0.04), fill: Color(red: 1, green: 0.945, blue: 0.886)) {
                        Text("ich \(verb.praeteritum.first ?? "")").font(.system(size: 16, weight: .bold)).foregroundColor(Self.ink)
                    }
                    tenseBox("PERFEKT", color: DS.das, fill: Color(red: 0.898, green: 0.965, blue: 0.918)) {
                        Text(verb.perfekt).font(.system(size: 16, weight: .bold)).foregroundColor(Self.ink)
                    }
                }
                tenseBox("FUTUR", color: Color(red: 0.42, green: 0.25, blue: 0.77), fill: Color(red: 0.953, green: 0.918, blue: 0.996)) {
                    Text(verb.futur).font(.system(size: 16, weight: .bold)).foregroundColor(Self.ink)
                }
            }
            .frame(maxWidth: .infinity)

        case .article(let word, let picture):
            VStack(spacing: 10) {
                kind("DER, DIE ODER DAS?")
                if let picture, let image = Covers.image(picture) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(.top, 6)
                }
                HStack(spacing: 10) {
                    Text(revealed ? word.type : "___")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(revealed ? a1ArticleColor(word.type) : Color(red: 0.79, green: 0.76, blue: 0.67))
                        .scaleEffect(revealed && !reduceMotion ? 1.05 : 1)
                    Text(word.de).font(.system(size: 42, weight: .heavy)).foregroundColor(Self.ink).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.top, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: revealed)
                if showTranslation { Text(word.mean.text).font(.title3).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21)) }
                HStack(spacing: 8) {
                    ForEach(["der", "die", "das"], id: \.self) { art in
                        Text(art).font(.system(size: 17, weight: .heavy)).foregroundColor(a1ArticleColor(art))
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(a1ArticleColor(art).opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(a1ArticleColor(art), lineWidth: revealed && art == word.type ? 3 : 0))
                            .opacity(revealed && art != word.type ? 0.35 : 1)
                    }
                }
                .padding(.top, 14)
                Text(t("lazy.guess")).font(.subheadline).foregroundColor(Self.soft).multilineTextAlignment(.center).padding(.top, 10)
            }
            .frame(maxWidth: .infinity)

        case .meaning(let word, let picture):
            VStack(spacing: 10) {
                kind(t("lazy.kind.meaning"))
                if let picture, revealed, let image = Covers.image(picture) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(.top, 6)
                        .transition(.scale.combined(with: .opacity))
                }
                HStack(spacing: 10) {
                    Text(word.type).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(a1ArticleColor(word.type), in: Capsule())
                    Text(word.de).font(.system(size: 40, weight: .heavy)).foregroundColor(Self.ink).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.top, revealed ? 10 : 40)
                guessAnswer(word.mean.text)
                Text(t("lazy.guessMeaning")).font(.subheadline).foregroundColor(Self.soft).multilineTextAlignment(.center).padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75), value: revealed)

        case .plural(let word, let picture):
            VStack(spacing: 10) {
                kind(t("lazy.kind.plural"))
                if let picture, let image = Covers.image(picture) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.top, 6)
                }
                HStack(spacing: 10) {
                    Text(word.type).font(.system(size: 22, weight: .heavy)).foregroundColor(a1ArticleColor(word.type))
                    Text(word.de).font(.system(size: 30, weight: .heavy)).foregroundColor(Self.ink).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.top, 10)
                if showTranslation { Text(word.mean.text).font(.title3).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21)) }
                Image(systemName: "arrow.down").font(.system(size: 18, weight: .bold)).foregroundColor(Self.soft).padding(.vertical, 4)
                HStack(spacing: 10) {
                    Text("die").font(.system(size: 30, weight: .heavy)).foregroundColor(a1ArticleColor("die"))
                    Text(revealed ? (word.plural ?? "") : "_____")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(revealed ? Self.ink : Color(red: 0.79, green: 0.76, blue: 0.67))
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .scaleEffect(revealed && !reduceMotion ? 1.05 : 1)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: revealed)
                Text(t("lazy.guess")).font(.subheadline).foregroundColor(Self.soft).multilineTextAlignment(.center).padding(.top, 10)
            }
            .frame(maxWidth: .infinity)

        case .question(let sentence, let verb):
            VStack(alignment: .leading, spacing: 12) {
                kind(t("lazy.kind.question")).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 3) {
                    Text(sentence.de).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    if showTranslation { Text(sentence.meaning).font(.subheadline).foregroundColor(Color(red: 0.81, green: 0.78, blue: 0.71)) }
                }
                .padding(16)
                .background(Self.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 14)
                HStack(spacing: 8) {
                    Text(verb.v).font(.system(size: 16, weight: .bold)).foregroundColor(Self.ink)
                    if showTranslation { Text("= " + verb.meaning).font(.subheadline).foregroundColor(Self.soft) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Self.sand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let note = sentence.note, !note.isEmpty {
                    Label(note, systemImage: "lightbulb").font(.subheadline).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21))
                }
            }

        case .must(let sheet, let row):
            VStack(spacing: 8) {
                kind(t("lazy.kind.must"))
                Image(systemName: sheet.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(DS.goldDeep)
                    .frame(width: 74, height: 74)
                    .background(Color(red: 1, green: 0.94, blue: 0.70), in: Circle())
                    .padding(.top, 10)
                Text(sheet.title.text).font(.subheadline.weight(.semibold)).foregroundColor(Self.soft)
                Text(row.a).font(.system(size: 32, weight: .heavy)).foregroundColor(Self.ink).multilineTextAlignment(.center)
                if showTranslation { Text(row.q.text).font(.title3).foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21)).multilineTextAlignment(.center) }
                if let x = row.x, !x.isEmpty { exampleBox(x, showTranslation ? row.xm?.text : nil).padding(.top, 8) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The hidden answer of the meaning game: a dashed box with "?" that turns into the meaning.
    private func guessAnswer(_ answer: String) -> some View {
        ZStack {
            if revealed {
                Text(answer).font(.system(size: 26, weight: .heavy)).foregroundColor(Self.ink)
                    .multilineTextAlignment(.center)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("?").font(.system(size: 30, weight: .heavy)).foregroundColor(Color(red: 0.79, green: 0.76, blue: 0.67))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(.horizontal, 14)
        .background(revealed ? Color(red: 1, green: 0.94, blue: 0.70) : Self.sand, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color(red: 0.79, green: 0.76, blue: 0.67), style: StrokeStyle(lineWidth: revealed ? 0 : 2, dash: [7, 6])))
        .padding(.top, 14)
    }

    private func kind(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .heavy)).tracking(2).foregroundColor(DS.goldDeep).padding(.top, 4)
    }

    private func exampleBox(_ de: String, _ meaning: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(de).font(.system(size: 17, weight: .semibold)).foregroundColor(Self.ink)
            if showTranslation, let meaning, !meaning.isEmpty {
                Text(meaning).font(.subheadline).foregroundColor(Self.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(14)
        .background(Self.sand, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func tenseBox<Content: View>(_ title: String, color: Color, fill: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundColor(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Flow

    private var readingTime: Double { (slide?.readingSeconds ?? 8) / speed }

    private func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard deck.isEmpty else { return }
        deck = LazyDeck.make(config, content: model.content)
        index = 0
        showSlide()
    }

    private func showSlide() {
        guard let slide else {
            finished = true
            return
        }
        elapsed = 0
        revealed = false
        narrationEnded = false
        caption = ""
        if slide.readsAtReveal {
            caption = "…"
            return  // Lina reads it when the answer shows
        }
        narrate(slide.lines)
    }

    private func narrate(_ lines: [String]) {
        guard !lines.isEmpty else {
            narrationEnded = true
            return
        }
        caption = lines[0]
        if muted {
            narrationEnded = true
            return
        }
        let current = index
        // Only the recorded natural voice (no iPhone voice): lines without a recording are shown, not read.
        let recorded = lines.filter { WordAudio.shared.isRecorded(A1Line(s: -1, t: $0)) }
        guard !recorded.isEmpty else {
            narrationEnded = true
            return
        }
        A1Speaker.shared.play(recorded.map { A1Line(s: -1, t: $0) }, slow: speed < 1, deviceVoice: false) { line in
            guard current == index else { return }
            if let line, recorded.indices.contains(line) {
                caption = recorded[line]
            } else {
                narrationEnded = true
            }
        }
    }

    private func tick() {
        guard playing, !finished, slide != nil else { return }
        elapsed += 0.25
        watched += 0.25
        // Guessing slides (article, meaning, plural): the answer shows by itself after a pause.
        if slide!.isGuess, !revealed, elapsed >= readingTime * 0.45 {
            revealed = true
            if slide!.readsAtReveal { narrate(slide!.lines) }
        }
        let audioBusy = A1Speaker.shared.isSpeaking || WordAudio.shared.isPlaying
        // A reading cut off by something else, or a recording that does not download, never says it ended:
        // the slide stood still for good. Nothing sounding 3 s after the reading time is up: go on.
        let stalled = !narrationEnded && !audioBusy && elapsed >= readingTime + 3
        let doneSpeaking = (narrationEnded && !audioBusy) || stalled
        guard elapsed >= readingTime, doneSpeaking else { return }
        if config.minutes > 0 && watched >= Double(config.minutes) * 60 {
            end()
        } else {
            move(1)
        }
    }

    private func move(_ delta: Int) {
        A1Speaker.shared.stop()
        if delta > 0 { slidesSeen += 1 }
        var next = index + delta
        if next >= deck.count {
            deck = LazyDeck.make(config, content: model.content)  // endless or long sessions: a fresh mix
            next = 0
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { index = max(0, next) }
        showSlide()
    }

    private func togglePlay() {
        playing.toggle()
        if playing {
            // Not before the answer shows on article and plural questions (reading it would give it away).
            if !narrationEnded, let slide, !(slide.readsAtReveal && !revealed) { narrate(slide.lines) }
        } else {
            A1Speaker.shared.stop()
        }
    }

    private func end() {
        A1Speaker.shared.stop()
        BadgeStore.countGame()
        StreakStore.shared.record()
        StreakStore.shared.addXP(max(5, slidesSeen / 3))
        withAnimation { finished = true }
    }
}

/// Four little bars that move while Lina is reading.
private struct SoundBars: View {
    let active: Bool
    @State private var up = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule().fill(DS.gold)
                    .frame(width: 4, height: active ? (up ? [18, 10, 16, 8][index] : [8, 18, 9, 16][index]) : 6)
            }
        }
        .frame(height: 20)
        .animation(active ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .default, value: up)
        .onAppear { up = true }
        .accessibilityHidden(true)
    }
}

/// Shows the app dimmed behind a full-screen cover (iOS 16.4+); older systems get the plain dark background.
struct ClearCoverBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}
