import SwiftUI

/// Home: Lina's greeting, today's text, word of the day and quick practice.
struct TodayView: View {
    @EnvironmentObject private var a1: A1Model
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var levels: LevelModels
    let open: (AppRoute) -> Void
    @State private var showStreak = false
    @State private var showBadges = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greeting.padding(.top, 4)
                PathContinueCard().padding(.top, 16)
                LessonCard().padding(.top, 12)
                ReviewCard(model: practiceModel).padding(.top, 12)
                TodayPractice(model: practiceModel).padding(.top, 22)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 190)  // room to scroll the last rows above the islands
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
        }
        .navigationTitle(t("tab.today"))
        .onAppear { levels.active = practiceModel.level }
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
        return WordOfDay.pick(from: words, level: model.content == nil ? "A1" : model.level)
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

/// "Keep going" rows for one level. Observes that level's model so the counts stay current.
struct TodayPractice: View {
    @ObservedObject var model: A1Model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("today.continue").uppercased() + " · " + model.level).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text(t("today.levelNote", Int((model.readiness * 100).rounded()), model.state.wrong.count))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            VStack(spacing: 0) {
                row(.mode(.artikel), "Artikel", t("today.left", max(0, model.totalFor(.artikel) - model.seenCount(.artikel))), "textformat", DS.die)
                Divider().padding(.leading, 58)
                if model.totalFor(.hoeren) > 0 {
                    row(.mode(.hoeren), "Hören", t("today.hoerenNote"), "headphones", .orange)
                } else {
                    row(.mode(.cloze), t("mode.cloze.title"), t("today.left", max(0, model.totalFor(.cloze) - model.seenCount(.cloze))), "square.dashed", .teal)
                }
                Divider().padding(.leading, 58)
                row(.grammarList, "Grammatik", t("practice.grammarTopics", model.content?.grammar.count ?? 0), "books.vertical.fill", .indigo)
                Divider().padding(.leading, 58)
                row(.mistakes, t("practice.mistakes"), "\(model.state.wrong.count)", "arrow.uturn.backward", .red)
                    .disabled(model.state.wrong.isEmpty)
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!model.ready)
    }

    /// Settings-style row: coloured icon square, title, value, chevron.
    private func row(_ route: A1Route, _ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title).foregroundColor(DS.ink)
                Spacer()
                Text(value).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}
