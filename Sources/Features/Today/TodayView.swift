import SwiftUI

/// Home: Lina's greeting, today's text, word of the day and quick practice.
struct TodayView: View {
    @EnvironmentObject private var a1: A1Model
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var levels: LevelModels
    let open: (AppRoute) -> Void
    @State private var showStreak = false
    @State private var showBadges = false
    /// Height of the islands at the bottom (pills or an open card), so the page leaves just enough room under the
    /// last card to scroll it above them, and no empty space when they are small or closed.
    @State private var islandsHeight: CGFloat = 90
    /// A new word in the island each time Today comes back (owner's request): after another page or the app
    /// returning from the background.
    @State private var wordRound = 0
    /// Today's lesson is finished: its card goes away until the next day (owner's request).
    @State private var lessonDone = LessonStore.allDone
    @State private var appeared = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greeting.padding(.top, 4)
                PathContinueCard().padding(.top, 16)
                if !lessonDone {
                    LessonCard().padding(.top, 12).transition(.opacity)
                }
                ReviewCard(model: practiceModel).padding(.top, 12)
                TodayPractice(model: practiceModel).padding(.top, 22)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, islandsHeight + 24)  // room to scroll the last rows above the islands
        }
        .deschlyPage()
        .overlay(alignment: .bottomLeading) {
            // Today's text and the word of the day, stacked; only one is open at a time.
            VStack(alignment: .leading, spacing: 8) {
                if let text = daily.today {
                    TextIsland(text: text, note: dailyNote(text),
                               readLabel: daily.isRead(text) ? t("today.readAgain") : t("today.read")) {
                        open(.reading(text.id))
                    }
                }
                if let word = wordOfDay { WordIsland(word: word) }
            }
            .padding(.bottom, 12)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { islandsHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { islandsHeight = $0 }
            })
        }
        .navigationTitle(t("tab.today"))
        .onAppear {
            levels.active = practiceModel.level
            if appeared { wordRound += 1 }
            appeared = true
            lessonDone = LessonStore.allDone
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            if appeared { wordRound += 1 }
            lessonDone = LessonStore.allDone  // a new day brings the card back
        }
        .onReceive(NotificationCenter.default.publisher(for: LessonStore.changed)) { _ in
            withAnimation { lessonDone = LessonStore.allDone }
        }
        .onChange(of: daily.level) { _ in levels.active = practiceModel.level }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    StreakButton { showStreak = true }
                    Button { showBadges = true } label: { XPChip() }
                        .accessibilityHint(t("badges.title"))
                }
            }
        }
        .sheet(isPresented: $showStreak) {
            StreakView(open: open).environmentObject(daily).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBadges) { BadgesView(asSheet: true).presentationDragIndicator(.visible) }
    }

    /// Quick practice follows the level chosen above (A1, A2 …); levels without practice fall back to A1.
    private var practiceModel: A1Model {
        levels.hasPractice(daily.level) ? levels.model(daily.level) : levels.a1
    }

    private var greeting: some View {
        HStack(spacing: 14) {
            LinaAvatar(size: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText).font(DS.display(32)).foregroundColor(DS.ink).tracking(-1)
                Text(linaLine).font(DS.text(14)).foregroundColor(DS.muted)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "Guten Morgen!" }
        if hour < 18 { return "Guten Tag!" }
        return "Guten Abend!"
    }

    private var linaLine: String {
        guard let text = daily.today else { return "Lina: Los geht's!" }
        switch daily.status(text) {
        case .done: return "Lina: Super, morgen geht's weiter!"
        case .tried: return "Lina: Fast! Versuch das Quiz nochmal."
        default: break
        }
        return "Lina: Bereit für deinen Text?"
    }

    /// The quiz state of today's text, for its island.
    private func dailyNote(_ text: DailyText) -> String {
        if daily.isCompleted(text) { return t("today.quizDone", 100) }
        if let score = daily.quizScore(text) { return t("today.quizRetry", score) }
        return t("today.withQuiz")
    }

    /// A noun with an example from the learner's level, new every day (WordOfDay).
    private var wordOfDay: A1Word? {
        let model = practiceModel
        guard let words = (model.content ?? a1.content)?.words else { return nil }
        return WordOfDay.pick(from: words, level: model.content == nil ? "A1" : model.level, round: wordRound)
    }

    private func wordCard(_ word: A1Word) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("today.wordOfDay")).font(DS.text(12)).foregroundColor(DS.muted)
                (Text(word.type + " ").foregroundColor(a1ArticleColor(word.type)) + Text(word.de).foregroundColor(DS.ink))
                    .font(DS.display(21, heavy: false))
                Text(a1PronLead(word.pron) + word.mean.text).font(DS.text(13)).foregroundColor(DS.muted)
            }
            Spacer()
            Button { A1Speaker.shared.say(word.withArticle) } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.ink)
                    .frame(width: 44, height: 44)
                    .background(DS.ground, in: Circle())
                    .overlay(Circle().stroke(DS.hairline, lineWidth: 1))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(t("common.listen"))
        }
        .deschlyCard(padding: 14)
    }
}

