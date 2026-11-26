import SwiftUI

// MARK: - Content (Resources/content/units.json, made by tools/units.py)

struct UnitPhrase: Decodable, Hashable {
    let de: String
    let tr: String
    let en: String
    /// Other learner languages (tools/translate.py adds them).
    var es: String?, fr: String?, it: String?, ku: String?, ar: String?
    var meaning: String { localText(tr: tr, en: en, es: es, fr: fr, it: it, ku: ku, ar: ar) }
}

/// A word of a unit that is not in the level's word list (A2+: taken from the glossaries of the unit's texts).
struct UnitWord: Decodable, Hashable {
    let de: String
    let art: String?
    let tr: String
    let en: String
    var es: String?, fr: String?, it: String?, ku: String?, ar: String?
    var meaning: String { localText(tr: tr, en: en, es: es, fr: fr, it: it, ku: ku, ar: ar) }
    var full: String { art.map { "\($0) \(de)" } ?? de }
}

struct LearningUnit: Decodable, Identifiable, Hashable {
    let id: String
    let level: String
    let number: Int
    let title: LocText
    let goal: LocText
    let cover: String
    let themes: [Int]
    let grammar: [Int]
    let texts: [String]
    let speaking: [String]
    let writing: [String]
    let phrases: [UnitPhrase]
    /// Word ids with a picture card (Resources/Covers/wp-<level>-<id>.jpg, made by tools/word_pictures.py).
    let pictures: [Int]?
    /// A1: more words of the unit (from its themes, shown as letter cards after the pictures; tools/units.py).
    let extra: [Int]?
    /// Words from the unit's texts, used instead of themes when present.
    let vocab: [UnitWord]?

    /// The unit's own picture, else the cover of its first text.
    var image: UIImage? { Covers.image(cover) ?? texts.lazy.compactMap { Covers.image($0) }.first }
}

private struct UnitFile: Decodable {
    let units: [LearningUnit]
}

enum UnitBank {
    private static let all = Bundled.decode(UnitFile.self, "units")?.units ?? []

    static func units(_ level: String) -> [LearningUnit] { all.filter { $0.level == level }.sorted { $0.number < $1.number } }
    static func unit(_ id: String) -> LearningUnit? { all.first { $0.id == id } }
    static var levels: [String] { LevelModels.practiceLevels.filter { !units($0).isEmpty } }
}

/// The six steps of every unit.
enum UnitStep: String, CaseIterable, Identifiable {
    case words, phrases, grammar, text, speak, test

    var id: String { rawValue }
    var title: String { t("unit.step.\(rawValue)") }
    var icon: String {
        switch self {
        case .words: return "textformat.abc"
        case .phrases: return "quote.bubble.fill"
        case .grammar: return "books.vertical.fill"
        case .text: return "doc.richtext.fill"
        case .speak: return "mic.fill"
        case .test: return "rosette"
        }
    }
}

/// Which steps of which unit are done. The test counts only with 80 % or more; that opens the next unit.
enum UnitStore {
    static let changed = Notification.Name("UnitStoreChanged")
    static let passMark = 80

    private static func key(_ unit: String) -> String { "unit.\(unit)" }

    static func done(_ unit: String) -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key(unit)) ?? []) }

    static func mark(_ step: UnitStep, _ unit: String) {
        var steps = done(unit)
        guard !steps.contains(step.rawValue) else { return }
        steps.insert(step.rawValue)
        UserDefaults.standard.set(Array(steps), forKey: key(unit))
        StreakStore.shared.record()
        if step == .test { StreakStore.shared.addXP(XP.perfectBonus * 2) }
        NotificationCenter.default.post(name: changed, object: nil)
    }

    static func passed(_ unit: String) -> Bool { done(unit).contains(UnitStep.test.rawValue) }

    static func unlocked(_ unit: LearningUnit) -> Bool {
        let list = UnitBank.units(unit.level)
        guard let index = list.firstIndex(of: unit), index > 0 else { return true }
        return passed(list[index - 1].id)
    }

    /// The first unit not passed yet (the last one when everything is passed).
    static func current(_ level: String) -> LearningUnit? {
        let list = UnitBank.units(level)
        return list.first { !passed($0.id) } ?? list.last
    }

    static func nextStep(_ unit: String) -> UnitStep? {
        let steps = done(unit)
        return UnitStep.allCases.first { !steps.contains($0.rawValue) }
    }
}

