import SwiftUI
import UIKit

// MARK: - Quiz

struct A1QuizView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var pro: ProStore
    @ObservedObject private var ads = AdsManager.shared
    let title: String
    var exam = false
    var review = false
    var resetMode: A1Mode? = nil
    var onFinish: ((Int, Int) -> Void)? = nil
    /// Reading quizzes are always free: they do not count toward the daily limit.
    var free = false
    let makeSession: () -> [A1Question]

    init(title: String, exam: Bool = false, review: Bool = false, resetMode: A1Mode? = nil, free: Bool = false,
         onFinish: ((Int, Int) -> Void)? = nil, makeSession: @escaping () -> [A1Question]) {
        self.title = title
        self.free = free
        self.exam = exam
        self.review = review
        self.resetMode = resetMode
        self.onFinish = onFinish
        self.makeSession = makeSession
    }

    @State private var session: [A1Question] = []
    @State private var started = false
    @State private var index = 0
    @State private var picked: String?
    @State private var typed = ""
    @State private var order: [Int] = []
    @State private var revealed = false
    @State private var wasCorrect = false
    @State private var score = 0
    @State private var missed: [A1Question] = []
    @State private var showText = false
    @State private var examSaved = false
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var startedAt = Date()
    @State private var newBadges: [Badge] = []
    @State private var celebration: Celebration?
    @Environment(\.dismiss) private var dismiss
    /// Today's free questions are used up (free version only).
    @State private var limitReached = false
    @State private var askFinish = false
    @FocusState private var typingFocused: Bool

    var body: some View {
        Group {
            if !started {
                ProgressView()
            } else if limitReached {
                DailyLimitView(answered: index, correct: score, streak: StreakStore.shared.current,
                               level: model.level, readiness: model.readiness,
                               onWatchAd: ads.rewardedReady ? watchAd : nil)
            } else if session.isEmpty {
                emptyState
            } else if index >= session.count {
                summary
            } else {
                question(session[index])
            }
        }
        .background(DS.ground.ignoresSafeArea())
        .tint(DS.accent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { A1Speaker.shared.stop() }
        .sheet(item: $celebration) { CelebrationView(badges: $0.badges) }
        .onAppear {
            if !started {
                session = makeSession()
                startedAt = Date()
                started = true
                pro.refreshQuota()
                limitReached = !free && !pro.canPractice
                if !limitReached { playIfNeeded() }
            }
        }
        .onChange(of: pro.isPro) { isPro in
            if isPro && limitReached {
                limitReached = false
                playIfNeeded()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            LinaAvatar(size: 96)
            Text(review ? t("quiz.noMistakes") : t("quiz.allSeen"))
                .font(DS.display(24, heavy: false))
                .multilineTextAlignment(.center)
            if let mode = resetMode {
                Text(t("quiz.resetHint"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(t("quiz.reset")) {
                    model.reset(mode)
                    restart()
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .padding(24)
    }

    private var perfect: Bool { !session.isEmpty && score == session.count && session.count >= 5 }

    private var sessionXP: Int {
        score * XP.correct * (review ? XP.mistakeMultiplier : 1) + (session.count - score) * XP.wrong
            + (perfect ? XP.perfectBonus : 0)
    }

    private var summary: some View {
        let total = session.count
        let points = total == 0 ? 0 : Int((Double(score) / Double(total) * 100).rounded())
        let seconds = Int(Date().timeIntervalSince(startedAt))
        return ScrollView {
            VStack(spacing: 14) {
                LinaAvatar(size: 104)
                    .clipShape(Circle())
                    .padding(.top, 12)
                Text(summaryTitle(points: points, total: total))
                    .font(DS.display(30))
                    .multilineTextAlignment(.center)
                Text(summarySubtitle(points: points))
                    .font(.subheadline)
                    .foregroundColor(exam ? (points >= 60 ? DS.success : DS.error) : DS.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    summaryTile("+\(sessionXP)", "XP", DS.accent)
                    summaryTile("\(bestCombo)×", t("done.combo"), .orange)
                    summaryTile(String(format: "%d:%02d", seconds / 60, seconds % 60), t("done.time"), DS.success)
                }
                goalCard
                ForEach(newBadges) { badge in
                    HStack(spacing: 12) {
                        BadgeIcon(badge: badge, earned: true, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("done.newBadge")).font(.caption.weight(.semibold)).foregroundColor(DS.goldDeep)
                            Text(badge.title).font(.system(size: 16, weight: .bold))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(DS.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("quiz.missedSection")).font(.headline)
                        ForEach(missed) { q in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.prompt).font(.subheadline)
                                Text("✓ \(q.answer)").font(.subheadline.bold()).foregroundColor(DS.success)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                VStack(spacing: 10) {
                    Button {
                        restart()
                    } label: {
                        Text(onFinish == nil ? t("quiz.continueNew") : t("quiz.again"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Button(t("done.finish")) { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            if !examSaved {
                examSaved = true
                if exam { model.saveExam(points) }
                if perfect {
                    StreakStore.shared.addXP(XP.perfectBonus)
                    StreakStore.shared.addPerfectRound()
                }
                onFinish?(score, total)
                BadgeStore.shared.refresh()
                newBadges = BadgeStore.shared.takePending()
                // A streak milestone gets the big celebration; other badges stay on this screen.
                if newBadges.contains(where: { $0.kind == .streak && BadgeStore.milestones.contains($0.target) }) {
                    celebration = Celebration(badges: newBadges)
                } else {
                    ads.quizFinished(isPro: pro.isPro)
                }
            }
        }
    }

    private func summaryTitle(points: Int, total: Int) -> String {
        if exam { return t("quiz.points", points) }
        if perfect { return "Perfekt! \(score)/\(total)" }
        if points >= 70 { return "Gut gemacht! \(score)/\(total)" }
        return "Weiter so! \(score)/\(total)"
    }

    private func summarySubtitle(points: Int) -> String {
        if exam { return points >= 60 ? t("quiz.passed") : t("quiz.notPassed") }
        if perfect { return t("done.perfectSub", XP.perfectBonus) }
        return missed.isEmpty ? t("done.sub") : t("done.subMistakes", missed.count)
    }

    private func summaryTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(color).monospacedDigit()
            Text(label).font(.caption).foregroundColor(DS.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var goalCard: some View {
        let store = StreakStore.shared
        return HStack(spacing: 14) {
            GoalRing(progress: store.goalProgress, size: 56, lineWidth: 7,
                     color: store.goalReachedToday ? DS.success : DS.accent) {
                if store.goalReachedToday {
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy)).foregroundColor(DS.success)
                } else {
                    Text("\(Int(store.goalProgress * 100))%").font(.system(size: 12, weight: .bold))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(store.goalReachedToday ? t("goal.done") : t("goal.left", store.goal - store.xpToday))
                    .font(.system(size: 16, weight: .bold))
                Text("\(store.xpToday) / \(store.goal) XP · " + t("today.streak", store.current))
                    .font(.footnote).foregroundColor(DS.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func restart() {
        session = makeSession()
        index = 0
        score = 0
        missed = []
        examSaved = false
        combo = 0
        bestCombo = 0
        startedAt = Date()
        resetAnswer()
        limitReached = !free && !pro.canPractice
        if !limitReached { playIfNeeded() }
    }

    /// Rewarded ad on the limit screen: +10 questions for today, then the quiz goes on.
    private func watchAd() {
        ads.showRewarded {
            pro.addBonus(10)
            limitReached = false
            playIfNeeded()
        }
    }

    private func resetAnswer() {
        picked = nil
        typed = ""
        order = []
        revealed = false
        wasCorrect = false
        showText = false
    }

    private func playIfNeeded() {
        guard index < session.count else { return }
        let q = session[index]
        guard q.dialog != nil || q.speakFirst != nil else { return }
        let times = q.mode == .listen || q.mode == .hoeren ? 2 : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { play(q, times: times) }
    }

    private func play(_ q: A1Question, slow: Bool = false, times: Int = 1) {
        if let dialog = q.dialog {
            A1Speaker.shared.play(dialog, slow: slow, times: times)
        } else if let text = q.speakFirst {
            A1Speaker.shared.say(text, slow: slow, times: times)
        }
    }

    private func question(_ q: A1Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView(value: Double(index), total: Double(session.count))
                HStack {
                    Text(t("quiz.progress", index + 1, session.count)).font(DS.text(12).monospacedDigit())
                    Spacer()
                    Text(q.label).font(.caption).lineLimit(1)
                }
                .foregroundStyle(.secondary)
                promptCard(q)
                switch q.kind {
                case .choice: choiceButtons(q)
                case .order: orderArea(q)
                case .typing: typingArea(q)
                }
                if revealed { feedback(q) }
                Button(role: .destructive) {
                    askFinish = true
                } label: {
                    Label(t("done.finish"), systemImage: "flag.checkered")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(t("quiz.finishAsk"), isPresented: $askFinish, titleVisibility: .visible) {
            Button(t("done.finish"), role: .destructive) { finishNow() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(exam ? t("quiz.finishExamNote") : t("quiz.finishNote"))
        }
    }

    /// Ends the round early. In an exam the unanswered questions count as wrong (the score stays out of the full round);
    /// in practice the round is cut to the answered questions. Nothing answered yet: just leave.
    private func finishNow() {
        A1Speaker.shared.stop()
        typingFocused = false
        let answered = min(session.count, revealed ? index + 1 : index)
        if exam {
            missed += session[answered...]
        } else if answered == 0 {
            dismiss()
            return
        } else {
            session = Array(session.prefix(answered))
        }
        resetAnswer()
        index = session.count
    }

    private func promptCard(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.mode.title).font(DS.text(12, .semibold)).foregroundStyle(DS.muted)
            if let context = q.context {
                DisclosureGroup(isExpanded: $showText) {
                    Text(context).font(.callout).padding(.top, 4)
                } label: {
                    Label(t("quiz.readText"), systemImage: "doc.text")
                }
                .onAppear { showText = true }
            }
            if q.dialog != nil || q.speakFirst != nil {
                HStack {
                    Button {
                        play(q)
                    } label: {
                        Label(t("common.listen"), systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        play(q, slow: true)
                    } label: {
                        Label(t("common.slow"), systemImage: "tortoise.fill")
                    }
                    .buttonStyle(.bordered)
                }
                if q.mode == .listen || q.mode == .hoeren {
                    Text(t("quiz.playsTwice"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(q.prompt)
                .font(q.prompt.count < 40 ? DS.display(28, heavy: false) : DS.display(21, heavy: false))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = q.detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deschlyCard(padding: 18)
    }

    private func choiceButtons(_ q: A1Question) -> some View {
        VStack(spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                Button {
                    guard !revealed else { return }
                    picked = option
                    check(q, correct: option == q.answer)
                } label: {
                    HStack {
                        Text(option)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(q.mode == .artikel ? a1ArticleColor(option) : Color.primary)
                            .font(q.mode == .artikel ? Font.title3.bold() : Font.body)
                        Spacer()
                        if revealed && option == q.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.success)
                        } else if revealed && option == picked {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DS.error)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(optionBackground(q, option), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(optionBorder(q, option), lineWidth: revealed && (option == q.answer || option == picked) ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func optionBackground(_ q: A1Question, _ option: String) -> Color {
        if revealed && option == q.answer { return DS.successSoft }
        if revealed && option == picked { return DS.errorSoft }
        return DS.surface
    }

    private func optionBorder(_ q: A1Question, _ option: String) -> Color {
        if revealed && option == q.answer { return DS.success }
        if revealed && option == picked { return DS.error }
        return DS.hairline
    }

    private func orderArea(_ q: A1Question) -> some View {
        let chosen = order.map { q.options[$0] }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 12) {
            Text(chosen.isEmpty ? t("quiz.tapWords") : chosen)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(12)
                .deschlyCard(padding: 2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { item in
                    let used = order.contains(item.offset)
                    Button {
                        guard !revealed else { return }
                        if let position = order.firstIndex(of: item.offset) {
                            order.remove(at: position)
                        } else {
                            order.append(item.offset)
                        }
                    } label: {
                        Text(item.element)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(used ? DS.chip : DS.surface, in: Capsule())
                            .overlay(Capsule().stroke(DS.hairline, lineWidth: used ? 0 : 1))
                            .foregroundStyle(used ? Color.secondary : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !revealed {
                HStack {
                    Button(t("quiz.clear")) { order = [] }
                        .buttonStyle(.bordered)
                        .disabled(order.isEmpty)
                    Button {
                        check(q, correct: chosen == q.answer)
                    } label: {
                        Text(t("quiz.check")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(order.count != q.options.count)
                }
            }
        }
    }

    private func typingArea(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(t("quiz.typeGerman"), text: $typed, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.hairline, lineWidth: 1))
                .focused($typingFocused)
                .disabled(revealed)
            HStack(spacing: 6) {
                ForEach(["ä", "ö", "ü", "ß", "Ä", "Ö", "Ü"], id: \.self) { letter in
                    Button(letter) { typed += letter }
                        .buttonStyle(.bordered)
                        .disabled(revealed)
                }
            }
            if !revealed {
                Button {
                    typingFocused = false
                    let answer = a1Normalize(typed)
                    let ok = ([q.answer] + q.accepted).contains { a1Normalize($0) == answer }
                    picked = typed
                    check(q, correct: ok)
                } label: {
                    Text(t("quiz.check")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func check(_ q: A1Question, correct: Bool) {
        revealed = true
        wasCorrect = correct
        if correct {
            score += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
        } else {
            missed.append(q)
            combo = 0
        }
        model.record(q, correct: correct)
        if review && correct { StreakStore.shared.addXP(XP.correct * (XP.mistakeMultiplier - 1)) }
        if !free { pro.countAnswer() }
        AnswerSound.play(correct: correct)
    }

    private func feedback(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LinaAvatar(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wasCorrect ? linaPraise : "Kein Problem!")
                        .font(DS.display(21, heavy: false))
                        .foregroundStyle(wasCorrect ? DS.success : DS.error)
                    Text(wasCorrect ? t("quiz.correct") : t("quiz.answerIs", q.answer))
                        .font(DS.text(14, .medium))
                        .foregroundStyle(DS.ink)
                }
            }
            if let explanation = q.explanation {
                Text(explanation).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if q.dialog != nil || q.speakAfter != nil || q.speakFirst != nil {
                    Button {
                        if let speak = q.speakAfter {
                            A1Speaker.shared.say(speak)
                        } else {
                            play(q)
                        }
                    } label: {
                        Label(t("common.listen"), systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    A1Speaker.shared.stop()
                    index += 1
                    resetAnswer()
                    // An exam that has started is not cut off; other quizzes stop at the daily limit.
                    if !free && !exam && index < session.count && !pro.canPractice {
                        limitReached = true
                    } else {
                        playIfNeeded()
                    }
                } label: {
                    Text(index + 1 < session.count ? t("quiz.next") : t("quiz.result")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wasCorrect ? DS.successSoft : DS.errorSoft, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }

    /// Lina's short German praise, varied so it does not feel robotic.
    private var linaPraise: String {
        let lines = ["Super gemacht!", "Richtig!", "Sehr gut!", "Genau!", "Toll!"]
        return lines[(index + score) % lines.count]
    }
}
