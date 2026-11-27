import SwiftUI

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
    case review
    case texts
    case text(Int)
    case wordList
    case numbersLearn
    case speaking
    case speakRepeat
    case speakTask(String)
    case phone
    case mistakesOf(MistakeGroup)
    case wordRun
    case songs
    case linaChat
    case camera
}

/// Every practice screen, reachable from any tab's NavigationStack.
struct A1Destination: View {
    @EnvironmentObject private var model: A1Model
    let route: A1Route

    var body: some View {
        switch route {
        case .mode(let mode):
            A1QuizView(title: mode.title, resetMode: mode) { model.session(mode: mode) }
        case .mixed:
            A1QuizView(title: t("practice.mixed")) { model.session() }
        case .exam:
            A1QuizView(title: t("practice.exam"), exam: true) { model.examSession() }
        case .review:
            A1QuizView(title: t("review.title"), free: true) { model.reviewSession() }  // due words: never blocked
        case .mistakes:
            A1QuizView(title: t("practice.mistakes"), review: true) { model.mistakeSession() }
        case .sprint:
            A1SprintView()
        case .match(let theme):
            A1MatchView(theme: theme)
        case .themes:
            A1ThemesView()
        case .theme(let id):
            A1ThemeView(themeID: id)
        case .themeQuiz(let id):
            A1QuizView(title: model.content?.themes[id].de ?? "") { model.session(theme: id) }
        case .grammarList:
            A1GrammarListView()
        case .grammar(let id):
            A1GrammarView(topicID: id)
        case .grammarQuiz(let id):
            A1QuizView(title: model.content?.grammar.first(where: { $0.id == id })?.de ?? "Grammatik") { model.session(topic: id) }
        case .texts:
            A1TextsView()
        case .text(let id):
            A1TextView(textID: id)
        case .wordList:
            A1WordListView()
        case .numbersLearn:
            A1NumbersLearnView()
        case .speaking:
            SpeakingHomeView()
        case .speakRepeat:
            SpeakRepeatView()
        case .speakTask(let id):
            if let task = SpeakingBank.task(id) { SpeakTaskView(task: task) }
        case .phone:
            PhoneCallsView(level: model.level)
        case .mistakesOf(let group):
            A1QuizView(title: group.title, review: true) { model.mistakeSession(group) }
        case .wordRun:
            WordRunView()
        case .songs:
            SongsHomeView(level: model.level)
        case .linaChat:
            LinaChatHomeView(level: model.level)
        case .camera:
            CameraLearnView()
        }
    }
}

/// Practice screens get the model of the level that is open (A1, A2, …).
struct A1RouteDestinations: ViewModifier {
    @EnvironmentObject private var levels: LevelModels

    func body(content: Content) -> some View {
        content.navigationDestination(for: A1Route.self) { route in
            A1Destination(route: route).environmentObject(levels.current)
        }
    }
}

extension View {
    func withA1Routes() -> some View { modifier(A1RouteDestinations()) }
}

