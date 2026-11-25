import Foundation
import Combine

/// What the learner did with the daily texts. Stored as JSON in UserDefaults and in the backup file.
struct DailySavedState: Codable {
    var read: Set<String> = []
    /// Best quiz result per text, in percent.
    var quizzes: [String: Int] = [:]
    /// Words saved from texts ("die Verspätung").
    var savedWords: [String] = []

    static let key = "dailyProgress"
    static let changed = Notification.Name("DailyProgressChanged")

    static func load() -> DailySavedState {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(DailySavedState.self, from: data) else { return DailySavedState() }
        return state
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: DailySavedState.key) }
    }

    func merged(with other: DailySavedState) -> DailySavedState {
        var result = self
        result.read.formUnion(other.read)
        for (id, score) in other.quizzes { result.quizzes[id] = max(result.quizzes[id] ?? 0, score) }
        for word in other.savedWords where !result.savedWords.contains(word) { result.savedWords.append(word) }
        return result
    }
}

/// Where the learner is with one daily text.
enum ReadingStatus: Equatable {
    case new
    /// Opened, quiz not taken yet.
    case opened
    /// Quiz taken, best result below 100 %.
    case tried(Int)
    /// Quiz answered fully correct.
    case done
}

/// Daily reading: one text per day and level, picked by date, plus reminder settings.
final class DailyModel: ObservableObject {
    static let levels = ["A1", "A2", "B1", "B2"]

    @Published private(set) var texts: [String: [DailyText]] = [:]
    @Published private(set) var state = DailySavedState.load()
    @Published var level: String { didSet { defaults.set(level, forKey: "dailyLevel"); Reminders.refresh(self) } }
    @Published var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: "dailyReminders"); Reminders.refresh(self) } }
    @Published var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: "dailyReminderMinutes"); Reminders.refresh(self) } }

    private let defaults = UserDefaults.standard
    private var observer: NSObjectProtocol?

    init() {
        level = UserDefaults.standard.string(forKey: "dailyLevel") ?? "A1"
        remindersOn = UserDefaults.standard.bool(forKey: "dailyReminders")
        reminderMinutes = UserDefaults.standard.object(forKey: "dailyReminderMinutes") as? Int ?? 8 * 60
        var loaded: [String: [DailyText]] = [:]
        for lvl in DailyModel.levels {
            if let file = Bundled.decode(DailyFile.self, "daily_\(lvl.lowercased())") { loaded[lvl] = file.texts }
        }
        texts = loaded
        if !isAvailable(level) { level = "A1" }
        observer = NotificationCenter.default.addObserver(forName: DailySavedState.changed, object: nil, queue: .main) { [weak self] _ in
            self?.state = DailySavedState.load()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func isAvailable(_ level: String) -> Bool { !(texts[level] ?? []).isEmpty }

    /// Days since 1 Jan 2026 in the phone's calendar: the same text for everyone on the same day.
    static func dayNumber(_ date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0)
    }

    func text(on date: Date, level: String? = nil) -> DailyText? {
        guard let list = texts[level ?? self.level], !list.isEmpty else { return nil }
        return list[DailyModel.dayNumber(date) % list.count]
    }

    var today: DailyText? { text(on: Date()) }

    /// All texts of the current level: not finished first, in their order.
    func allTexts() -> [DailyText] {
        let list = texts[level] ?? []
        return list.filter { !isCompleted($0) } + list.filter { isCompleted($0) }
    }

    func text(id: String) -> DailyText? {
        texts.values.lazy.flatMap { $0 }.first { $0.id == id }
    }

    /// Earlier days' texts, newest first (at most one full round of the pool).
    func archive(days: Int = 30) -> [(date: Date, text: DailyText)] {
        guard let list = texts[level], !list.isEmpty else { return [] }
        var result: [(date: Date, text: DailyText)] = []
        let limit = min(days, list.count - 1)
        guard limit > 0 else { return [] }
        for offset in 1...limit {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            if let item = text(on: date) { result.append((date, item)) }
        }
        return result
    }

    func isRead(_ text: DailyText) -> Bool { state.read.contains(text.id) }
    func quizScore(_ text: DailyText) -> Int? { state.quizzes[text.id] }

    /// A text counts as done only when its quiz was answered fully correct once.
    func isCompleted(_ text: DailyText) -> Bool { (state.quizzes[text.id] ?? 0) >= 100 }

    func status(_ text: DailyText) -> ReadingStatus {
        if let score = state.quizzes[text.id] { return score >= 100 ? .done : .tried(score) }
        return state.read.contains(text.id) ? .opened : .new
    }

    func markRead(_ text: DailyText) {
        guard !state.read.contains(text.id) else { return }
        state.read.insert(text.id)
        state.save()
    }

    func saveQuiz(_ text: DailyText, correct: Int, total: Int) {
        guard total > 0 else { return }
        let percent = Int((Double(correct) / Double(total) * 100).rounded())
        state.quizzes[text.id] = max(state.quizzes[text.id] ?? 0, percent)
        StreakStore.shared.record()
        StreakStore.shared.addXP(percent >= 100 ? XP.readingDone : XP.readingTried)
        state.read.insert(text.id)
        state.save()
    }

    /// Saved words with their glossary entry and the text they come from (newest first).
    var savedGlosses: [(gloss: DailyGloss, text: DailyText)] {
        var index: [String: (DailyGloss, DailyText)] = [:]
        for list in texts.values {
            for text in list {
                for g in text.glossary where index[g.display] == nil { index[g.display] = (g, text) }
            }
        }
        return state.savedWords.reversed().compactMap { word in index[word].map { (gloss: $0.0, text: $0.1) } }
    }

    func removeSaved(_ display: String) {
        state.savedWords.removeAll { $0 == display }
        state.save()
    }

    /// Meaning quiz over the saved words; wrong options come from every glossary.
    func savedWordsQuiz() -> [A1Question] {
        let saved = savedGlosses
        let allMeanings = Array(Set(texts.values.flatMap { $0 }.flatMap { $0.glossary.map { $0.mean.text } }))
        return saved.shuffled().compactMap { item in
            let correct = item.gloss.mean.text
            let wrong = Array(allMeanings.filter { $0 != correct }.shuffled().prefix(3))
            guard wrong.count == 3 else { return nil }
            return A1Question(id: "sw-\(item.gloss.display)", mode: .wordToTr, kind: .choice, label: item.text.title,
                              prompt: item.gloss.display, detail: a1PronDetail(item.gloss.pron ?? ""), speakAfter: item.gloss.display,
                              options: ([correct] + wrong).shuffled(), answer: correct,
                              explanation: "\(item.gloss.display) = \(correct)")
        }
    }

    func isSaved(_ gloss: DailyGloss) -> Bool { state.savedWords.contains(gloss.display) }

    func toggleSaved(_ gloss: DailyGloss) {
        if let index = state.savedWords.firstIndex(of: gloss.display) {
            state.savedWords.remove(at: index)
        } else {
            state.savedWords.append(gloss.display)
        }
        state.save()
    }
}