// MARK: - Questions made from a unit
// Words (stages, UnitDrillWord) and grammar (rule first, known words): PathLearning.swift.

extension A1Model {
    /// Meaning of each phrase, and two phrases to put in order.
    func unitPhraseSession(_ unit: LearningUnit) -> [A1Question] {
        let label = unit.title.text
        var out: [A1Question] = unit.phrases.enumerated().map { index, phrase in
            let wrong = unit.phrases.filter { $0 != phrase }.map(\.meaning).shuffled().prefix(3)
            return A1Question(id: "up-\(unit.id)-\(index)", mode: .sentence, kind: .choice, label: label, prompt: phrase.de,
                              detail: t("verb.meaningOf"), speakFirst: phrase.de, options: ([phrase.meaning] + wrong).shuffled(),
                              answer: phrase.meaning, explanation: "\(phrase.de) = \(phrase.meaning)")
        }
        for (index, phrase) in unit.phrases.enumerated().shuffled().prefix(2) {
            let tokens = phrase.de.split(separator: " ").map(String.init)
            guard tokens.count >= 3 else { continue }
            var shuffled = tokens.shuffled()
            var tries = 0
            while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
            out.append(A1Question(id: "upo-\(unit.id)-\(index)", mode: .order, kind: .order, label: label, prompt: phrase.meaning,
                                  detail: t("q.orderWords"), speakAfter: phrase.de, options: shuffled,
                                  answer: tokens.joined(separator: " ")))
        }
        return out.shuffled()
    }

    /// The unit test: words, grammar and phrases together.
    func unitTestSession(_ unit: LearningUnit) -> [A1Question] {
        (unitWordSession(unit, count: 6) + unitGrammarSession(unit, count: 6) + Array(unitPhraseSession(unit).prefix(3))).shuffled()
    }
}

// MARK: - Picture

struct UnitPicture: View {
    let unit: LearningUnit
    /// nil: the whole picture at its own shape (3:2). A height crops it from the top, so faces stay in view.
    var height: CGFloat? = nil
    var dimmed = false

