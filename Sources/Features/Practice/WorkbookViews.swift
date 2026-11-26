import SwiftUI

// MARK: - Workbook

struct A1ThemesView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        List(model.content?.themes ?? []) { theme in
            NavigationLink(value: A1Route.theme(theme.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d  ", theme.id + 1) + theme.de)
                    Text("\(theme.name.text) · " + t("common.words", model.content?.words.filter { $0.theme == theme.id }.count ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(t("practice.themes"))
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
                    Label(t("workbook.themeQuiz"), systemImage: "play.circle.fill")
                }
                NavigationLink(value: A1Route.match(themeID)) {
                    Label(t("workbook.themeMatch"), systemImage: "square.grid.2x2")
                }
            }
            Section(t("workbook.words")) {
                ForEach(words) { word in
                    DisclosureGroup {
                        ForEach(Array(word.ex.enumerated()), id: \.offset) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.element.de)
                                    if a1ShowsPron() {
                                        Text("[\(item.element.pron)]").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(item.element.mean.text).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                A1SpeakButton(text: item.element.de)
                            }
                        }
                        if let er = word.er {
                            Text("\(er) · \(word.perfekt ?? "")").font(.caption)
                        }
                        if let pl = word.plural {
                            Text(t("word.plural", pl)).font(.caption)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.withArticle).font(.body.weight(.semibold)).foregroundStyle(a1ArticleColor(word.type))
                                Text(a1PronLead(word.pron) + word.mean.text).font(.caption).foregroundStyle(.secondary)
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
    @State private var filter = Filter.all

    enum Filter: CaseIterable { case all, open, mistakes }

    private var topics: [A1GrammarTopic] {
        let all = model.content?.grammar ?? []
        switch filter {
        case .all: return all
        case .open: return all.filter { model.topicStatus($0.id) == .open }
        case .mistakes: return all.filter { model.topicStatus($0.id) == .mistakes }
        }
    }

    var body: some View {
        let all = model.content?.grammar ?? []
        let done = all.filter { model.topicStatus($0.id) == .done }.count
        let withMistakes = all.filter { model.topicStatus($0.id) == .mistakes }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(withMistakes > 0 ? t("grammar.summaryMistakes", done, withMistakes) : t("grammar.summary", done, all.count))
                    .font(.subheadline).foregroundColor(DS.muted)
                MistakeGroupRow(model: model, group: .grammar)
                HStack(spacing: 8) {
                    chip(.all, t("grammar.filterAll"))
                    chip(.open, t("grammar.filterOpen"))
                    chip(.mistakes, t("grammar.filterMistakes", withMistakes))
                }
                .padding(.bottom, 4)
                ForEach(topics) { topic in
                    NavigationLink(value: A1Route.grammar(topic.id)) { topicCard(topic) }
                        .buttonStyle(.pressable)
                }
                if topics.isEmpty {
                    Text(t("grammar.filterEmpty")).font(.subheadline).foregroundColor(DS.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("workbook.grammarTitle"))
    }

    private func chip(_ value: Filter, _ title: String) -> some View {
        let on = filter == value
        let warn = value == .mistakes
        return Button {
            filter = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(on ? (warn ? DS.onGold : Color(UIColor.systemBackground)) : DS.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(on ? (warn ? DS.gold : DS.ink) : DS.surface, in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func topicCard(_ topic: A1GrammarTopic) -> some View {
        let p = model.topicProgress(topic.id)
        let status = model.topicStatus(topic.id)
        let seen = min(p.seen, p.total)
        let progress = status == .done ? 1 : (p.total == 0 ? 0 : Double(seen) / Double(min(p.total, 30)))
        let color = TopicBadge.color(status)
        return HStack(spacing: 14) {
            TopicBadge(status: status, number: topic.id, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(topic.de).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink).lineLimit(2)
                    Spacer(minLength: 6)
                    Text(status == .done ? t("grammar.done") : (p.wrong > 0 ? t("grammar.mistakesShort", p.wrong) : (seen == 0 ? t("grammar.new") : "\(seen)/\(min(p.total, 30))")))
                        .font(.footnote.weight(.bold))
                        .foregroundColor(status == .done ? DS.success : (p.wrong > 0 ? DS.goldDeep : DS.muted))
                }
                Text(topic.name.text).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                ProgressView(value: min(1, progress)).tint(status == .open ? DS.accent : color)
                if p.wrong > 0 {
                    Text(t("grammar.fixHint")).font(.caption2).foregroundColor(DS.muted)
                }
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if status == .mistakes {
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.gold, lineWidth: 2)
            }
        }
    }
}

/// Grammar topic badge: green = finished without open mistakes, yellow = open mistakes, grey = not finished.
struct TopicBadge: View {
    let status: TopicStatus
    let number: Int
    var size: CGFloat = 30

    static func color(_ status: TopicStatus) -> Color {
        switch status {
        case .done: return DS.success
        case .mistakes: return Color(red: 0.95, green: 0.70, blue: 0.10)
        case .open: return Color(UIColor.systemGray3)
        }
    }

    private var icon: String? {
        switch status {
        case .done: return "checkmark"
        case .mistakes: return "exclamationmark"
        case .open: return nil
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(TopicBadge.color(status))
            if let icon {
                Image(systemName: icon).font(.system(size: size * 0.43, weight: .bold)).foregroundColor(.white)
            } else {
                Text("\(number)").font(.system(size: size * 0.4, weight: .semibold)).foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(status == .done ? t("grammar.legendDone") : (status == .mistakes ? t("grammar.legendMistakes") : t("grammar.legendOpen")))
    }
}

struct A1GrammarView: View {
    @EnvironmentObject private var model: A1Model
    let topicID: Int

    var body: some View {
        if let topic = model.content?.grammar.first(where: { $0.id == topicID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GrammarRuleCard(topic: topic)
                    NavigationLink(value: A1Route.grammarQuiz(topicID)) {
                        Label(t("workbook.topicQuiz", model.topicProgress(topicID).total), systemImage: "play.fill")
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
            .navigationTitle(topic.de)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Look of the short practice texts (a1.json "texts"): an icon and a colour per text, and which ones were listened to.
enum PracticeTextStyle {
    private static let palette: [Color] = [DS.der, DS.das, DS.die, DS.goldDeep, .indigo, .teal, .orange, .pink]
    private static let icons: [String: String] = [
        "vorstellen": "person.crop.circle", "familie": "figure.2.and.child.holdinghands", "tag": "sun.max",
        "wohnung": "house", "frühstück": "cup.and.saucer", "supermarkt": "cart", "wochenende": "calendar",
        "wetter": "cloud.sun", "arzt": "cross.case", "beruf": "briefcase", "stadt": "building.2",
        "meer": "beach.umbrella", "geburtstag": "gift", "hobbys": "paintpalette", "restaurant": "fork.knife",
        "hotel": "bed.double", "haustier": "pawprint", "deutschkurs": "book", "zug": "tram", "nachbar": "person.2",
    ]

    static func color(_ index: Int) -> Color { palette[abs(index) % palette.count] }

    static func icon(_ title: String) -> String {
        let lower = title.lowercased()
        return icons.first { lower.contains($0.key) }?.value ?? "doc.text"
    }

    private static let listenedKey = "practiceTexts.listened"

    static func listened(_ level: String, _ id: Int) -> Bool {
        (UserDefaults.standard.stringArray(forKey: listenedKey) ?? []).contains("\(level)-\(id)")
    }

    static func markListened(_ level: String, _ id: Int) {
        var all = UserDefaults.standard.stringArray(forKey: listenedKey) ?? []
        guard !all.contains("\(level)-\(id)") else { return }
        all.append("\(level)-\(id)")
        UserDefaults.standard.set(all, forKey: listenedKey)
    }
}

struct A1TextsView: View {
    @EnvironmentObject private var model: A1Model
    @State private var refresh = 0  // listened marks are read again when the list comes back

    var body: some View {
        let texts = model.content?.texts ?? []
        let done = texts.filter { PracticeTextStyle.listened(model.level, $0.id) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("workbook.textsIntro")).font(.subheadline).foregroundColor(DS.muted)
                    HStack(spacing: 10) {
                        ProgressView(value: texts.isEmpty ? 0 : Double(done) / Double(texts.count)).tint(DS.gold)
                        Text("\(done)/\(texts.count)").font(.caption.monospacedDigit().weight(.semibold)).foregroundColor(DS.ink)
                    }
                }
                .padding(.bottom, 4)
                ForEach(Array(texts.enumerated()), id: \.element.id) { index, text in
                    NavigationLink(value: A1Route.text(text.id)) { card(text, index: index) }
                        .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
            .id(refresh)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("workbook.textsTitle"))
        .onAppear { refresh += 1 }
    }

    private func card(_ text: A1Text, index: Int) -> some View {
        let color = PracticeTextStyle.color(index)
        let listened = PracticeTextStyle.listened(model.level, text.id)
        return HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: PracticeTextStyle.icon(text.title))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                if listened {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white, DS.success)
                        .offset(x: 6, y: 6)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(t("workbook.textNumber", index + 1).uppercased())
                    .font(.caption2.weight(.bold)).foregroundColor(color)
                Text(text.title).font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink).lineLimit(1)
                Text(text.titleL.text).font(.caption).foregroundColor(DS.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("workbook.sentences", text.de.count)).font(.caption2.weight(.semibold)).foregroundColor(DS.muted)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted.opacity(0.6))
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(listened ? 0.35 : 0.12), lineWidth: 1))
    }
}

/// One short practice text: a header, a player that reads sentence by sentence with the recorded voice
/// (the sentence being read is highlighted), every sentence on its own card to tap and hear, the translation
/// and the reading quiz. Leaving the page stops the voice.
struct A1TextView: View {
    @EnvironmentObject private var model: A1Model
    let textID: Int
    @State private var showTranslation = false
    @State private var playing = false
    @State private var slow = false
    @State private var current: Int?
    @State private var ended = false       // the player said "no more lines" (or the iPhone voice took over)
    @State private var endedAt = Date()
    private let clock = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        let texts = model.content?.texts ?? []
        if let index = texts.firstIndex(where: { $0.id == textID }) {
            let text = texts[index]
            let color = PracticeTextStyle.color(index)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(text, index: index, color: color)
                    player(text, color: color)
                    VStack(spacing: 8) {
                        ForEach(Array(text.de.enumerated()), id: \.offset) { line, sentence in
                            sentenceCard(sentence, number: line + 1, active: current == line, color: color)
                        }
                    }
                    translation(text)
                    NavigationLink(value: A1Route.mode(.reading)) {
                        Label(t("workbook.readingQuiz"), systemImage: "checkmark.bubble.fill")
                            .font(DS.text(16, .semibold))
                            .foregroundColor(DS.onGold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DS.gold, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 4)
                }
                .padding(.horizontal, DS.gutter)
                .padding(.bottom, 28)
            }
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(text.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stop() }
            .onReceive(clock) { _ in
                // Finished: the recorded lines are over, or the iPhone voice stopped speaking.
                if playing, ended, Date().timeIntervalSince(endedAt) > 1.0, !A1Speaker.shared.isSpeaking {
                    playing = false
                    current = nil
                    PracticeTextStyle.markListened(model.level, textID)
                }
            }
        }
    }

    private func header(_ text: A1Text, index: Int, color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(model.level) · " + t("workbook.textNumber", index + 1))
                    .font(.caption.weight(.bold)).foregroundColor(.white.opacity(0.75))
                Text(text.title).font(DS.display(28)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                Text(text.titleL.text).font(.subheadline).foregroundColor(.white.opacity(0.85))
                Text(t("workbook.sentences", text.de.count)).font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Image(systemName: PracticeTextStyle.icon(text.title))
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 4)
    }

    private func player(_ text: A1Text, color: Color) -> some View {
        HStack(spacing: 12) {
            Button { playing ? stop() : playAll(text) } label: {
                Image(systemName: playing ? "stop.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DS.ground)
                    .frame(width: 52, height: 52)
                    .background(DS.ink, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(playing ? t("reading.stop") : t("workbook.listenAll"))
            VStack(alignment: .leading, spacing: 4) {
                Text(playing ? t("reading.playing") : t("workbook.listenAll")).font(DS.text(15, .semibold)).foregroundColor(DS.ink)
                if playing, let current {
                    ProgressView(value: Double(current + 1), total: Double(max(1, text.de.count))).tint(color)
                } else {
                    Text(t("workbook.tapSentence")).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button {
                slow.toggle()
                if playing { playAll(text) }
            } label: {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(slow ? DS.onGold : DS.ink)
                    .frame(width: 40, height: 34)
                    .background(slow ? DS.gold : Color.clear, in: Capsule())
                    .overlay(Capsule().stroke(DS.hairline, lineWidth: slow ? 0 : 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("common.listenSlow"))
            .accessibilityAddTraits(slow ? .isSelected : [])
        }
        .padding(12)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sentenceCard(_ sentence: String, number: Int, active: Bool, color: Color) -> some View {
        Button {
            stop()
            A1Speaker.shared.say(sentence, slow: slow)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .heavy).monospacedDigit())
                    .foregroundColor(active ? .white : color)
                    .frame(width: 26, height: 26)
                    .background(active ? color : color.opacity(0.13), in: Circle())
                Text(sentence)
                    .font(.system(size: 17, weight: active ? .semibold : .regular))
                    .foregroundColor(DS.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(active ? color : DS.muted.opacity(0.7))
                    .padding(.top, 3)
            }
            .padding(14)
            .background(active ? color.opacity(0.12) : DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 1.5))
            .animation(.easeOut(duration: 0.2), value: active)
        }
        .buttonStyle(.pressable)
    }

    private func translation(_ text: A1Text) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showTranslation.toggle() }
            } label: {
                HStack {
                    Label(t("workbook.showTranslation"), systemImage: "character.bubble")
                        .font(DS.text(15, .semibold)).foregroundColor(DS.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold)).foregroundColor(DS.muted)
                        .rotationEffect(.degrees(showTranslation ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if showTranslation {
                Text(text.trans.text).font(.callout).foregroundColor(DS.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func playAll(_ text: A1Text) {
        stop()
        playing = true
        ended = false
        A1Speaker.shared.play(text.de.map { A1Line(s: -1, t: $0) }, slow: slow) { line in
            current = line
            if line == nil {
                ended = true
                endedAt = Date()
            }
        }
    }

    private func stop() {
        A1Speaker.shared.stop()
        playing = false
        current = nil
        ended = false
    }
}

struct A1WordListView: View {
    @EnvironmentObject private var model: A1Model
    @State private var search = ""
    @State private var filter = "all"

    var body: some View {
        let words = filtered
        List {
            Picker(t("workbook.type"), selection: $filter) {
                Text(t("workbook.all")).tag("all")
                Text(t("workbook.noun")).tag("noun")
                Text(t("workbook.verb")).tag("verb")
                Text(t("workbook.other")).tag("word")
            }
            .pickerStyle(.segmented)
            Section(t("common.words", words.count)) {
                ForEach(words) { word in
                    A1WordRow(word: word)
                }
            }
        }
        .searchable(text: $search, prompt: t("workbook.search"))
        .navigationTitle(t("practice.wordList"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filtered: [A1Word] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (model.content?.words ?? [])
            .filter { filter == "all" || $0.group == filter }
            .filter { query.isEmpty || $0.de.localizedStandardContains(query) || $0.mean.contains(query) }
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
                Text(a1PronLead(word.pron) + word.mean.text).font(.caption).foregroundStyle(.secondary)
                if let pl = word.plural {
                    Text(t("word.plural", pl)).font(.caption2).foregroundStyle(.secondary)
                }
                if let er = word.er {
                    Text("\(er) · \(word.perfekt ?? "")").font(.caption2).foregroundStyle(.secondary)
                }
                if let ex = word.ex.first {
                    Text(ex.de).font(.callout).padding(.top, 2)
                    if a1ShowsPron() {
                        Text("[\(ex.pron)]").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(ex.mean.text).font(.caption).foregroundStyle(.secondary)
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

/// Random number drill at the top of the numbers page: the dice gives a number (heard, or written in German)
/// and the learner picks its digits from four. Wrong options are typical mix-ups: swapped digits (47 / 74), ±1, ±10.
struct NumberQuizSection: View {
    enum Band: Int, CaseIterable, Identifiable {
        case small, tens, hundreds, thousands

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .small: return "0–20"
            case .tens: return "21–99"
            case .hundreds: return "100–999"
            case .thousands: return "1000+"
            }
        }
        var bounds: ClosedRange<Int> {
            switch self {
            case .small: return 0...20
            case .tens: return 21...99
            case .hundreds: return 100...999
            case .thousands: return 1000...99_999
            }
        }
    }

    @State private var band: Band = .tens
    @State private var listen = true
    @State private var number: Int?
    @State private var options: [Int] = []
    @State private var picked: Int?
    @State private var streak = 0

    var body: some View {
        Section {
            Picker(t("numbers.quiz.title"), selection: $band) {
                ForEach(Band.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: band) { _ in next() }
            Picker(t("numbers.quiz.title"), selection: $listen) {
                Text(t("numbers.quiz.listen")).tag(true)
                Text(t("numbers.quiz.read")).tag(false)
            }
            .pickerStyle(.segmented)
            Button { next() } label: {
                Label(t("numbers.quiz.new"), systemImage: "dice.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            if let n = number {
                HStack {
                    if listen {
                        Text(t("numbers.quiz.pick")).font(.headline)
                    } else {
                        Text(a1GermanNumber(n)).font(.title3.bold()).foregroundStyle(a1Accent)
                    }
                    Spacer()
                    A1SpeakButton(text: a1GermanNumber(n))
                    A1SpeakButton(text: a1GermanNumber(n), slow: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button { choose(option) } label: {
                            Text(digits(option))
                                .font(.title3.monospacedDigit().bold())
                                .foregroundColor(DS.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(fill(option), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(picked != nil)
                    }
                }
                .padding(.vertical, 4)
                if let picked = picked {
                    Text(picked == n ? t("numbers.quiz.right") : t("numbers.quiz.wrong", "\(digits(n)) = \(a1GermanNumber(n))"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(picked == n ? DS.success : DS.error)
                }
            }
        } header: {
            Text(t("numbers.quiz.title"))
        } footer: {
            if streak > 1 { Text(t("numbers.quiz.score", streak)) }
        }
    }

    private func digits(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

    private func fill(_ option: Int) -> Color {
        guard let picked = picked, let number = number else { return DS.chip }
        if option == number { return DS.success.opacity(0.25) }
        return option == picked ? DS.error.opacity(0.25) : DS.chip
    }

    private func next() {
        var n = Int.random(in: band.bounds)
        if n == number { n = Int.random(in: band.bounds) }
        number = n
        picked = nil
        options = choices(for: n)
        if listen { A1Speaker.shared.say(a1GermanNumber(n)) }
    }

    private func choose(_ option: Int) {
        guard let number = number, picked == nil else { return }
        picked = option
        streak = option == number ? streak + 1 : 0
        AnswerSound.play(correct: option == number)
        if option == number { StreakStore.shared.record() }
    }

    /// The number and three look-alikes: swapped last two digits first (the classic German mix-up), then ±1, ±10, ±100.
    private func choices(for n: Int) -> [Int] {
        var seen: Set<Int> = [n]
        var result = [n]
        func add(_ value: Int) {
            guard value >= 0, value < 1_000_000, !seen.contains(value), result.count < 4 else { return }
            seen.insert(value)
            result.append(value)
        }
        let text = Array(String(n))
        if text.count >= 2 {
            var swapped = text
            swapped.swapAt(text.count - 1, text.count - 2)
            if swapped.first != "0", let value = Int(String(swapped)) { add(value) }
        }
        for value in [n + 1, n - 1, n + 10, n - 10, n + 100, n - 100, n + 2].shuffled() { add(value) }
        while result.count < 4 { add(Int.random(in: band.bounds)) }
        return result.shuffled()
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
            NumberQuizSection()
            Section {
                TextField(t("numbers.input"), text: $input)
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
                        Text(t("numbers.asYear", a1Year(n))).font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    Text(t("numbers.range")).foregroundStyle(.secondary)
                }
            } header: {
                Text(t("numbers.converter"))
            } footer: {
                Text(t("numbers.converterHint"))
            }
            rule(t("numbers.r1"), t("numbers.r1text"), Array(0...12))
            rule(t("numbers.r2"), t("numbers.r2text"), Array(13...19))
            rule(t("numbers.r3"), t("numbers.r3text"), [20, 30, 40, 50, 60, 70, 80, 90])
            rule(t("numbers.r4"), t("numbers.r4text"), [21, 34, 47, 58, 65, 76, 89, 99])
            rule(t("numbers.r5"), t("numbers.r5text"), [100, 101, 115, 230, 347, 508, 999])
            rule(t("numbers.r6"), t("numbers.r6text"), [1000, 2500, 10_000, 12_345, 100_000])
            Section {
                ForEach([1990, 1998, 2000, 2010, 2024], id: \.self) { year in
                    row("\(year)", a1Year(year))
                }
            } header: {
                Text(t("numbers.r7"))
            } footer: {
                Text(t("numbers.r7text"))
            }
            Section {
                row("1,00 €", a1Price(1, 0))
                row("3,50 €", a1Price(3, 50))
                row("12,99 €", a1Price(12, 99))
                row("0,80 €", "achtzig Cent")
            } header: {
                Text(t("numbers.r8"))
            } footer: {
                Text(t("numbers.r8text"))
            }
            Section {
                row("0171 345 682", "null eins sieben eins – drei vier fünf – sechs acht zwei")
                row("030 12 34 56", "null drei null – zwölf vierunddreißig sechsundfünfzig")
            } header: {
                Text(t("numbers.r9"))
            } footer: {
                Text(t("numbers.r9text"))
            }
        }
        .navigationTitle(t("practice.numbers"))
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

/// "[pron] · " for Turkish speakers, nothing otherwise.
func a1PronLead(_ p: String) -> String { a1ShowsPron() && !p.isEmpty ? "[\(p)] · " : "" }
