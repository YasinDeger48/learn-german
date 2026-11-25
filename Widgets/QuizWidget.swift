import AppIntents
import SwiftUI
import WidgetKit

// E · Mini quiz: der / die / das played right on the Home Screen or the Lock Screen.
// State lives in the extension's own defaults: today's score, the run of right answers and the open question.

enum QuizState {
    private static var d: UserDefaults { .standard }
    static let indexKey = "quizIndex"
    static let pickedKey = "quizPicked"
    static let answerKey = "quizAnswer"
    static let dayKey = "quizDay"
    static let rightKey = "quizRight"
    static let totalKey = "quizTotal"
    static let comboKey = "quizCombo"

    static func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// A new day starts a new score.
    static func roll() {
        let now = today()
        guard d.string(forKey: dayKey) != now else { return }
        d.set(now, forKey: dayKey)
        d.set(0, forKey: rightKey)
        d.set(0, forKey: totalKey)
    }

    static var index: Int { d.integer(forKey: indexKey) }
    static var picked: String? { d.string(forKey: pickedKey).flatMap { $0.isEmpty ? nil : $0 } }
    static var right: Int { roll(); return d.integer(forKey: rightKey) }
    static var total: Int { roll(); return d.integer(forKey: totalKey) }
    static var combo: Int { d.integer(forKey: comboKey) }

    /// The timeline stores the right article of the word on screen, so the answer intent can check it.
    static func show(answer: String) { d.set(answer, forKey: answerKey) }

    static func answer(_ article: String) {
        roll()
        guard picked == nil else { return }
        let right = article == d.string(forKey: answerKey)
        d.set(article, forKey: pickedKey)
        d.set(d.integer(forKey: totalKey) + 1, forKey: totalKey)
        if right {
            d.set(d.integer(forKey: rightKey) + 1, forKey: rightKey)
            d.set(d.integer(forKey: comboKey) + 1, forKey: comboKey)
        } else {
            d.set(0, forKey: comboKey)
        }
    }

    static func next() {
        d.set(index + 1, forKey: indexKey)
        d.set("", forKey: pickedKey)
    }
}

struct AnswerArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Answer"

    @Parameter(title: "Article")
    var article: String

    init() {}

    init(article: String) {
        self.article = article
    }

    func perform() async throws -> some IntentResult {
        QuizState.answer(article)
        return .result()
    }
}

struct NextQuizIntent: AppIntent {
    static var title: LocalizedStringResource = "Next question"

    func perform() async throws -> some IntentResult {
        QuizState.next()
        return .result()
    }
}

struct QuizEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord
    let picked: String?
    let right: Int
    let total: Int
    let combo: Int
    let level: String
    let turkish: Bool

    var answered: Bool { picked != nil }
    var correct: Bool { picked == word.a }
}

struct QuizProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuizEntry {
        QuizEntry(date: Date(), word: WordBank.sample, picked: nil, right: 0, total: 0, combo: 0, level: "A1", turkish: WordBank.turkish)
    }

    func snapshot(for configuration: LevelConfigIntent, in context: Context) async -> QuizEntry {
        entry(configuration)
    }

    func timeline(for configuration: LevelConfigIntent, in context: Context) async -> Timeline<QuizEntry> {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return Timeline(entries: [entry(configuration)], policy: .after(tomorrow))
    }

    private func entry(_ configuration: LevelConfigIntent) -> QuizEntry {
        let level = configuration.level.rawValue
        let word = WordBank.word(level: level, index: QuizState.index, nounsOnly: true)
        QuizState.show(answer: word.a)
        return QuizEntry(date: Date(), word: word, picked: QuizState.picked, right: QuizState.right, total: QuizState.total,
                         combo: QuizState.combo, level: level, turkish: WordBank.turkish)
    }
}

