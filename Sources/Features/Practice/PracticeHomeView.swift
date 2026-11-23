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
    case texts
    case text(Int)
    case wordList
    case numbersLearn
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
            A1QuizView(title: model.content?.grammar.first { $0.id == id }?.de ?? "Grammatik") { model.session(topic: id) }
        case .texts:
            A1TextsView()
        case .text(let id):
            A1TextView(textID: id)
        case .wordList:
            A1WordListView()
        case .numbersLearn:
            A1NumbersLearnView()
        }
    }
}

extension View {
    func withA1Routes() -> some View {
        navigationDestination(for: A1Route.self) { A1Destination(route: $0) }
    }
}

/// A1 level home: progress, quick starts, all games and the workbook.
struct PracticeHomeView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !model.ready {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(t("practice.preparing")).font(DS.text(15)).foregroundColor(DS.muted)
                    }
                } else if model.content == nil {
                    Text(t("practice.loadFailed")).font(DS.text(15))
                } else {
                    quickStart
                    games
                    speedGames
                    workbook
                    Text(t("practice.footer")).font(DS.text(13)).foregroundColor(DS.muted)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 120)
        }
        .deschlyPage()
        .navigationTitle("A1")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("A1").font(DS.display(52)).foregroundColor(DS.ink)
                Text(t("level.a1.name")).font(DS.text(16, .medium)).foregroundColor(DS.muted)
                Spacer()
                Text("\(Int((model.readiness * 100).rounded()))%").font(DS.display(28, heavy: false)).foregroundColor(DS.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.hairline)
                    Capsule().fill(DS.ink).frame(width: max(8, geo.size.width * model.readiness))
                }
            }
            .frame(height: 8)
            HStack(spacing: 0) {
                stat("\(model.learned)", t("practice.statLearned", model.total))
                stat("\(model.state.streak)", t("practice.statStreak"))
                stat("\(model.todayCount)", t("practice.statToday"))
                stat(model.state.exams.last.map { "\($0)" } ?? "–", t("practice.statExam"))
            }
        }
        .padding(.top, 8)
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(DS.display(20, heavy: false)).foregroundColor(DS.ink).monospacedDigit()
            Text(title).font(DS.text(12)).foregroundColor(DS.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickStart: some View {
        VStack(spacing: 10) {
            NavigationLink(value: A1Route.mixed) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("practice.mixedTitle")).font(DS.display(22, heavy: false))
                        Text(t("practice.mixedSub")).font(DS.text(13)).foregroundColor(DS.onNightMuted)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.onGold)
                        .frame(width: 44, height: 44)
                        .background(DS.gold, in: Circle())
                }
                .foregroundColor(DS.onNight)
                .padding(18)
                .background(DS.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                NavigationLink(value: A1Route.exam) {
                    smallCard(t("practice.exam"), t("practice.examSub"), "graduationcap")
                }
                NavigationLink(value: A1Route.mistakes) {
                    smallCard(t("practice.mistakes"), t("practice.mistakesSub", model.state.wrong.count), "arrow.uturn.backward")
                }
                .disabled(model.state.wrong.isEmpty)
            }
            .buttonStyle(.plain)
        }
    }

    private func smallCard(_ title: String, _ sub: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(DS.ink)
            Text(title).font(DS.text(15, .semibold)).foregroundColor(DS.ink)
            Text(sub).font(DS.text(12)).foregroundColor(DS.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deschlyCard(padding: 14)
    }

    private var games: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: t("practice.games"))
            ForEach(Array(A1Mode.allCases.enumerated()), id: \.element) { index, mode in
                NavigationLink(value: A1Route.mode(mode)) {
                    ListRow(title: mode.title, note: "\(model.seenCount(mode))/\(model.totalFor(mode))",
                            showsDivider: index < A1Mode.allCases.count - 1) {
                        modeIcon(mode)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func modeIcon(_ mode: A1Mode) -> some View {
        if mode == .artikel {
            ArticleBars()
        } else {
            Image(systemName: mode.icon).font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
        }
    }

    private var speedGames: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: t("practice.speed"))
            NavigationLink(value: A1Route.sprint) {
                ListRow(title: t("practice.sprint"), note: t("practice.record", model.state.bestSprint)) {
                    Image(systemName: "timer").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.match(nil)) {
                ListRow(title: t("practice.match"), showsDivider: false) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var workbook: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: t("practice.workbook"))
            NavigationLink(value: A1Route.wordList) {
                ListRow(title: t("practice.wordList"), note: "\(model.content?.words.count ?? 0)") {
                    Image(systemName: "textformat.abc").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.themeQuiz(A1BankBuilder.coreTheme)) {
                ListRow(title: t("practice.coreQuiz"), note: "\(model.coreLearned)/\(model.coreTotal)") {
                    Image(systemName: "play.circle").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.themes) {
                ListRow(title: t("practice.themes")) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.grammarList) {
                ListRow(title: t("practice.grammarTopics", model.content?.grammar.count ?? 0)) {
                    Text("Aa").font(DS.display(15, heavy: false)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.texts) {
                ListRow(title: t("practice.texts", model.content?.texts.count ?? 0)) {
                    Image(systemName: "doc.richtext").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.numbersLearn) {
                ListRow(title: t("practice.numbers"), showsDivider: false) {
                    Image(systemName: "number").font(.system(size: 17, weight: .medium)).foregroundColor(DS.ink)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