/// "Keep going" for one level: four coloured tiles (articles, listening or gap filling, grammar, mistakes) with a
/// progress ring or a count. Observes that level's model so the numbers stay current.
struct TodayPractice: View {
    @ObservedObject var model: A1Model
    @State private var showLazySetup = false
    @State private var lazyConfig: LazyConfig?

    private func seenShare(_ mode: A1Mode) -> Double {
        let total = model.totalFor(mode)
        return total == 0 ? 0 : Double(min(model.seenCount(mode), total)) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("today.continue").uppercased() + " · " + model.level).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(t("today.levelNote", Int((model.readiness * 100).rounded()), model.state.wrong.count))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(.mode(.artikel), "Artikel", t("today.left", max(0, model.totalFor(.artikel) - model.seenCount(.artikel))),
                     "textformat", DS.die, progress: seenShare(.artikel))
                    .overlay(alignment: .bottomTrailing) { MistakeGroupBadge(model: model, group: .artikel) }
                if model.totalFor(.hoeren) > 0 {
                    tile(.mode(.hoeren), "Hören", t("today.hoerenNote"), "headphones", .orange, progress: seenShare(.hoeren))
                        .overlay(alignment: .bottomTrailing) { MistakeGroupBadge(model: model, group: .hoeren) }
                } else {
                    tile(.mode(.cloze), t("mode.cloze.title"), t("today.left", max(0, model.totalFor(.cloze) - model.seenCount(.cloze))),
                         "square.dashed", .teal, progress: seenShare(.cloze))
                }
                tile(.grammarList, "Grammatik", t("practice.grammarTopics", model.content?.grammar.count ?? 0),
                     "books.vertical.fill", .indigo, progress: nil)
                    .overlay(alignment: .bottomTrailing) { MistakeGroupBadge(model: model, group: .grammar) }
                tile(.mistakes, t("practice.mistakes"), t("today.mistakesNote"), "arrow.uturn.backward", .red,
                     progress: nil, badge: model.state.wrong.count)
                    .disabled(model.state.wrong.isEmpty)
                    .opacity(model.state.wrong.isEmpty ? 0.55 : 1)
            }
            // The word run game, in the space under the tiles (owner's request 2026-11-27).
            NavigationLink(value: A1Route.wordRun) { WordRunCard() }
                .buttonStyle(.pressable)
            // Chat with Lina (Apple's on-device model): only where it runs.
            if LinaAI.isAvailable {
                NavigationLink(value: A1Route.linaChat) { LinaChatCard() }
                    .buttonStyle(.pressable)
            }
            // Word matching, moved up from Practice to Today (owner's request).
            NavigationLink(value: A1Route.match(nil)) { MatchGameCard() }
                .buttonStyle(.pressable)
            let songs = SongBank.songs(model.level).count
            if songs > 0 {
                NavigationLink(value: A1Route.songs) { SongsCard(count: songs) }
                    .buttonStyle(.pressable)
            }
            // Tembel Mod, moved here from Practice (owner's request): the last card on Today.
            LazyModeCard(level: model.level) { showLazySetup = true }
        }
        .disabled(!model.ready)
        .sheet(isPresented: $showLazySetup) {
            LazySetupView(level: model.level, words: model.content?.words ?? [], themes: model.content?.themes ?? []) { config in
                showLazySetup = false
                // The player opens after the sheet has gone (two presentations at once are refused).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { lazyConfig = config }
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(item: $lazyConfig) { config in
            LazyPlayerView(config: config)
                .environmentObject(model)
                .modifier(ClearCoverBackground())
        }
    }

    private func tile(_ route: A1Route, _ title: String, _ value: String, _ icon: String, _ color: Color,
                      progress: Double?, badge: Int = 0) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Spacer(minLength: 0)
                    if let progress {
                        GoalRing(progress: progress, size: 32, lineWidth: 4, color: color) {
                            Text("\(Int((progress * 100).rounded()))").font(.system(size: 9, weight: .heavy)).foregroundColor(DS.ink)
                        }
                    } else if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 13, weight: .heavy).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(color, in: Capsule())
                    }
                }
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                Text(value).font(.caption).foregroundColor(DS.muted).lineLimit(2).multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }
}
