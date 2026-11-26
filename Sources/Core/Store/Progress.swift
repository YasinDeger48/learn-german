import Foundation
import Combine

// MARK: - Progress

struct A1SavedState: Codable {
    var seen: Set<String> = []
    var correct: Set<String> = []
    var wrong: [String] = []
    var bestSprint = 0
    var exams: [Int] = []
    var streak = 0
    var lastDay = ""
    var today = 0

    static let changed = Notification.Name("A1ProgressChanged")

    /// One saved state per level: "a1Progress", "a2Progress", …
    static func key(_ level: String) -> String { "\(level.lowercased())Progress" }

    static func load(_ level: String = "A1") -> A1SavedState {
        guard let data = UserDefaults.standard.data(forKey: key(level)),
              let state = try? JSONDecoder().decode(A1SavedState.self, from: data) else { return A1SavedState() }
        return state
    }

    func save(_ level: String = "A1") {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: A1SavedState.key(level))
        }
    }

    func merged(with other: A1SavedState) -> A1SavedState {
        var result = self
        result.seen.formUnion(other.seen)
        result.correct.formUnion(other.correct)
        for id in other.wrong where !result.wrong.contains(id) && !result.correct.contains(id) { result.wrong.append(id) }
        result.bestSprint = max(bestSprint, other.bestSprint)
        result.exams = exams + other.exams
        result.streak = max(streak, other.streak)
        return result
    }
}

final class A1Model: ObservableObject {
    @Published private(set) var content: A1Content?
    @Published private(set) var questions: [A1Question] = []
    @Published private(set) var ready = false
    private(set) var byID: [String: A1Question] = [:]
    private var modeTotals: [A1Mode: Int] = [:]
    private var a1Total = 0
    @Published private(set) var state: A1SavedState { didSet { recount() } }
    /// Counted once when the progress or the questions change, not on every screen update
    /// (screens ask for these many times per render; counting walked through every answered question each time).
    private var seenByMode: [A1Mode: Int] = [:]
    private var topicCounts: [Int: (seen: Int, total: Int, wrong: Int)] = [:]
    private var learnedCount = 0
    private var observer: NSObjectProtocol?

    private var languageWatch: AnyCancellable?

    /// "A1", "A2", … Each level has its own content file and saved progress.
    let level: String