struct QuizView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuizEntry

    private var tr: Bool { entry.turkish }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: lockScreen
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular {
                Color.clear
            } else if entry.answered {
                entry.correct ? Palette.der : Palette.night
            } else {
                Color.white
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text(entry.answered ? (entry.correct ? "RICHTIG!" : (tr ? "DOĞRUSU" : "IT IS")) : "DER, DIE, DAS?")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(entry.answered ? .white.opacity(0.85) : Palette.muted)
            Spacer()
            if entry.answered && entry.correct {
                Text("+3 XP").font(.system(size: 11, weight: .heavy)).foregroundColor(Palette.gold)
            } else if entry.combo > 1 {
                Text("\(entry.combo)×").font(.system(size: 11, weight: .heavy)).foregroundColor(.orange)
            }
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.answered {
                Text(entry.word.full).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(entry.word.meaning(tr)).font(.system(size: 12)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
            } else {
                (Text("___ ").foregroundColor(Color(white: 0.78)) + Text(entry.word.d).foregroundColor(Palette.night))
                    .font(.system(size: 24, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(entry.word.meaning(tr)).font(.system(size: 12)).foregroundColor(Palette.muted).lineLimit(1)
            }
        }
    }

    private func articleButtons(height: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(["der", "die", "das"], id: \.self) { article in
                Button(intent: AnswerArticleIntent(article: article)) {
                    Text(article)
                        .font(.system(size: height > 36 ? 15 : 13, weight: .heavy))
                        .foregroundColor(Palette.article(article))
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(Palette.article(article).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var afterButtons: some View {
        HStack(spacing: 6) {
            Button(intent: NextQuizIntent()) {
                Text(WidgetText.next(tr))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Palette.night)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Palette.gold, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            question
            Spacer(minLength: 0)
            if entry.answered { afterButtons } else { articleButtons(height: 34) }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 0)
                question
                if !entry.answered {
                    Text("„\(entry.word.x)“").font(.system(size: 11)).foregroundColor(Palette.muted).lineLimit(1).padding(.top, 2)
                }
                Spacer(minLength: 0)
                if entry.answered { afterButtons } else { articleButtons(height: 40) }
            }
            VStack(spacing: 3) {
                Text("\(entry.right)/\(entry.total)").font(.system(size: 24, weight: .heavy)).monospacedDigit()
                    .foregroundColor(entry.answered ? .white : Palette.night)
                Text(tr ? "bugün doğru" : "right today").font(.system(size: 10)).multilineTextAlignment(.center)
                    .foregroundColor(entry.answered ? .white.opacity(0.7) : Palette.muted)
                Text("+\(entry.right * 3) XP").font(.system(size: 12, weight: .heavy)).foregroundColor(entry.answered ? Palette.gold : Palette.der)
                    .padding(.top, 4)
            }
            .frame(width: 70)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.answered {
                Text((entry.correct ? "✓ " : "✗ ") + entry.word.full).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
                Button(intent: NextQuizIntent()) {
                    Text(WidgetText.next(tr)).font(.caption.weight(.bold)).frame(maxWidth: .infinity, minHeight: 24)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("___ \(entry.word.d)").font(.headline).lineLimit(1).minimumScaleFactor(0.6).widgetAccentable()
                HStack(spacing: 4) {
                    ForEach(["der", "die", "das"], id: \.self) { article in
                        Button(intent: AnswerArticleIntent(article: article)) {
                            Text(article).font(.caption.weight(.heavy)).frame(maxWidth: .infinity, minHeight: 24)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct QuizWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyQuiz", intent: LevelConfigIntent.self, provider: QuizProvider()) { QuizView(entry: $0) }
            .configurationDisplayName(WordBank.turkish ? "der, die, das? · Mini quiz" : "der, die, das? · Mini quiz")
            .description(WordBank.turkish ? "Ana ekrandan ya da kilit ekranından artikel quiz\u{2019}i." : "An article quiz right on your Home Screen or Lock Screen.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
