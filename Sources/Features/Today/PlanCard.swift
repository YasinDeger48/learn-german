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

/// The games on Today as one row that scrolls sideways (all of them are also in Practice).
struct TodayGames: View {
    @ObservedObject var model: A1Model
    @State private var showLazySetup = false
    @State private var lazyConfig: LazyConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("plan.games").uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink(value: A1Route.wordRun) { tile("figure.run", DS.die, t("run.title")) }
                    NavigationLink(value: A1Route.match(nil)) { tile("square.grid.3x3.fill", DS.der, t("practice.match")) }
                    if LinaAI.isAvailable {
                        NavigationLink(value: A1Route.linaChat) { tile("bubble.left.and.bubble.right.fill", .purple, t("lina.chatTitle")) }
                    }
                    if !SongBank.songs(model.level).isEmpty {
                        NavigationLink(value: A1Route.songs) { tile("music.mic", .orange, t("song.title")) }
                    }
                    Button { showLazySetup = true } label: { tile("sofa.fill", DS.das, t("lazy.title")) }
                    if PhotoCapture.available {
                        NavigationLink(value: A1Route.camera) { tile("camera.fill", .teal, t("cam.title")) }
                    }
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, DS.gutter)
            }
            .padding(.horizontal, -DS.gutter)
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

    private func tile(_ icon: String, _ color: Color, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer(minLength: 16)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 118, height: 112, alignment: .topLeading)
        .background(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