    init(level: String = "A1") {
        self.level = level
        state = A1SavedState.load(level)
        observer = NotificationCenter.default.addObserver(forName: A1SavedState.changed, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.state = A1SavedState.load(self.level)
        }
        // Question texts are in the learner's language: build them again when it changes. Ids stay the same.
        languageWatch = Localizer.shared.$language.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.rebuild() }
        }
        rebuild()
    }

    func rebuild() {
        ready = false
        let cached = content
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = cached ?? A1Content.load(self.level)
            var built: [A1Question] = []
            if let loaded {
                var builder = A1BankBuilder(content: loaded, level: self.level)
                built = builder.build()
            }
            var map: [String: A1Question] = [:]
            var totals: [A1Mode: Int] = [:]
            var a1 = 0
            for q in built {
                map[q.id] = q
                if !A1Model.isCore(q) {
                    totals[q.mode, default: 0] += 1
                    a1 += 1
                }
            }
            DispatchQueue.main.async {
                self.content = loaded
                self.byID = map
                self.recount()
                self.modeTotals = totals
                self.a1Total = a1
                self.questions = built
                self.ready = true
            }
        }
    }

    /// Questions about the extra frequent-word list (not part of the A1 PDF).
    static func isCore(_ q: A1Question) -> Bool { q.theme == A1BankBuilder.coreTheme }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var total: Int { a1Total }
    var learned: Int { learnedCount }

    private func recount() {
        var seen: [A1Mode: Int] = [:]
        for id in state.seen {
            if let q = byID[id], !A1Model.isCore(q) { seen[q.mode, default: 0] += 1 }
        }
        var learned = 0
        for id in state.correct {
            if let q = byID[id], !A1Model.isCore(q) { learned += 1 }
        }
        seenByMode = seen
        learnedCount = learned
        var topics: [Int: (seen: Int, total: Int, wrong: Int)] = [:]
        for q in byID.values {
            guard let topic = q.topic else { continue }
            var entry = topics[topic] ?? (0, 0, 0)
            entry.total += 1
            if state.seen.contains(q.id) { entry.seen += 1 }
            topics[topic] = entry
        }
        for id in state.wrong {
            if let topic = byID[id]?.topic { topics[topic, default: (0, 0, 0)].wrong += 1 }
        }
        topicCounts = topics
    }
    var coreTotal: Int { questions.count - a1Total }
    var coreLearned: Int { max(0, state.correct.count - learned) }
    var readiness: Double { total == 0 ? 0 : Double(learned) / Double(total) }

    func totalFor(_ mode: A1Mode) -> Int { modeTotals[mode] ?? 0 }

    func seenCount(_ mode: A1Mode) -> Int { seenByMode[mode] ?? 0 }

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// Made once (a new DateFormatter per call was the cost of the streak count). Formatting is thread-safe.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var todayCount: Int { state.lastDay == A1Model.dayString(Date()) ? state.today : 0 }

    /// Today's activity keeps the streak alive.
    private func countToday(_ s: inout A1SavedState) {
        let today = A1Model.dayString(Date())
        if s.lastDay != today {
            let yesterday = A1Model.dayString(Date().addingTimeInterval(-86_400))
            s.streak = s.lastDay == yesterday ? s.streak + 1 : 1
            s.lastDay = today
            s.today = 0
        }
        s.today += 1
    }

    func record(_ q: A1Question, correct: Bool) {
        WordMastery.record(q.id, correct: correct)  // path word practice: the word moves a step
        var s = state
        countToday(&s)
        s.seen.insert(q.id)
        if correct {
            s.correct.insert(q.id)
            s.wrong.removeAll { $0 == q.id }
        } else if !s.wrong.contains(q.id) {
            s.wrong.append(q.id)
        }
        state = s
        s.save(level)
        ReviewStore.record(q.id, correct: correct, level: level)
        StreakStore.shared.record()
        StreakStore.shared.addXP(correct ? XP.correct : XP.wrong)
    }

    func saveSprint(_ score: Int) {
        StreakStore.shared.record()
        StreakStore.shared.addXP(score)
        guard score > state.bestSprint else { return }
        state.bestSprint = score
        state.save(level)
    }

    func saveExam(_ score: Int) {
        state.exams.append(score)
        state.save(level)
    }

    func reset(_ mode: A1Mode) {
        var s = state
        s.seen = s.seen.filter { byID[$0]?.mode != mode }
        s.correct = s.correct.filter { byID[$0]?.mode != mode }
        s.wrong.removeAll { byID[$0]?.mode == mode }
        state = s
        s.save(level)
    }

    /// How much a question is worth asking now: new and weak questions often, well-known ones rarely.
    /// Uses the spaced-repetition box (0 = just got it wrong … 5 = known for weeks) and the mistakes list.
    private func weight(_ q: A1Question, reviews: [String: ReviewItem], wrong: Set<String>, today: String) -> Double {
        if wrong.contains(q.id) { return 5 }
        guard let item = reviews[q.id] else {
            return state.seen.contains(q.id) ? 2 : 3  // never answered: new material comes often
        }
        let byBox: [Double] = [4, 2.5, 1.2, 0.5, 0.2, 0.08]
        let base = byBox[min(max(item.box, 0), byBox.count - 1)]
        return item.due <= today ? base * 2 : base  // due for review: twice as likely
    }

    /// A practice round that adapts to the learner: new questions and weak ones (wrong before, low box, due)
    /// come often, questions known for a long time only now and then. Weighted random without repeats
    /// (key = random^(1 / weight)), so every round is different. Mixed rounds spread over the games.
    func session(mode: A1Mode? = nil, theme: Int? = nil, topic: Int? = nil, count: Int = 20) -> [A1Question] {
        let pool = questions.filter { q in
            (mode == nil || q.mode == mode) && (topic == nil || q.topic == topic) &&
                (theme == nil ? !A1Model.isCore(q) : q.theme == theme)
        }
        let reviews = ReviewStore.load(level)
        let wrong = Set(state.wrong)
        let today = A1Model.dayString(Date())
        let ranked = pool
            .map { q in (q, pow(Double.random(in: 0.000_001..<1), 1 / weight(q, reviews: reviews, wrong: wrong, today: today))) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
        if mode != nil { return Array(ranked.prefix(count)) }
        // Mixed: take from the different games in turn, each game in its ranked order.
        var buckets = Dictionary(grouping: ranked, by: \.mode).values.map { Array($0) }
        var result: [A1Question] = []
        while result.count < count && !buckets.isEmpty {
            buckets.shuffle()
            for i in buckets.indices where !buckets[i].isEmpty && result.count < count {
                result.append(buckets[i].removeFirst())
            }
            buckets.removeAll { $0.isEmpty }
        }
        return result.shuffled()
    }

    func mistakeSession(count: Int = 20) -> [A1Question] {
        Array(state.wrong.compactMap { byID[$0] }.shuffled().prefix(count))
    }

    /// Exam rehearsal: listening, reading, writing and grammar like the Goethe/telc A1 modules.
    func examSession() -> [A1Question] {
        func take(_ mode: A1Mode, _ n: Int) -> [A1Question] {
            let pool = questions.filter { $0.mode == mode && !A1Model.isCore($0) }
            let unseen = pool.filter { !state.seen.contains($0.id) }.shuffled()
            let any = pool.shuffled()
            return Array((unseen.count >= n ? unseen : any).prefix(n))
        }
        return take(.hoeren, 6) + take(.listen, 3) + take(.reading, 6) + take(.write, 4) + take(.grammar, 5) +
            take(.cloze, 2) + take(.daily, 2) + take(.sentence, 2)
    }
}

// MARK: - Levels

/// Progress models for every level with practice content. `active` is the level whose practice screens are open.
final class LevelModels: ObservableObject {
    static let practiceLevels = ["A1", "A2", "B1", "B2"]

    let a1 = A1Model(level: "A1")
    lazy var a2 = A1Model(level: "A2")
    lazy var b1 = A1Model(level: "B1")
    lazy var b2 = A1Model(level: "B2")
    @Published var active = "A1"

    func model(_ level: String) -> A1Model {
        switch level {
        case "A2": return a2
        case "B1": return b1
        case "B2": return b2
        default: return a1
        }
    }
    var current: A1Model { model(active) }
    func hasPractice(_ level: String) -> Bool { LevelModels.practiceLevels.contains(level) }
}

// MARK: - Grammar topic badges

enum TopicStatus {
    /// Not finished yet.
    case open
    /// Has mistakes that are not corrected yet.
    case mistakes
    /// Finished, no open mistakes.
    case done
}

extension A1Model {
    /// Questions answered, questions in the topic, open mistakes.
    func topicProgress(_ topic: Int) -> (seen: Int, total: Int, wrong: Int) { topicCounts[topic] ?? (0, 0, 0) }

    /// A topic counts as finished after all its questions, or 30 of them for very large topics.
    func topicStatus(_ topic: Int) -> TopicStatus {
        let p = topicProgress(topic)
        if p.wrong > 0 { return .mistakes }
        if p.total > 0 && p.seen >= min(p.total, 30) { return .done }
        return .open
    }
}
