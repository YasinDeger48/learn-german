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
    @State private var appeared = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greeting.padding(.top, 4)
                // One plan for the day (unit step, words and review, text, speaking), then the games.
                TodayPlanCard(model: practiceModel).padding(.top, 16)
                TodayGames(model: practiceModel).padding(.top, 22)
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
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            if appeared { wordRound += 1 }
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