/// Level home: a hero card with progress and the recommended next step, practice modes as cards,
/// speed games and the workbook.
struct PracticeHomeView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var daily: DailyModel
    @State private var showPaywall = false
    private var isA1: Bool { model.level == "A1" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !model.ready {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(t("practice.preparing")).foregroundColor(DS.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if model.content == nil {
                    Text(t("practice.loadFailed"))
                } else {
                    hero
                    // Tembel Mod moved to Today (owner's request).
                    if !pro.isPro { FreeQuestionsBanner { showPaywall = true } }
                    speakingCard
                    modeGrid
                    speedRow
                    workbook
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle("\(model.level) · " + t("level.\(model.level.lowercased()).name"))
        .onAppear {
            levels.active = model.level
            pro.refreshQuota()
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
        .safeAreaInset(edge: .bottom) { AdBanner() }
    }

    // MARK: Hero

    /// What to do next: open mistakes first, then the first unfinished grammar topic, else a mixed round.
    private var next: (route: A1Route, title: String, note: String) {
        if !model.state.wrong.isEmpty {
            return (.mistakes, t("practice.nextMistakes"), t("practice.nextMistakesNote", model.state.wrong.count))
        }
        let due = model.dueReviewIDs.count
        if due > 0 {
            return (.review, t("review.title"), t("review.due", due))
        }
        if let topic = model.content?.grammar.first(where: { model.topicStatus($0.id) != .done }) {
            return (.grammar(topic.id), t("practice.nextContinue", topic.de), t("practice.nextNote", 10, 3, 10 * XP.correct))
        }
        return (.mixed, t("practice.mixedTitle"), t("practice.nextNote", 10, 3, 10 * XP.correct))
    }

    private var hero: some View {
        let readiness = model.readiness
        let step = next
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.level) · " + t("level.\(model.level.lowercased()).name"))
                        .font(.subheadline.weight(.semibold)).foregroundColor(.white.opacity(0.85))
                    Text(t("practice.ready", Int((readiness * 100).rounded())))
                        .font(.system(size: 28, weight: .heavy)).foregroundColor(.white)
                    Text(t("practice.statLearned", model.total)).font(.footnote).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                GoalRing(progress: readiness, size: 64, lineWidth: 7, color: DS.gold) {
                    Text("\(model.learned)").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                }
            }
            NavigationLink(value: step.route) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.onGold)
                        .frame(width: 40, height: 40)
                        .background(DS.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title).font(.system(size: 16, weight: .bold)).foregroundColor(.black).lineLimit(1)
                        Text(step.note).font(.footnote).foregroundColor(Color(white: 0.42)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundColor(Color(white: 0.6))
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(red: 0.118, green: 0.227, blue: 0.62), Color(red: 0.184, green: 0.357, blue: 0.918),
                                            Color(red: 0.357, green: 0.498, blue: 0.949)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 4)
    }

    // MARK: Modes

    private var modeGrid: some View {
        let modes = A1Mode.allCases.filter { model.totalFor($0) > 0 }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            card(.mixed, "shuffle", .orange, t("practice.mixedTitle"), t("practice.mixedSub"), progress: nil)
            card(.exam, "graduationcap.fill", .indigo, t("practice.exam"),
                 model.state.exams.max().map { t("practice.bestExam", $0) } ?? t("practice.examSub"), progress: nil)
            if !model.state.wrong.isEmpty {
                card(.mistakes, "arrow.uturn.backward", DS.error, t("practice.mistakes"),
                     t("practice.mistakesSub", model.state.wrong.count), progress: nil)
            }
            ForEach(modes) { mode in
                let total = model.totalFor(mode)
                let seen = min(model.seenCount(mode), total)
                card(.mode(mode), mode.icon, color(mode), mode.title, "\(seen)/\(total)",
                     progress: total == 0 ? 0 : Double(seen) / Double(total))
            }
        }
    }

    private func card(_ route: A1Route, _ icon: String, _ color: Color, _ title: String, _ sub: String, progress: Double?) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink).lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let progress {
                    HStack(spacing: 8) {
                        ProgressView(value: progress).tint(color)
                        Text(sub).font(.caption.monospacedDigit()).foregroundColor(DS.muted).lineLimit(1)
                    }
                } else {
                    Text(sub).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Speaking

    private var speakingCard: some View {
        let tasks = SpeakingBank.tasks(model.level)
        let done = tasks.filter { (SpeakingBank.best($0.id) ?? 0) >= $0.points.count }.count
        return NavigationLink(value: A1Route.speaking) {
            HStack(spacing: 14) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DS.onGold)
                    .frame(width: 46, height: 46)
                    .background(DS.gold, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("speak.title")).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    Text(tasks.isEmpty ? t("speak.sub") : t("speak.subTasks", done, tasks.count))
                        .font(.footnote).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundColor(.white.opacity(0.8))
            }
            .padding(14)
            .background(SpeakStyle.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Speed games

    private var speedRow: some View {
        HStack(spacing: 10) {
            smallCard(.sprint, "timer", .pink, t("practice.sprint"), t("practice.record", model.state.bestSprint))
            smallCard(.match(nil), "square.grid.2x2.fill", .teal, t("practice.match"), t("practice.matchSub"))
        }
    }

    private func smallCard(_ route: A1Route, _ icon: String, _ color: Color, _ title: String, _ sub: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(DS.ink)
                    Text(sub).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Workbook

    private var workbook: some View {
        let topics = model.content?.grammar ?? []
        let doneTopics = topics.filter { model.topicStatus($0.id) == .done }.count
        return VStack(spacing: 0) {
            row(.grammarList, "books.vertical.fill", .purple, t("practice.grammarTopics", topics.count), "\(doneTopics)/\(topics.count)",
                valueColor: doneTopics > 0 ? DS.success : DS.muted)
            Divider().padding(.leading, 52)
            row(.wordList, "textformat.abc", .blue, t("practice.wordList"), "\(model.content?.words.count ?? 0)")
            Divider().padding(.leading, 52)
            row(.themes, "list.bullet.rectangle.fill", .brown, t("practice.themes"), nil)
            if isA1 {
                Divider().padding(.leading, 52)
                row(.themeQuiz(A1BankBuilder.coreTheme), "play.circle.fill", .green, t("practice.coreQuiz"), "\(model.coreLearned)/\(model.coreTotal)")
            }
            if !(model.content?.texts.isEmpty ?? true) {
                Divider().padding(.leading, 52)
                row(.texts, "doc.richtext.fill", .cyan, t("practice.texts", model.content?.texts.count ?? 0), nil)
            }
            let calls = PhoneBank.texts(model.level)
            if !calls.isEmpty {
                Divider().padding(.leading, 52)
                row(.phone, "phone.fill", .green, t("phone.title"), "\(calls.filter { daily.isCompleted($0) }.count)/\(calls.count)")
            }
            if isA1 {
                Divider().padding(.leading, 52)
                row(.numbersLearn, "number", .mint, t("practice.numbers"), nil)
            }
        }
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(_ route: A1Route, _ icon: String, _ color: Color, _ title: String, _ value: String?, valueColor: Color = DS.muted) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(color).frame(width: 26)
                Text(title).foregroundColor(DS.ink).lineLimit(2)
                Spacer(minLength: 6)
                if let value { Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundColor(valueColor) }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func color(_ mode: A1Mode) -> Color {
        switch mode {
        case .artikel: return DS.die
        case .wordToTr, .trToWord: return .blue
        case .sentence, .cloze, .order: return .teal
        case .listen, .hoeren: return .orange
        case .write: return .pink
        case .plural, .verbs: return .purple
        case .grammar: return .indigo
        case .numbers: return .mint
        case .reading, .daily: return .green
        }
    }
}
