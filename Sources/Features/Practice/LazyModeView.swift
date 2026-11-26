import SwiftUI

// MARK: - Tembel Mod (lazy mode)
// The learner only watches and listens: a slide show over the app, Lina reads every slide aloud and the next one
// comes when she has finished AND there was time to read everything on it (long slides stay longer).
// Design: https://claude.ai/artifact/6zFB7bGLPD61mYDWeeKBKs (owner's choice: name "Tembel Mod", the whole level).

enum LazyTopic: String, CaseIterable, Identifiable {
    case words, verbs, articles, questions, must

    var id: String { rawValue }
    var title: String { t("lazy.topic.\(rawValue)") }
}

/// What the learner chose in the setup sheet.
struct LazyConfig: Identifiable {
    let id = UUID()
    let level: String
    let topics: Set<LazyTopic>
    /// 0 = endless.
    let minutes: Int
}

enum LazySlide {
    case noun(A1Word, picture: String?)
    case examples(A1Word)
    case verb(VerbEntry)
    case verbExamples(VerbEntry)
    case article(A1Word, picture: String?)
    case question(VerbSentence, verb: VerbEntry)
    case must(MemorizeSheet, MemorizeRow)

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
        case .article(let word, _):
            chars = word.de.count + word.mean.text.count + 40
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
        if topics.contains(.words) || topics.contains(.articles) {
            for word in (content?.words ?? []).filter(\.isNoun).shuffled().prefix(120) {
                let picture = picture(for: word, level: level)
                var block: [LazySlide] = []
                if topics.contains(.articles) { block.append(.article(word, picture: picture)) }
                if topics.contains(.words) {
                    block.append(.noun(word, picture: picture))
                    if !word.ex.isEmpty { block.append(.examples(word)) }
                }
                nounBlocks.append(block)
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

/// The card on the level's practice page.
struct LazyModeCard: View {
    let level: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                LinaAvatar(size: 64, mood: .calm)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("lazy.badge")).font(.system(size: 11, weight: .heavy)).tracking(1.8).foregroundColor(DS.gold)
                    Text(t("lazy.title")).font(.system(size: 21, weight: .heavy)).foregroundColor(.white)
                    Text(t("lazy.cardSub", level)).font(.footnote).foregroundColor(Color(red: 0.81, green: 0.78, blue: 0.71))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.onGold)
                    .frame(width: 44, height: 44)
                    .background(DS.gold, in: Circle())
            }
            .padding(16)
            .background(LinearGradient(colors: [Color(red: 0.165, green: 0.149, blue: 0.078), Color(red: 0.055, green: 0.059, blue: 0.047)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(t("lazy.title"))
        .accessibilityHint(t("lazy.cardSub", level))
    }
}

struct LazySetupView: View {
    let level: String
    let start: (LazyConfig) -> Void
    @AppStorage("lazy.topics") private var topicsRaw = LazyTopic.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage("lazy.minutes") private var minutes = 10

    private var topics: Set<LazyTopic> { Set(topicsRaw.split(separator: ",").compactMap { LazyTopic(rawValue: String($0)) }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("lazy.setupTitle")).font(.system(size: 22, weight: .heavy))
                Text(t("lazy.setupSub")).font(.subheadline).foregroundColor(DS.muted)
                VStack(spacing: 8) {
                    ForEach(LazyTopic.allCases) { topic in
                        Toggle(topic.title, isOn: Binding(get: { topics.contains(topic) }, set: { on in
                            var set = topics
                            if on { set.insert(topic) } else { set.remove(topic) }
                            topicsRaw = LazyTopic.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
                        }))
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.top, 6)
                Text(t("lazy.duration")).font(.caption.weight(.heavy)).foregroundColor(DS.muted).padding(.top, 10)
                HStack(spacing: 6) {
                    ForEach([5, 10, 20, 0], id: \.self) { value in
                        Button { minutes = value } label: {
                            Text(value == 0 ? t("lazy.endless") : t("lazy.minutes", value))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(minutes == value ? DS.ground : DS.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(minutes == value ? DS.ink : DS.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(minutes == value ? .isSelected : [])
                    }
                }
                Button {
                    start(LazyConfig(level: level, topics: topics, minutes: minutes))
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
                .padding(.top, 14)
            }
            .padding(20)
        }
        .background(DS.ground.ignoresSafeArea())
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
                    Text(card?.focus ?? t("lazy.title")).font(.system(size: 17, weight: .heavy)).foregroundColor(Self.ink).lineLimit(1)
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
                if let x = row.x, !x.isEmpty { exampleBox(x, nil).padding(.top, 8) }
            }
            .frame(maxWidth: .infinity)
        }
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
        if case .article = slide {
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
        if case .article = slide!, !revealed, elapsed >= readingTime * 0.45 {
            revealed = true
            narrate(slide!.lines)
        }
        let doneSpeaking = narrationEnded && !A1Speaker.shared.isSpeaking
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
            if !narrationEnded, let slide { narrate(slide.lines) }
        } else {
            A1Speaker.shared.stop()
        }
    }

    private func end() {
        A1Speaker.shared.stop()
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