    var body: some View {
        frame
            .overlay(alignment: .top) { picture }
            .clipped()
            .grayscale(dimmed ? 1 : 0)
            .opacity(dimmed ? 0.55 : 1)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var frame: some View {
        if let height {
            Color.clear.frame(maxWidth: .infinity).frame(height: height)
        } else {
            Color.clear.frame(maxWidth: .infinity).aspectRatio(3 / 2, contentMode: .fit)
        }
    }

    @ViewBuilder
    private var picture: some View {
        if let image = unit.image {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [DS.gold.opacity(0.6), DS.gold.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Path tab

struct PathView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel
    @State private var level = "A1"
    @State private var levelChosen = false
    @State private var refresh = 0

    private enum Row: Identifiable {
        case wide(LearningUnit)
        case pair(LearningUnit, LearningUnit?)
        var id: String {
            switch self {
            case .wide(let u): return u.id
            case .pair(let a, _): return "p-" + a.id
            }
        }
    }

    var body: some View {
        let units = UnitBank.units(level)
        let current = UnitStore.current(level)
        let passedCount = units.filter { UnitStore.passed($0.id) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t("path.progress", level, passedCount, units.count)).font(.subheadline).foregroundColor(DS.muted)
                    Spacer()
                    ForEach(LevelModels.practiceLevels, id: \.self) { code in
                        Button { level = code } label: {
                            Text(code)
                                .font(DS.text(13, .bold))
                                .foregroundColor(level == code ? DS.ground : DS.ink)
                                .frame(minWidth: 44, minHeight: 32)
                                .background(level == code ? DS.ink : DS.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Unit 0 for complete beginners: alphabet, sounds, numbers, greetings.
                if level == "A1" && StarterContent.shared != nil {
                    NavigationLink {
                        StarterView().environmentObject(levels.a1)
                    } label: {
                        StarterCard()
                    }
                    .buttonStyle(.pressable)
                }
                if units.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("path.soon", level)).font(.headline)
                        Text(t("path.soonSub")).font(.subheadline).foregroundColor(DS.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                ForEach(rows(units, current: current)) { row in
                    switch row {
                    case .wide(let unit):
                        NavigationLink(value: AppRoute.unit(unit.id)) { currentCard(unit) }.buttonStyle(.pressable)
                    case .pair(let a, let b):
                        HStack(spacing: 10) {
                            tile(a)
                            if let b { tile(b) } else { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                }
                if !units.isEmpty {
                    reviewCards(units)
                    NavigationLink(value: AppRoute.examHome) {
                        HStack(spacing: 12) {
                            Image(systemName: "rosette").font(.system(size: 17, weight: .bold)).foregroundColor(DS.goldDeep)
                                .frame(width: 38, height: 38).background(DS.gold.opacity(0.18), in: Circle())
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t("path.examAfter")).font(.caption).foregroundColor(DS.muted)
                                Text(t("path.exam", level)).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
            .id(refresh)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("tab.path"))
        .onAppear {
            // Only the first time: coming back from a unit keeps the level the learner picked here.
            guard !levelChosen else { return }
            levelChosen = true
            if UnitBank.levels.contains(daily.level) { level = daily.level }
        }
        .onReceive(NotificationCenter.default.publisher(for: UnitStore.changed)) { _ in refresh += 1 }
    }

    private func rows(_ units: [LearningUnit], current: LearningUnit?) -> [Row] {
        var out: [Row] = []
        var pending: LearningUnit?
        for unit in units {
            if unit == current {
                if let p = pending { out.append(.pair(p, nil)); pending = nil }
                out.append(.wide(unit))
            } else if let p = pending {
                out.append(.pair(p, unit))
                pending = nil
            } else {
                pending = unit
            }
        }
        if let p = pending { out.append(.pair(p, nil)) }
        return out
    }

    private func currentCard(_ unit: LearningUnit) -> some View {
        let done = UnitStore.done(unit.id).count
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                UnitPicture(unit: unit, height: 160)
                Text(t("path.now", done, UnitStep.allCases.count))
                    .font(.caption.weight(.heavy))
                    .foregroundColor(DS.onGold)
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(DS.gold, in: Capsule())
                    .padding(12)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("path.unit", unit.number)).font(.caption.weight(.bold)).foregroundColor(DS.gold)
                    Text(unit.title.text).font(.system(size: 19, weight: .bold)).foregroundColor(DS.onNight)
                    Text(unit.goal.text).font(.caption).foregroundColor(DS.onNightMuted).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.onGold)
                    .frame(width: 44, height: 44)
                    .background(DS.gold, in: Circle())
            }
            .padding(14)
        }
        .background(DS.night, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// A review after every four units, open once one unit of the block is passed.
    @ViewBuilder
    private func reviewCards(_ units: [LearningUnit]) -> some View {
        let blocks = stride(from: 0, to: units.count, by: 4).map { Array(units[$0..<min($0 + 4, units.count)]) }
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            if block.contains(where: { UnitStore.passed($0.id) }), let first = block.first, let last = block.last {
                NavigationLink {
                    A1QuizView(title: t("path.review", first.number, last.number)) {
                        levels.model(level).blockReviewSession(block)
                    }
                    .environmentObject(levels.model(level))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t("path.review", first.number, last.number)).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                            Text(t("path.reviewSub")).font(.caption).foregroundColor(DS.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    @ViewBuilder
    private func tile(_ unit: LearningUnit) -> some View {
        let passed = UnitStore.passed(unit.id)
        let open = UnitStore.unlocked(unit)
        let content = VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                UnitPicture(unit: unit, height: 90, dimmed: !open)
                if passed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                        .frame(width: 26, height: 26).background(DS.success, in: Circle()).padding(8)
                } else if !open {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(DS.ink)
                        .frame(width: 32, height: 32).background(DS.surface, in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: 90)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(t("path.unit", unit.number)).font(.caption2).foregroundColor(DS.muted)
                Text(unit.title.text).font(.system(size: 14, weight: .bold)).foregroundColor(open ? DS.ink : DS.muted).lineLimit(1)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        if open {
            NavigationLink(value: AppRoute.unit(unit.id)) { content }.buttonStyle(.pressable)
        } else {
            content.accessibilityHint(t("path.lockedHint"))
        }
    }
}

// MARK: - One unit

struct UnitView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    let unit: LearningUnit
    @State private var done: Set<String> = []
    @State private var lastTest: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                UnitPicture(unit: unit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("path.unitOf", unit.level, unit.number).uppercased()).font(.caption.weight(.bold)).foregroundColor(DS.goldDeep)
                    Text(unit.title.text).font(DS.display(28)).foregroundColor(DS.ink)
                    Text(t("path.goal", unit.goal.text)).font(.subheadline).foregroundColor(DS.muted)
                }
                VStack(spacing: 0) {
                    ForEach(Array(UnitStep.allCases.enumerated()), id: \.element) { index, step in
                        if index > 0 { Divider().padding(.leading, 60) }
                        stepRow(step, number: index + 1)
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let lastTest, lastTest < UnitStore.passMark, !done.contains(UnitStep.test.rawValue) {
                    Text(t("unit.testAgain", lastTest, UnitStore.passMark)).font(.footnote).foregroundColor(DS.error)
                }
                if !unit.writing.isEmpty {
                    Text(t("unit.extra")).font(.headline).padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(unit.writing.compactMap { WritingBank.task($0) }) { task in
                            NavigationLink(value: AppRoute.writingTask(task.id)) {
                                ModuleRow(icon: "square.and.pencil", color: DS.das, title: task.title.text, subtitle: nil, value: nil)
                            }
                        }
                    }
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(unit.title.text)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { done = UnitStore.done(unit.id) }
        .onReceive(NotificationCenter.default.publisher(for: UnitStore.changed)) { _ in done = UnitStore.done(unit.id) }
    }

    private var nextStep: UnitStep? { UnitStep.allCases.first { !done.contains($0.rawValue) } }

    private func subtitle(_ step: UnitStep) -> String {
        switch step {
        case .words:
            if let vocab = unit.vocab, !vocab.isEmpty { return vocab.prefix(3).map(\.full).joined(separator: " · ") }
            let names = unit.themes.compactMap { id in model.content?.themes.first { $0.id == id }?.name.text }
            return names.joined(separator: " · ")
        case .phrases: return unit.phrases.first.map { "„\($0.de)“" } ?? ""
        case .grammar:
            return unit.grammar.compactMap { id in model.content?.grammar.first { $0.id == id }?.de }.joined(separator: " · ")
        case .text: return readingText?.title ?? ""
        case .speak: return unit.speaking.first.flatMap { SpeakingBank.task($0)?.title.text } ?? ""
        case .test: return t("unit.testSub", UnitStore.passMark)
        }
    }

    /// The first text of the unit the learner has not finished.
    private var readingText: DailyText? {
        let texts = unit.texts.compactMap { daily.text(id: $0) }
        return texts.first { !daily.isCompleted($0) } ?? texts.first
    }

    private func stepRow(_ step: UnitStep, number: Int) -> some View {
        let finished = done.contains(step.rawValue)
        let isNext = step == nextStep
        return NavigationLink {
            destination(step)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(finished ? DS.success : (isNext ? DS.gold : DS.chip))
                    if finished {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                    } else {
                        Image(systemName: step.icon).font(.system(size: 14, weight: .bold)).foregroundColor(isNext ? DS.onGold : DS.muted)
                    }
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(number) · \(step.title)").font(.system(size: 15, weight: isNext ? .bold : .semibold)).foregroundColor(DS.ink)
                    Text(subtitle(step)).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                if isNext {
                    Text(t("unit.now")).font(.caption.weight(.bold)).foregroundColor(DS.goldDeep)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isNext ? DS.gold.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(_ step: UnitStep) -> some View {
        switch step {
        case .words:
            UnitWordsView(unit: unit)
        case .phrases:
            UnitPhrasesView(unit: unit)
        case .grammar:
            UnitGrammarIntroView(unit: unit)
        case .text:
            if !StoryBank.stories(unit.id).isEmpty {
                UnitStoriesView(unit: unit, stories: StoryBank.stories(unit.id), dailyText: readingText)
            } else if let text = readingText {
                DailyReadingView(text: text).onAppear { UnitStore.mark(.text, unit.id) }
            }
        case .speak:
            if let task = unit.speaking.compactMap({ SpeakingBank.task($0) }).first {
                SpeakTaskView(task: task) { covered, _ in
                    if covered > 0 { UnitStore.mark(.speak, unit.id) }  // silence does not finish the step
                }
            }
        case .test:
            A1QuizView(title: t("unit.step.test"), onFinish: { correct, total in
                let percent = total == 0 ? 0 : correct * 100 / total
                lastTest = percent
                if percent >= UnitStore.passMark { UnitStore.mark(.test, unit.id) }
            }) {
                model.unitTestSession(unit)
            }
        }
    }
}

/// Step 1: the unit's words as picture cards (tap to hear), then a practice round.
struct UnitWordsView: View {
    @EnvironmentObject private var model: A1Model
    let unit: LearningUnit
    /// Redraws the stage dots when a practice round changed them.
    @State private var masteryTick = 0

    private struct Card: Identifiable {
        let id: String
        let article: String?
        let de: String
        let meaning: String
        let picture: String?
        var full: String { article.map { "\($0) \(de)" } ?? de }
    }

    private var cards: [Card] {
        if let vocab = unit.vocab, !vocab.isEmpty {
            return vocab.enumerated().map { index, word in
                Card(id: "v\(index)", article: word.art, de: word.de, meaning: word.meaning, picture: nil)
            }
        }
        let all = model.content?.words ?? []
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var picked = (unit.pictures ?? []).compactMap { byID[$0] }
        if picked.isEmpty { picked = Array(all.filter { unit.themes.contains($0.theme) && $0.isNoun }.prefix(16)) }
        picked += (unit.extra ?? []).compactMap { byID[$0] }  // no picture: shown as a letter card
        return picked.map { word in
            Card(id: "w\(word.id)", article: word.isNoun ? word.type : nil, de: word.de, meaning: word.mean.text,
                 picture: "wp-\(unit.level.lowercased())-\(word.id)")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("unit.wordsIntro")).font(.subheadline).foregroundColor(DS.muted)
                masteryHeader
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                          spacing: 12) {
                    ForEach(cards) { word in card(word) }
                }
                NavigationLink {
                    A1QuizView(title: t("unit.step.words"), onFinish: { _, _ in
                        // Done when most words reached the "written" stage, not after one round.
                        if WordMastery.unitDone(unit.level, model.unitDrillWords(unit)) { UnitStore.mark(.words, unit.id) }
                    }) {
                        model.unitWordSession(unit)
                    }
                } label: {
                    Text(t("unit.practiseWords"))
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
        .navigationTitle(t("unit.step.words"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: WordMastery.changed)) { _ in masteryTick += 1 }
    }

    /// "12 / 28 words learned" with a bar, and how the steps work.
    private var masteryHeader: some View {
        let words = model.unitDrillWords(unit)
        let progress = WordMastery.progress(unit.level, words)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("unit.mastery", progress.learned, progress.total)).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                Spacer()
                Text("\(progress.total == 0 ? 0 : progress.learned * 100 / progress.total)%")
                    .font(.footnote.monospacedDigit().weight(.semibold)).foregroundColor(DS.muted)
            }
            ProgressView(value: Double(progress.learned), total: Double(max(1, progress.total))).tint(DS.success)
            Text(t("unit.masteryNote")).font(.footnote).foregroundColor(DS.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .id(masteryTick)
    }

    /// Four dots: recognised, recalled, written, used in a sentence.
    private func stageDots(_ stage: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { step in
                Circle().fill(step <= stage ? (stage >= 4 ? DS.success : DS.gold) : DS.hairline).frame(width: 6, height: 6)
            }
        }
        .id(masteryTick)
        .accessibilityLabel("\(stage)/4")
    }

    private func card(_ word: Card) -> some View {
        let color = word.article.map { a1ArticleColor($0) } ?? DS.muted
        return Button {
            A1Speaker.shared.say(word.full)
        } label: {
            VStack(spacing: 6) {
                // Word pictures are square: show them whole in a square box.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let name = word.picture, let image = Covers.image(name) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            ZStack {
                                color.opacity(0.12)
                                Text(String(word.de.prefix(1))).font(.system(size: 34, weight: .heavy)).foregroundColor(color.opacity(0.7))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                (word.article.map { Text($0 + " ").foregroundColor(color) + Text(word.de).foregroundColor(DS.ink) } ?? Text(word.de).foregroundColor(DS.ink))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(word.meaning).font(.caption2).foregroundColor(DS.muted).lineLimit(1)
                stageDots(WordMastery.stage(unit.level, word.full))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(word.full), \(word.meaning)")
    }
}

/// Step 2: the unit's key phrases, to hear and then to practise.
struct UnitPhrasesView: View {
    @EnvironmentObject private var model: A1Model
    let unit: LearningUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("unit.phrasesIntro")).font(.subheadline).foregroundColor(DS.muted)
                ForEach(unit.phrases, id: \.self) { phrase in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phrase.de).font(DS.text(18, .semibold)).foregroundColor(DS.ink)
                            Text(phrase.meaning).font(DS.text(14)).foregroundColor(DS.muted)
                        }
                        Spacer(minLength: 0)
                        A1SpeakButton(text: phrase.de)
                        A1SpeakButton(text: phrase.de, slow: true)
                    }
                    .padding(14)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                NavigationLink {
                    A1QuizView(title: t("unit.step.phrases"), onFinish: { _, _ in UnitStore.mark(.phrases, unit.id) }) {
                        model.unitPhraseSession(unit)
                    }
                } label: {
                    Text(t("unit.practisePhrases"))
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
        .navigationTitle(t("unit.step.phrases"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Today: continue the path

struct PathContinueCard: View {
    @EnvironmentObject private var daily: DailyModel
    @State private var refresh = 0

    var body: some View {
        let level = UnitBank.levels.contains(daily.level) ? daily.level : (UnitBank.levels.first ?? "A1")
        if let unit = UnitStore.current(level) {
            let done = UnitStore.done(unit.id)
            let next = UnitStore.nextStep(unit.id)
            NavigationLink(value: AppRoute.unit(unit.id)) {
                VStack(alignment: .leading, spacing: 12) {
                    UnitPicture(unit: unit, height: 120)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("path.continue").uppercased()).font(.caption.weight(.bold)).foregroundColor(DS.onNightMuted)
                        Text("\(unit.level) · " + t("path.unit", unit.number)).font(.footnote.weight(.bold)).foregroundColor(DS.gold)
                        Text(unit.title.text).font(.system(size: 22, weight: .heavy)).foregroundColor(DS.onNight)
                        if let next {
                            Text(t("path.nextStep", next.title)).font(.footnote).foregroundColor(DS.onNightMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    // The six steps: done = green tick, next = gold ring, the rest faint.
                    HStack(spacing: 0) {
                        ForEach(UnitStep.allCases) { step in
                            stepDot(step, done: done.contains(step.rawValue), next: next == step)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
                .background(DS.night, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.pressable)
            .id(refresh)
            .onReceive(NotificationCenter.default.publisher(for: UnitStore.changed)) { _ in refresh += 1 }
        }
    }

    private func stepDot(_ step: UnitStep, done: Bool, next: Bool) -> some View {
        ZStack {
            Circle().fill(done ? DS.success : Color.white.opacity(next ? 0.16 : 0.08))
            if next { Circle().stroke(DS.gold, lineWidth: 2) }
            Image(systemName: done ? "checkmark" : step.icon)
                .font(.system(size: done ? 13 : 11, weight: .heavy))
                .foregroundColor(done ? .white : (next ? DS.gold : Color.white.opacity(0.4)))
        }
        .frame(width: 30, height: 30)
        .accessibilityElement()
        .accessibilityLabel(step.title + (done ? ", ✓" : ""))
    }
}
