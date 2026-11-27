import SwiftUI

/// Today's lesson: the app puts the day together, the learner only taps Start.
/// 1. words and review (new words plus what is due), 2. the text of the day, 3. three sentences to say aloud.
enum LessonStep: String, CaseIterable, Identifiable {
    case practice, text, speak

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .practice: return "rectangle.stack.fill"
        case .text: return "doc.richtext.fill"
        case .speak: return "mic.fill"
        }
    }
}

enum LessonStore {
    static let changed = Notification.Name("LessonChanged")
    static let bonus = 15

    private static func key(_ date: Date = Date()) -> String { "lesson.\(A1Model.dayString(date))" }

    static func done() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key()) ?? []) }

    /// All of today's steps are done: Today hides the lesson card until tomorrow.
    static var allDone: Bool { done().count == LessonStep.allCases.count }

    /// Marks a step; when the third step is done the bonus XP is given once.
    static func mark(_ step: LessonStep) {
        var steps = done()
        guard !steps.contains(step.rawValue) else { return }
        steps.insert(step.rawValue)
        UserDefaults.standard.set(Array(steps), forKey: key())
        if steps.count == LessonStep.allCases.count {
            StreakStore.shared.addXP(bonus)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

extension A1Model {
    /// 15 questions: up to 5 new word questions, then due reviews, then the adaptive mix.
    func lessonSession(count: Int = 15) -> [A1Question] {
        let wordModes: Set<A1Mode> = [.wordToTr, .trToWord, .artikel]
        let fresh = questions.filter { wordModes.contains($0.mode) && !state.seen.contains($0.id) && !A1Model.isCore($0) }
            .shuffled().prefix(5)
        var result = Array(fresh)
        var used = Set(result.map(\.id))
        for id in dueReviewIDs where result.count < 10 && !used.contains(id) {
            if let q = byID[id] { result.append(q); used.insert(id) }
        }
        for q in session(count: count * 2) where result.count < count && !used.contains(q.id) {
            result.append(q)
            used.insert(q.id)
        }
        return result.shuffled()
    }
}

/// The lesson page: the three steps in order.
struct LessonView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    @State private var done = LessonStore.done()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("lesson.intro")).font(.subheadline).foregroundColor(DS.muted)
                VStack(spacing: 0) {
                    stepRow(.practice, subtitle: t("lesson.practiceSub")) {
                        A1QuizView(title: t("lesson.step.practice"), onFinish: { _, _ in LessonStore.mark(.practice) }) {
                            model.lessonSession()
                        }
                    }
                    Divider().padding(.leading, 60)
                    if let text = daily.today {
                        stepRow(.text, subtitle: text.title) {
                            DailyReadingView(text: text).onAppear { LessonStore.mark(.text) }
                        }
                    }
                    Divider().padding(.leading, 60)
                    stepRow(.speak, subtitle: t("lesson.speakSub")) {
                        SpeakRepeatView(count: 3, onFinish: { LessonStore.mark(.speak) })
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if done.count == LessonStep.allCases.count {
                    Label(t("lesson.bonus", LessonStore.bonus), systemImage: "sparkles")
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.goldDeep)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DS.gold.opacity(0.18), in: Capsule())
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("lesson.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: LessonStore.changed)) { _ in done = LessonStore.done() }
    }

    private func stepRow<Destination: View>(_ step: LessonStep, subtitle: String,
                                            @ViewBuilder destination: @escaping () -> Destination) -> some View {
        let finished = done.contains(step.rawValue)
        return NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: finished ? "checkmark" : step.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(finished ? .white : DS.ink)
                    .frame(width: 36, height: 36)
                    .background(finished ? DS.success : DS.chip, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("lesson.step.\(step.rawValue)")).font(.system(size: 16, weight: .semibold)).foregroundColor(DS.ink)
                    Text(subtitle).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
