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

    static let key = "a1Progress"
    static let changed = Notification.Name("A1ProgressChanged")

    static func load() -> A1SavedState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(A1SavedState.self, from: data) else { return A1SavedState() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: A1SavedState.key)
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
    @Published private(set) var state: A1SavedState
    private var observer: NSObjectProtocol?

    private var languageWatch: AnyCancellable?

    init() {
        state = A1SavedState.load()
        observer = NotificationCenter.default.addObserver(forName: A1SavedState.changed, object: nil, queue: .main) { [weak self] _ in
            self?.state = A1SavedState.load()
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
            let loaded = cached ?? A1Content.load()
            var built: [A1Question] = []
            if let loaded {
                var builder = A1BankBuilder(content: loaded)
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
    var learned: Int {
        state.correct.reduce(0) { count, id in
            guard let q = byID[id], !A1Model.isCore(q) else { return count }
            return count + 1
        }
    }
    var coreTotal: Int { questions.count - a1Total }
    var coreLearned: Int { max(0, state.correct.count - learned) }
    var readiness: Double { total == 0 ? 0 : Double(learned) / Double(total) }

    func totalFor(_ mode: A1Mode) -> Int { modeTotals[mode] ?? 0 }

    func seenCount(_ mode: A1Mode) -> Int {
        state.seen.reduce(0) { count, id in
            guard let q = byID[id], q.mode == mode, !A1Model.isCore(q) else { return count }
            return count + 1
        }
    }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

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
        s.save()
    }

    func saveSprint(_ score: Int) {
        guard score > state.bestSprint else { return }
        state.bestSprint = score
        state.save()
    }

    func saveExam(_ score: Int) {
        state.exams.append(score)
        state.save()
    }

    func reset(_ mode: A1Mode) {
        var s = state
        s.seen = s.seen.filter { byID[$0]?.mode != mode }
        s.correct = s.correct.filter { byID[$0]?.mode != mode }
        s.wrong.removeAll { byID[$0]?.mode == mode }
        state = s
        s.save()
    }

    /// Never-seen questions only, so the same question is not asked twice.
    func session(mode: A1Mode? = nil, theme: Int? = nil, topic: Int? = nil, count: Int = 20) -> [A1Question] {
        let pool = questions.filter { q in
            (mode == nil || q.mode == mode) && (topic == nil || q.topic == topic) &&
                (theme == nil ? !A1Model.isCore(q) : q.theme == theme) && !state.seen.contains(q.id)
        }
        if mode != nil { return Array(pool.shuffled().prefix(count)) }
        // Mixed: spread the questions over the different games.
        var buckets = Dictionary(grouping: pool.shuffled(), by: \.mode).values.map { Array($0) }
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
