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

/// The learner's own order of daily texts for one level: which text each coming day gets, and what was shown.
/// Unread texts come first, in a random order, and nothing shown in the last weeks comes back soon.
struct DailyPlan: Codable {
    struct Shown: Codable {
        let day: String
        let id: String
    }

    /// "yyyy-MM-dd" → text id, today and the coming days.
    var days: [String: String] = [:]
    /// Texts that were the text of the day (also ones replaced after being finished), oldest first.
    var shown: [Shown] = []

    static func key(_ level: String) -> String { "dailyPlan.\(level)" }

    static func load(_ level: String) -> DailyPlan {
        guard let data = UserDefaults.standard.data(forKey: key(level)),
              let plan = try? JSONDecoder().decode(DailyPlan.self, from: data) else { return DailyPlan() }
        return plan
    }

    func save(_ level: String) {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: DailyPlan.key(level)) }
    }
}

/// Daily reading: one text per day and level from the learner's own plan, plus reminder settings.
final class DailyModel: ObservableObject {
    static let levels = ["A1", "A2", "B1", "B2"]

    @Published private(set) var texts: [String: [DailyText]] = [:]
    @Published private(set) var state = DailySavedState.load()
    @Published var level: String { didSet { defaults.set(level, forKey: "dailyLevel"); Reminders.refresh(self) } }
    @Published var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: "dailyReminders"); Reminders.refresh(self) } }
    @Published var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: "dailyReminderMinutes"); Reminders.refresh(self) } }

    private let defaults = UserDefaults.standard
    private var observer: NSObjectProtocol?
    private var plans: [String: DailyPlan] = [:]
    /// How many days ahead the plan is kept (reminders look 14 days ahead).
    private static let planDays = 21

    init() {
        level = UserDefaults.standard.string(forKey: "dailyLevel") ?? "A1"
        remindersOn = UserDefaults.standard.bool(forKey: "dailyReminders")
        reminderMinutes = UserDefaults.standard.object(forKey: "dailyReminderMinutes") as? Int ?? 8 * 60
        // The learner's level (and A1) before the first screen; the other levels off the main thread right after.
        var loaded: [String: [DailyText]] = [:]
        let first = Set([level, "A1"])
        for lvl in DailyModel.levels where first.contains(lvl) {
            if let file = Bundled.decode(DailyFile.self, "daily_\(lvl.lowercased())") { loaded[lvl] = file.texts }
        }
        texts = loaded
        if !isAvailable(level) { level = "A1" }
        let rest = DailyModel.levels.filter { !first.contains($0) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var more: [String: [DailyText]] = [:]
            for lvl in rest {
                if let file = Bundled.decode(DailyFile.self, "daily_\(lvl.lowercased())") { more[lvl] = file.texts }
            }
            DispatchQueue.main.async { self?.texts.merge(more) { current, _ in current } }
        }
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
        // Gregorian on purpose: with a Hijri or Japanese phone calendar "year 2026" is another date and the
        // number stayed 0 (the same text and word every day). The time zone is still the phone's.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0)
    }

    /// The text of `date` from the learner's plan (dates before today: from what was shown).
    func text(on date: Date, level: String? = nil) -> DailyText? {
        let level = level ?? self.level
        guard let list = texts[level], !list.isEmpty else { return nil }
        let day = A1Model.dayString(date)
        var plan = currentPlan(level)
        if day < A1Model.dayString(Date()) {
            return plan.shown.last { $0.day == day }.flatMap { text(id: $0.id) }
        }
        if plan.days[day] == nil {
            extend(&plan, level: level, through: date)
            plans[level] = plan
            plan.save(level)
        }
        return plan.days[day].flatMap { text(id: $0) }
    }

    /// Today's text. Once it is finished (quiz 100 %), a new one takes its place, so the first card keeps changing.
    var today: DailyText? {
        guard let current = text(on: Date()) else { return nil }
        guard isCompleted(current) else { return current }
        return replaceToday(level: level) ?? current
    }

    /// The plan with past days moved to `shown` and finished texts removed from the coming days.
    private func currentPlan(_ level: String) -> DailyPlan {
        var plan = plans[level] ?? DailyPlan.load(level)
        let today = A1Model.dayString(Date())
        var changed = false
        for (day, id) in plan.days.sorted(by: { $0.key < $1.key }) where day < today {
            plan.shown.append(.init(day: day, id: id))
            plan.days[day] = nil
            changed = true
        }
        // A future day whose text the learner already finished from the list gets a new one later.
        for (day, id) in plan.days where day > today && (state.quizzes[id] ?? 0) >= 100 {
            plan.days[day] = nil
            changed = true
        }
        if plan.shown.count > 400 { plan.shown.removeFirst(plan.shown.count - 400) }
        if changed { plan.save(level) }
        plans[level] = plan
        return plan
    }

    /// Fills every missing day from today to `date` (at least `planDays` ahead).
    private func extend(_ plan: inout DailyPlan, level: String, through date: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = max(calendar.startOfDay(for: date), calendar.date(byAdding: .day, value: Self.planDays - 1, to: start) ?? start)
        var day = start
        while day <= end {
            let key = A1Model.dayString(day)
            if plan.days[key] == nil, let id = pick(level: level, plan: plan) { plan.days[key] = id }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }

    /// A text that is not planned and was not shown lately: never opened first, then opened but not finished,
    /// then (when everything is done) finished ones for review. Random within each group.
    private func pick(level: String, plan: DailyPlan) -> String? {
        let list = texts[level] ?? []
        guard !list.isEmpty else { return nil }
        let planned = Set(plan.days.values)
        let recentCount = min(max(0, list.count - Self.planDays - 1), 45)
        let recent = Set(plan.shown.suffix(recentCount).map(\.id))
        let free = list.filter { !planned.contains($0.id) && !recent.contains($0.id) }
        let groups = [free.filter { status($0) == .new },
                      free.filter { !isCompleted($0) && status($0) != .new },
                      free]
        for group in groups where !group.isEmpty {
            return group.randomElement()?.id
        }
        return list.filter { !planned.contains($0.id) }.randomElement()?.id ?? list.randomElement()?.id
    }

    /// Today's finished text goes to `shown` and an unfinished one becomes today's text: the next planned day's
    /// if there is one, else a random unfinished text. Returns nil (and changes nothing) when every text is finished.
    private func replaceToday(level: String) -> DailyText? {
        var plan = currentPlan(level)
        let today = A1Model.dayString(Date())
        let list = texts[level] ?? []
        let shownToday = Set(plan.shown.filter { $0.day == today }.map(\.id) + [plan.days[today]].compactMap { $0 })
        let planned = plan.days.filter { $0.key > today }.sorted { $0.key < $1.key }
        var nextID: String?
        if let next = planned.first(where: { entry in text(id: entry.value).map { !isCompleted($0) } ?? false }) {
            nextID = next.value
            plan.days[next.key] = nil
        } else {
            nextID = list.filter { !isCompleted($0) && !shownToday.contains($0.id) }.randomElement()?.id
        }
        guard let nextID else { return nil }
        if let old = plan.days[today] { plan.shown.append(.init(day: today, id: old)) }
        plan.days[today] = nextID
        plans[level] = plan
        plan.save(level)
        DispatchQueue.main.async { Reminders.refresh(self) }
        return text(id: nextID)
    }

    /// All texts of the current level: not finished first, in their order.
    func allTexts() -> [DailyText] {
        let list = texts[level] ?? []
        return list.filter { !isCompleted($0) } + list.filter { isCompleted($0) }
    }

    func text(id: String) -> DailyText? {
        texts.values.lazy.flatMap { $0 }.first { $0.id == id } ?? StoryBank.text(id: id) ?? PhoneBank.text(id: id)  // stories, calls too
    }

    /// Texts shown on earlier days (and finished today's texts), newest first, each text once.
    func archive(days: Int = 30) -> [(date: Date, text: DailyText)] {
        let plan = currentPlan(level)
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        var seen = Set<String>()
        var result: [(date: Date, text: DailyText)] = []
        for entry in plan.shown.reversed() where !seen.contains(entry.id) {
            seen.insert(entry.id)
            if let text = text(id: entry.id), let date = parser.date(from: entry.day) { result.append((date, text)) }
            if result.count >= days { break }
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
