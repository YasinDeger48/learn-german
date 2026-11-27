import SwiftUI

/// One step of today's lesson as its own screen (AppRoute.lessonStep), used by the plan card and the lesson page.
struct LessonStepView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    let step: LessonStep

    var body: some View {
        switch step {
        case .practice:
            A1QuizView(title: t("lesson.step.practice"), onFinish: { _, _ in LessonStore.mark(.practice) }) {
                model.lessonSession()
            }
        case .text:
            if let text = daily.today {
                DailyReadingView(text: text).onAppear { LessonStore.mark(.text) }
            }
        case .speak:
            SpeakRepeatView(count: 3, onFinish: { LessonStore.mark(.speak) })
        }
    }
}

/// Today's plan (design: https://claude.ai/artifact/UR4SupytQYdc9vFCF9RZgu): the unit step, words and review,
/// today's text and speaking in one card, ticked off in order; the button always names the next step.
/// When everything is done it shrinks to one line until tomorrow.
struct TodayPlanCard: View {
    @EnvironmentObject private var daily: DailyModel
    @ObservedObject var model: A1Model
    @State private var refresh = 0

    private struct Step: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let done: Bool
        let route: AppRoute
    }

    private var level: String { UnitBank.levels.contains(daily.level) ? daily.level : (UnitBank.levels.first ?? "A1") }
    private var unit: LearningUnit? { UnitStore.current(level) }

    private var steps: [Step] {
        let lesson = LessonStore.done()
        var list: [Step] = []
        if let unit, let next = UnitStore.nextStep(unit.id) ?? (UnitStore.steppedToday ? UnitStep.allCases.last : nil) {
            list.append(Step(id: "unit", icon: next.icon, title: t("plan.unitStep", next.title),
                             subtitle: "\(unit.level) · " + t("path.unit", unit.number) + " · " + unit.title.text,
                             done: UnitStore.steppedToday, route: .unit(unit.id)))
        }
        let due = model.ready ? model.dueReviewIDs.count : 0
        list.append(Step(id: "practice", icon: LessonStep.practice.icon, title: t("lesson.step.practice"),
                         subtitle: due > 0 ? t("plan.reviewDue", due) : t("lesson.practiceSub"),
                         done: lesson.contains(LessonStep.practice.rawValue), route: .lessonStep(LessonStep.practice.rawValue)))
        if let text = daily.today {
            list.append(Step(id: "text", icon: LessonStep.text.icon, title: t("lesson.step.text"), subtitle: text.title,
                             done: lesson.contains(LessonStep.text.rawValue), route: .lessonStep(LessonStep.text.rawValue)))
        }
        list.append(Step(id: "speak", icon: LessonStep.speak.icon, title: t("lesson.step.speak"), subtitle: t("lesson.speakSub"),
                         done: lesson.contains(LessonStep.speak.rawValue), route: .lessonStep(LessonStep.speak.rawValue)))
        return list
    }

    var body: some View {
        let steps = self.steps
        let finished = steps.filter(\.done).count
        Group {
            if let next = steps.first(where: { !$0.done }) {
                planCard(steps, finished: finished, next: next)
            } else {
                doneCard
            }
        }
        .id(refresh)
        .onAppear { markTextIfRead() }
        .onReceive(NotificationCenter.default.publisher(for: LessonStore.changed)) { _ in refresh += 1 }
        .onReceive(NotificationCenter.default.publisher(for: UnitStore.changed)) { _ in refresh += 1 }
        .onReceive(NotificationCenter.default.publisher(for: DailySavedState.changed)) { _ in markTextIfRead() }
    }

    private func planCard(_ steps: [Step], finished: Int, next: Step) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text((t("plan.title") + " · " + level).uppercased())
                        .font(.caption.weight(.bold)).kerning(0.5).foregroundColor(DS.onNightMuted)
                    Text(unit?.title.text ?? t("lesson.title"))
                        .font(.system(size: 21, weight: .heavy)).foregroundColor(DS.onNight)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("\(finished)/\(steps.count)").font(.subheadline.weight(.bold).monospacedDigit()).foregroundColor(DS.onNightMuted)
            }
            ProgressView(value: Double(finished), total: Double(max(1, steps.count))).tint(DS.gold)
            VStack(spacing: 2) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    NavigationLink(value: step.route) { row(step, number: index + 1, isNext: step.id == next.id) }
                        .buttonStyle(.plain)
                }
            }
            NavigationLink(value: next.route) {
                HStack(spacing: 8) {
                    Text(t("plan.next", next.title)).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.onGold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DS.gold, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(_ step: Step, number: Int, isNext: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(step.done ? DS.success : Color.white.opacity(isNext ? 0.14 : 0.06))
                if isNext { Circle().stroke(DS.gold, lineWidth: 2) }
                if step.done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundColor(.white)
                } else {
                    Text("\(number)").font(.system(size: 12, weight: .heavy)).foregroundColor(isNext ? DS.gold : DS.onNightMuted)
                }
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(.system(size: 15, weight: isNext ? .bold : .semibold))
                    .foregroundColor(step.done ? DS.onNightMuted : DS.onNight)
                    .strikethrough(step.done, color: DS.onNightMuted)
                    .lineLimit(1)
                Text(step.subtitle).font(.caption).foregroundColor(DS.onNightMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: step.icon).font(.system(size: 13, weight: .semibold)).foregroundColor(DS.onNightMuted)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.done ? "✓" : "")
    }

    private var doneCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(DS.success, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t("plan.doneTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                Text(t("lesson.doneSub")).font(.caption).foregroundColor(DS.muted)
            }
            Spacer(minLength: 0)
            if let unit {
                NavigationLink(value: AppRoute.unit(unit.id)) {
                    Text(t("plan.more")).font(.caption.weight(.bold)).foregroundColor(DS.accent)
                }
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// The text step counts once today's text was opened (also from its island).
    private func markTextIfRead() {
        if let text = daily.today, daily.isRead(text) { LessonStore.mark(.text) }
    }
}

/// The games on Today as a grid of square picture cards, two side by side (design:
/// https://claude.ai/artifact/7FU2y3Sw4ewThDTzB3ruCg): one colour per game, Lina in the middle in a pose of the
/// game (Resources/Images), only the game's name on top. Open games first (slow opening for beginners).
struct TodayGames: View {
    @ObservedObject var model: A1Model
    @State private var showLazySetup = false
    @State private var lazyConfig: LazyConfig?
    /// Something opened since the last visit (slow opening for beginners): Lina says so once.
    @State private var fresh: UnlockFeature?

    private struct Game: Identifiable {
        let feature: UnlockFeature
        let title: String
        let color: Color
        let picture: String
        var id: String { feature.rawValue }
    }

    private var games: [Game] {
        var list = [
            Game(feature: .wordRun, title: t("run.title"), color: Color(red: 0.78, green: 0.20, blue: 0.23), picture: "lina-run-2"),
            Game(feature: .match, title: t("practice.match"), color: Color(red: 0.18, green: 0.36, blue: 0.92), picture: "lina-dance-4"),
        ]
        if LinaAI.isAvailable {
            list.append(Game(feature: .linaChat, title: t("lina.chatTitle"), color: Color(red: 0.48, green: 0.31, blue: 0.84), picture: "lina-dance-5"))
        }
        if !SongBank.songs(model.level).isEmpty {
            list.append(Game(feature: .songs, title: t("song.title"), color: Color(red: 0.76, green: 0.40, blue: 0.06), picture: "lina-dance-6"))
        }
        list.append(Game(feature: .lazy, title: t("lazy.title"), color: Color(red: 0.08, green: 0.48, blue: 0.25), picture: "lina-sleep"))
        if PhotoCapture.available {
            list.append(Game(feature: .camera, title: t("cam.title"), color: Color(red: 0.05, green: 0.49, blue: 0.53), picture: "lina-photo"))
        }
        // Open ones first, the order otherwise kept.
        return list.filter { Unlocks.isOpen($0.feature) } + list.filter { !Unlocks.isOpen($0.feature) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fresh { UnlockedBanner(feature: fresh).transition(.opacity) }
            Text(t("plan.games").uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(games) { game in
                    UnlockGate(feature: game.feature) { link(game) }
                }
            }
            .buttonStyle(.pressable)
        }
        .disabled(!model.ready)
        .onAppear { if fresh == nil { fresh = Unlocks.takeNew() } }
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

    @ViewBuilder
    private func link(_ game: Game) -> some View {
        switch game.feature {
        case .lazy: Button { showLazySetup = true } label: { GameCard(game: game.feature, title: game.title, color: game.color, picture: game.picture, isNew: fresh == game.feature) }
        case .wordRun: NavigationLink(value: A1Route.wordRun) { card(game) }
        case .match: NavigationLink(value: A1Route.match(nil)) { card(game) }
        case .linaChat: NavigationLink(value: A1Route.linaChat) { card(game) }
        case .songs: NavigationLink(value: A1Route.songs) { card(game) }
        case .camera: NavigationLink(value: A1Route.camera) { card(game) }
        case .exam: EmptyView()
        }
    }

    private func card(_ game: Game) -> GameCard {
        GameCard(game: game.feature, title: game.title, color: game.color, picture: game.picture, isNew: fresh == game.feature)
    }
}

/// One square game card: the colour, Lina, the game's few decorations and its name.
private struct GameCard: View {
    let game: UnlockFeature
    let title: String
    let color: Color
    let picture: String
    let isNew: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                let side = proxy.size.width
                ZStack(alignment: .bottom) {
                    decorations(side)
                    if let image = UIImage(named: picture) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: side * (game == .lazy ? 0.70 : 0.74))
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 5)
                    }
                }
                .frame(width: side, height: side, alignment: .bottom)
            }
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isNew {
                    Text(t("unlock.newChip"))
                        .font(.system(size: 10, weight: .heavy)).kerning(0.6)
                        .foregroundColor(DS.ink)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.92), in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .onAppear { if game == .camera && !reduceMotion { blink = true } }
    }

    /// Small things that tell the game apart: a track, word cards, speech bubbles, notes, "z z", a viewfinder.
    @ViewBuilder
    private func decorations(_ side: CGFloat) -> some View {
        switch game {
        case .wordRun:
            Capsule().fill(Color.white.opacity(0.4)).frame(width: side * 0.84, height: 3).padding(.bottom, side * 0.06)
        case .match:
            HStack {
                miniCard(Text("der").foregroundColor(DS.der) + Text(" Tisch").foregroundColor(DS.ink), side: side)
                    .rotationEffect(.degrees(-10))
                Spacer()
                miniCard(Text("die").foregroundColor(DS.die) + Text(" Uhr").foregroundColor(DS.ink), side: side)
                    .rotationEffect(.degrees(9))
            }
            .padding(.horizontal, side * 0.05)
            .padding(.bottom, side * 0.11)
        case .linaChat:
            ZStack {
                bubble("Hallo!", fill: .white).offset(x: side * 0.27, y: -side * 0.36)
                bubble("Wie geht's?", fill: DS.gold).offset(x: -side * 0.24, y: -side * 0.18)
            }
            .frame(width: side, height: side, alignment: .bottom)
        case .songs:
            ZStack {
                Text("♪").offset(x: -side * 0.34, y: -side * 0.42)
                Text("♫").offset(x: side * 0.34, y: -side * 0.52)
            }
            .font(.system(size: 19, weight: .heavy)).foregroundColor(.white.opacity(0.9))
            .frame(width: side, height: side, alignment: .bottom)
        case .lazy:
            Text("z z").font(.system(size: 15, weight: .heavy)).foregroundColor(.white.opacity(0.9))
                .offset(x: side * 0.30, y: -side * 0.48)
                .frame(width: side, height: side, alignment: .bottom)
        case .camera:
            Viewfinder().stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: side * 0.56, height: side * 0.40)
                .overlay(alignment: .topTrailing) { recordingDot.padding(7) }
                .padding(.bottom, side * 0.20)
        case .exam:
            EmptyView()
        }
    }

    private func miniCard(_ text: Text, side: CGFloat) -> some View {
        text.font(.system(size: 10.5, weight: .heavy))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: side * 0.28, height: side * 0.32)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }

    private func bubble(_ text: String, fill: Color) -> some View {
        Text(text).font(.system(size: 10.5, weight: .heavy)).foregroundColor(DS.ink)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// A red recording dot that blinks (still with Reduce Motion).
    private var recordingDot: some View {
        Circle().fill(Color(red: 1, green: 0.23, blue: 0.19)).frame(width: 10, height: 10)
            .opacity(blink ? 0.2 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: blink)
            .accessibilityHidden(true)
    }
}

/// The four corners of a camera viewfinder.
private struct Viewfinder: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * 0.18
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
        }
        return path
    }
}
