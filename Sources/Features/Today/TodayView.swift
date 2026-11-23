import SwiftUI

/// Home: Lina's greeting, today's text, word of the day and quick practice.
struct TodayView: View {
    @EnvironmentObject private var a1: A1Model
    @EnvironmentObject private var daily: DailyModel
    let open: (AppRoute) -> Void
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                greeting.padding(.top, 20)
                levelTabs.padding(.top, 16)
                dailyCard.padding(.top, 16)
                if let word = wordOfDay { wordCard(word).padding(.top, 14) }
                practice.padding(.top, 22)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 120)
        }
        .deschlyPage()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var topBar: some View {
        HStack {
            Wordmark()
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").foregroundColor(DS.gold)
                Text("\(a1.state.streak)").font(DS.text(15, .semibold)).foregroundColor(DS.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(t("today.streak", a1.state.streak))
            CircleIconButton(systemName: "slider.horizontal.3", label: t("settings.title"), filled: true) { showSettings = true }
                .padding(.leading, 10)
        }
        .padding(.top, 8)
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
        if daily.quizScore(text) != nil { return "Lina: Super, morgen geht's weiter!" }
        return "Lina: Bereit für deinen Text?"
    }

    private var levelTabs: some View {
        HStack(spacing: 22) {
            ForEach(DailyModel.levels, id: \.self) { level in
                let active = level == daily.level
                let available = daily.isAvailable(level)
                Button {
                    if available { daily.level = level }
                } label: {
                    VStack(spacing: 8) {
                        Text(level)
                            .font(DS.text(15, active ? .semibold : .medium))
                            .foregroundColor(active ? DS.ink : (available ? DS.muted : DS.muted.opacity(0.5)))
                        Rectangle().fill(active ? DS.ink : Color.clear).frame(height: 2)
                    }
                    .frame(minWidth: 32, minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(!available)
                .accessibilityLabel(available ? level : t("levels.soonA11y", level))
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(DS.hairline).frame(height: 1) }
    }

    @ViewBuilder
    private var dailyCard: some View {
        if let text = daily.today {
            Button { open(.reading(text.id)) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    if let cover = Covers.image(text.id) {
                        CoverImage(image: cover, height: 160, radius: 18)
                    }
                    Text(t("today.dailyMeta", text.level, text.minutes)).font(DS.text(13)).foregroundColor(DS.onNightMuted)
                    Text(text.title)
                        .font(DS.display(34, heavy: false))
                        .tracking(-1.2)
                        .foregroundColor(DS.onNight)
                        .frame(maxWidth: 250, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    HStack {
                        HStack(spacing: 8) {
                            Text(daily.isRead(text) ? t("today.readAgain") : t("today.read"))
                            Image(systemName: "arrow.right")
                        }
                        .font(DS.text(15, .semibold))
                        .foregroundColor(DS.onGold)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 46)
                        .background(DS.gold, in: Capsule())
                        Spacer()
                        if let score = daily.quizScore(text) {
                            Label(t("today.quizDone", score), systemImage: "checkmark.circle.fill")
                                .font(DS.text(13, .medium))
                                .foregroundColor(DS.onNight)
                        } else {
                            Text(t("today.withQuiz")).font(DS.text(13)).foregroundColor(DS.onNightMuted)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .topTrailing) {
                    ZStack(alignment: .topTrailing) {
                        Circle().fill(DS.gold).frame(width: 150, height: 150).offset(x: 36, y: -36)
                        Text(dateStamp)
                            .font(DS.text(13, .semibold))
                            .foregroundColor(DS.onGold)
                            .multilineTextAlignment(.trailing)
                            .padding(.top, 22)
                            .padding(.trailing, 24)
                    }
                    .accessibilityHidden(true)
                }
                .background(DS.night)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var dateStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM."
        return "HEUTE\n" + f.string(from: Date())
    }

    /// A noun with an example, the same for everyone on the same day.
    private var wordOfDay: A1Word? {
        guard let words = a1.content?.words else { return nil }
        let nouns = words.filter { $0.isNoun && !$0.ex.isEmpty && $0.theme != A1BankBuilder.coreTheme }
        guard !nouns.isEmpty else { return nil }
        return nouns[(DailyModel.dayNumber(Date()) * 37) % nouns.count]
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
            .buttonStyle(.plain)
            .accessibilityLabel(t("common.listen"))
        }
        .deschlyCard(padding: 14)
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: t("today.continue"),
                         note: t("today.levelNote", Int((a1.readiness * 100).rounded()), a1.state.wrong.count))
            NavigationLink(value: A1Route.mode(.artikel)) {
                ListRow(title: "Artikel", note: t("today.left", max(0, a1.totalFor(.artikel) - a1.seenCount(.artikel)))) { ArticleBars() }
            }
            NavigationLink(value: A1Route.mode(.hoeren)) {
                ListRow(title: "Hören", note: t("today.hoerenNote")) {
                    Image(systemName: "waveform").font(.system(size: 18, weight: .semibold)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.grammarList) {
                ListRow(title: "Grammatik", note: t("today.grammarNote")) {
                    Text("Aa").font(DS.display(15, heavy: false)).foregroundColor(DS.ink)
                }
            }
            NavigationLink(value: A1Route.mistakes) {
                ListRow(title: t("practice.mistakes"), note: "\(a1.state.wrong.count)", showsDivider: false) {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold)).foregroundColor(DS.ink)
                }
            }
            .disabled(a1.state.wrong.isEmpty)
        }
        .buttonStyle(.plain)
        .disabled(!a1.ready)
    }
}
