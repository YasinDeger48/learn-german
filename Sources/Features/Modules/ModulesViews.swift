import SwiftUI

/// The four modules of the Goethe-style exam. Every practice game belongs to one of them (or to the basics).
enum ExamModule: String, CaseIterable, Identifiable, Hashable {
    case lesen, hoeren, schreiben, sprechen

    var id: String { rawValue }

    /// German names, as in the exam.
    var title: String {
        switch self {
        case .lesen: return "Lesen"
        case .hoeren: return "Hören"
        case .schreiben: return "Schreiben"
        case .sprechen: return "Sprechen"
        }
    }

    var subtitle: String { t("module.\(rawValue).sub") }
    var examInfo: String { t("module.\(rawValue).exam") }

    var icon: String {
        switch self {
        case .lesen: return "book"
        case .hoeren: return "headphones"
        case .schreiben: return "pencil.line"
        case .sprechen: return "mic.fill"
        }
    }

    var color: Color {
        switch self {
        case .lesen: return DS.der
        case .hoeren: return Color(red: 0.76, green: 0.25, blue: 0.05)
        case .schreiben: return DS.das
        case .sprechen: return DS.die
        }
    }

    /// Practice games of this module.
    var modes: [A1Mode] {
        switch self {
        case .lesen: return [.reading]
        case .hoeren: return [.hoeren, .listen]
        case .schreiben: return [.write, .order, .sentence, .cloze]
        case .sprechen: return [.daily]
        }
    }

    /// Minutes in the exam (Goethe A1 timing; the mock exam uses the same).
    var minutes: Int {
        switch self {
        case .lesen: return 25
        case .hoeren: return 20
        case .schreiben: return 20
        case .sprechen: return 15
        }
    }

    /// The exam parts (Teil 1…3), shown on the module page.
    var parts: [String] {
        (1...(self == .schreiben ? 2 : 3)).map { t("module.\(rawValue).part\($0)") }
    }

    /// 0…1: practice done in this module (games seen; texts finished for Lesen; speaking tasks for Sprechen).
    func progress(_ model: A1Model, daily: DailyModel) -> Double {
        var done = 0.0, total = 0.0
        for mode in modes where model.totalFor(mode) > 0 {
            total += Double(model.totalFor(mode))
            done += Double(min(model.seenCount(mode), model.totalFor(mode)))
        }
        var parts: [Double] = total > 0 ? [done / total] : []
        switch self {
        case .lesen:
            let texts = daily.texts[model.level] ?? []
            if !texts.isEmpty { parts.append(Double(texts.filter { daily.isCompleted($0) }.count) / Double(texts.count)) }
        case .sprechen:
            let tasks = SpeakingBank.tasks(model.level)
            if !tasks.isEmpty {
                let covered = tasks.map { Double(min(SpeakingBank.best($0.id) ?? 0, $0.points.count)) / Double(max(1, $0.points.count)) }
                parts.append(covered.reduce(0, +) / Double(tasks.count))
            }
        default:
            break
        }
        return parts.isEmpty ? 0 : parts.reduce(0, +) / Double(parts.count)
    }
}

