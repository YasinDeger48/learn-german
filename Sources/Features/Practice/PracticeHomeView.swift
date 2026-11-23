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
            A1QuizView(title: model.content?.grammar.first(where: { $0.id == id })?.de ?? "Grammatik") { model.session(topic: id) }
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

/// A1 level home as a native grouped list: progress, quick starts, every game and the workbook.
struct PracticeHomeView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var levels: LevelModels
    private var isA1: Bool { model.level == "A1" }

    var body: some View {
        List {
            if !model.ready {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(t("practice.preparing")).foregroundStyle(.secondary)
                }
            } else if model.content == nil {
                Text(t("practice.loadFailed"))
            } else {
                overview
                Section {
                    link(.mixed, t("practice.mixedTitle"), t("practice.mixedSub"), "shuffle", .orange)
                    link(.exam, t("practice.exam"), t("practice.examSub"), "graduationcap.fill", .indigo)
                    link(.mistakes, t("practice.mistakes"), t("practice.mistakesSub", model.state.wrong.count),
                         "arrow.uturn.backward", .red)
                        .disabled(model.state.wrong.isEmpty)
                }
                Section {
                    ForEach(A1Mode.allCases.filter { model.totalFor($0) > 0 }) { mode in
                        link(.mode(mode), mode.title, "\(model.seenCount(mode))/\(model.totalFor(mode))",
                             mode.icon, color(mode))
                    }
                } header: {
                    Text(t("practice.games"))
                } footer: {
                    Text(t("practice.footer"))
                }
                Section(t("practice.speed")) {
                    link(.sprint, t("practice.sprint"), t("practice.record", model.state.bestSprint), "timer", .pink)
                    link(.match(nil), t("practice.match"), nil, "square.grid.2x2.fill", .teal)
                }
                Section(t("practice.workbook")) {
                    link(.wordList, t("practice.wordList"), "\(model.content?.words.count ?? 0)", "textformat.abc", .blue)
                    if isA1 {
                        link(.themeQuiz(A1BankBuilder.coreTheme), t("practice.coreQuiz"), "\(model.coreLearned)/\(model.coreTotal)",
                             "play.circle.fill", .green)
                    }
                    link(.themes, t("practice.themes"), nil, "list.bullet.rectangle.fill", .brown)
                    link(.grammarList, t("practice.grammarTopics", model.content?.grammar.count ?? 0), nil, "books.vertical.fill", .purple)
                    if !(model.content?.texts.isEmpty ?? true) {
                        link(.texts, t("practice.texts", model.content?.texts.count ?? 0), nil, "doc.richtext.fill", .cyan)
                    }
                    if isA1 {
                        link(.numbersLearn, t("practice.numbers"), nil, "number", .mint)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(model.level) · " + t("level.\(model.level.lowercased()).name"))
        .onAppear { levels.active = model.level }
    }

    private var overview: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int((model.readiness * 100).rounded()))%").font(.largeTitle.bold()).monospacedDigit()
                    Text(t("practice.statLearned", model.total)).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: model.readiness).tint(DS.das)
                HStack {
                    stat("\(model.state.streak)", t("practice.statStreak"), "flame.fill", .orange)
                    stat("\(model.todayCount)", t("practice.statToday"), "checkmark.circle.fill", DS.das)
                    stat(model.state.exams.last.map { "\($0)" } ?? "–", t("practice.statExam"), "graduationcap.fill", .indigo)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func stat(_ value: String, _ title: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.headline).monospacedDigit()
                Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A row like the iOS Settings app: coloured icon square, title, value on the right.
    private func link(_ route: A1Route, _ title: String, _ value: String?, _ icon: String, _ color: Color) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title).lineLimit(2)
                Spacer(minLength: 6)
                if let value { Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
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
