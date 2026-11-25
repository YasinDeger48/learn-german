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
                HStack(spacing: 8) {
                    chip(.all, t("grammar.filterAll"))
                    chip(.open, t("grammar.filterOpen"))
                    chip(.mistakes, t("grammar.filterMistakes", withMistakes))
                }
                .padding(.bottom, 4)
                ForEach(topics) { topic in
                    NavigationLink(value: A1Route.grammar(topic.id)) { topicCard(topic) }
                        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
            List {
                Section(t("workbook.rule")) {
                    Text(topic.rule.text)
                }
                Section(t("workbook.examples")) {
                    ForEach(topic.examples, id: \.self) { example in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.de)
                                Text(example.mean.text).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            A1SpeakButton(text: example.de)
                        }
                    }
                }
                Section {
                    NavigationLink(value: A1Route.grammarQuiz(topicID)) {
                        Label(t("workbook.topicQuiz", model.questions.filter { $0.topic == topicID }.count), systemImage: "play.circle.fill")
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
                    Text(text.titleL.text).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(t("workbook.textsTitle"))
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
                        Label(t("workbook.listenAll"), systemImage: "speaker.wave.2.fill")
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
                    Toggle(t("workbook.showTranslation"), isOn: $showTurkish)
                    if showTurkish { Text(text.trans.text).foregroundStyle(.secondary) }
                }
                Section {
                    NavigationLink(value: A1Route.mode(.reading)) {
                        Label(t("workbook.readingQuiz"), systemImage: "play.circle.fill")
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

struct A1NumbersLearnView: View {
    @State private var input = "347"

    private var number: Int? {
        guard let n = Int(input.filter(\.isNumber)), n < 1_000_000 else { return nil }
        return n
    }

    var body: some View {
        List {
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