/// Level chips used on the Modules and Exam tabs; they change the level that practice screens use.
struct LevelChips: View {
    @EnvironmentObject private var levels: LevelModels

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LevelModels.practiceLevels, id: \.self) { level in
                Button {
                    levels.active = level
                } label: {
                    Text(level)
                        .font(DS.text(14, .bold))
                        .foregroundColor(levels.active == level ? DS.ground : DS.ink)
                        .frame(minWidth: 52, minHeight: 36)
                        .background(levels.active == level ? DS.ink : DS.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(levels.active == level ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Modules tab

struct ModulesHomeView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel
    @State private var didPickLevel = false

    var body: some View {
        let model = levels.current
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LevelChips()
                if model.ready {
                    hero(model)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(ExamModule.allCases) { module in
                            NavigationLink(value: AppRoute.module(module.rawValue)) { moduleCard(module, model) }
                                .buttonStyle(.pressable)
                        }
                    }
                    basics(model)
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(t("practice.preparing")).foregroundColor(DS.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("tab.modules"))
        .onAppear {
            // Start on the learner's own level the first time.
            if !didPickLevel {
                didPickLevel = true
                if levels.hasPractice(daily.level) { levels.active = daily.level }
            }
        }
        .safeAreaInset(edge: .bottom) { AdBanner() }
    }

    private func hero(_ model: A1Model) -> some View {
        let readiness = ExamModule.allCases.map { $0.progress(model, daily: daily) }.reduce(0, +) / 4
        return HStack(spacing: 14) {
            GoalRing(progress: readiness, size: 66, lineWidth: 8, color: DS.gold) {
                Text("\(Int((readiness * 100).rounded()))%").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(t("modules.readiness").uppercased()).font(.caption.weight(.bold)).foregroundColor(.white.opacity(0.65))
                Text(t("modules.goal", model.level)).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Text(t("modules.goalNote")).font(.footnote).foregroundColor(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func moduleCard(_ module: ExamModule, _ model: A1Model) -> some View {
        let progress = module.progress(model, daily: daily)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: module.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(module.color)
                .frame(width: 38, height: 38)
                .background(module.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(module.title).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                Text(module.subtitle).font(.caption).foregroundColor(DS.muted)
            }
            HStack(spacing: 8) {
                ProgressView(value: progress).tint(module.color)
                Text("\(Int((progress * 100).rounded()))%").font(.caption.monospacedDigit().weight(.semibold)).foregroundColor(DS.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func basics(_ model: A1Model) -> some View {
        let topics = model.content?.grammar ?? []
        let doneTopics = topics.filter { model.topicStatus($0.id) == .done }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text(t("modules.basics")).font(.title3.weight(.bold)).padding(.top, 6)
            VStack(spacing: 0) {
                NavigationLink(value: AppRoute.basics) {
                    ModuleRow(icon: "textformat.abc", color: .blue, title: "Wortschatz", subtitle: t("modules.wordsSub"),
                              value: "\(model.content?.words.count ?? 0)")
                }
                Divider().padding(.leading, 56)
                NavigationLink(value: A1Route.grammarList) {
                    ModuleRow(icon: "books.vertical.fill", color: .purple, title: "Grammatik", subtitle: t("modules.grammarSub"),
                              value: "\(doneTopics)/\(topics.count)")
                }
                Divider().padding(.leading, 56)
                NavigationLink(value: AppRoute.practice(model.level)) {
                    ModuleRow(icon: "square.grid.2x2.fill", color: .orange, title: t("modules.allPractice"),
                              subtitle: t("modules.allPracticeSub"), value: nil)
                }
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// One row in the grouped lists of the module pages.
struct ModuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String?
    let value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(DS.muted).lineLimit(1) }
            }
            Spacer(minLength: 4)
            if let value { Text(value).font(.subheadline.monospacedDigit()).foregroundColor(DS.muted) }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - One module

struct ModuleView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    let module: ExamModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text(t("modules.examParts")).font(.title3.weight(.bold))
                VStack(spacing: 0) {
                    ForEach(Array(module.parts.enumerated()), id: \.offset) { index, part in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(module.color)
                                .frame(width: 32, height: 32)
                                .background(module.color.opacity(0.13), in: Circle())
                            Text(part).font(.system(size: 15)).foregroundColor(DS.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(t("modules.practice")).font(.title3.weight(.bold)).padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().padding(.leading, 56) }
                        row
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let progress = module.progress(model, daily: daily)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(model.level) · \(module.subtitle)".uppercased()).font(.caption.weight(.bold)).foregroundColor(.white.opacity(0.75))
                Text(module.title).font(DS.display(32)).foregroundColor(.white)
                Text(module.examInfo).font(.footnote).foregroundColor(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(module.color)
                .frame(width: 64, height: 64)
                .background(Color.white, in: Circle())
        }
        .padding(18)
        .background(module.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 4)
    }

    /// The module's practice: its games plus the screens that belong to it.
    private var rows: [AnyView] {
        var out: [AnyView] = []
        func link<V: Hashable>(_ value: V, _ icon: String, _ title: String, _ subtitle: String?, _ count: String?) {
            out.append(AnyView(NavigationLink(value: value) {
                ModuleRow(icon: icon, color: module.color, title: title, subtitle: subtitle, value: count)
            }))
        }
        switch module {
        case .lesen:
            let texts = daily.texts[model.level] ?? []
            link(AppRoute.readingHome, "doc.richtext.fill", t("modules.dailyTexts"), t("modules.dailyTextsSub"),
                 "\(texts.filter { daily.isCompleted($0) }.count)/\(texts.count)")
            if !(model.content?.texts.isEmpty ?? true) {
                link(A1Route.texts, "text.alignleft", t("practice.texts", model.content?.texts.count ?? 0), nil, nil)
            }
            link(AppRoute.savedWords, "bookmark.fill", t("saved.title"), nil, "\(daily.state.savedWords.count)")
        case .hoeren:
            link(AppRoute.readingHome, "waveform", t("modules.listenTexts"), t("modules.listenTextsSub"), nil)
        case .sprechen:
            link(A1Route.speaking, "mic.fill", t("speak.title"), t("speak.sub"), nil)
            link(A1Route.speakRepeat, "repeat", t("speak.repeatTitle"), nil, nil)
        case .schreiben:
            let tasks = WritingBank.tasks(model.level)
            if !tasks.isEmpty {
                let done = tasks.filter { (WritingBank.best($0.id) ?? 0) >= 60 }.count
                link(AppRoute.writing, "square.and.pencil", t("modules.writingTasks"), t("modules.writingTasksSub"), "\(done)/\(tasks.count)")
            }
        }
        for mode in module.modes where model.totalFor(mode) > 0 {
            let total = model.totalFor(mode)
            link(A1Route.mode(mode), mode.icon, mode.title, mode.subtitle, "\(min(model.seenCount(mode), total))/\(total)")
        }
        return out
    }
}

// MARK: - Basics: words

struct WordsBasicsView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        let modes: [A1Mode] = [.artikel, .wordToTr, .trToWord, .plural, .verbs, .numbers].filter { model.totalFor($0) > 0 }
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    NavigationLink(value: A1Route.wordList) {
                        ModuleRow(icon: "textformat.abc", color: .blue, title: t("practice.wordList"), subtitle: nil,
                                  value: "\(model.content?.words.count ?? 0)")
                    }
                    Divider().padding(.leading, 56)
                    NavigationLink(value: A1Route.themes) {
                        ModuleRow(icon: "list.bullet.rectangle.fill", color: .brown, title: t("practice.themes"), subtitle: nil, value: nil)
                    }
                    if model.level == "A1" {
                        Divider().padding(.leading, 56)
                        NavigationLink(value: A1Route.numbersLearn) {
                            ModuleRow(icon: "number", color: .mint, title: t("practice.numbers"), subtitle: nil, value: nil)
                        }
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(modes.enumerated()), id: \.element) { index, mode in
                        if index > 0 { Divider().padding(.leading, 56) }
                        let total = model.totalFor(mode)
                        NavigationLink(value: A1Route.mode(mode)) {
                            ModuleRow(icon: mode.icon, color: .blue, title: mode.title, subtitle: mode.subtitle,
                                      value: "\(min(model.seenCount(mode), total))/\(total)")
                        }
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 0) {
                    NavigationLink(value: A1Route.sprint) {
                        ModuleRow(icon: "timer", color: .pink, title: t("practice.sprint"), subtitle: t("practice.record", model.state.bestSprint), value: nil)
                    }
                    Divider().padding(.leading, 56)
                    NavigationLink(value: A1Route.match(nil)) {
                        ModuleRow(icon: "square.grid.2x2.fill", color: .teal, title: t("practice.match"), subtitle: t("practice.matchSub"), value: nil)
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle("Wortschatz")
        .navigationBarTitleDisplayMode(.inline)
    }
}
