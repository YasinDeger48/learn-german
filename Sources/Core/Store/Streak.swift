import Foundation

/// Learning days for the whole app: any answered practice question (every level), a finished reading quiz
/// or a sprint counts. The streak is the number of days in a row up to today (or yesterday, while today is
/// still open).
struct StreakState: Codable {
    /// "yyyy-MM-dd" → actions that day.
    var days: [String: Int] = [:]
    var best = 0
    /// "yyyy-MM-dd" → XP earned that day.
    var xp: [String: Int] = [:]
    var totalXP = 0
    /// Daily XP goal: 20 relaxed, 50 regular, 100 serious.
    var goal = 50
    /// Days a streak freeze covered ("yyyy-MM-dd").
    var frozen: [String] = []
    /// Streak freezes in stock (at most 2).
    var freezes = 0
    /// Period of the last free freeze ("M2026-11" free, "W2026-48" Pro).
    var freezeGrant = ""
    /// Practice rounds of 5+ questions without a mistake.
    var perfectRounds = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([String: Int].self, forKey: .days) ?? [:]
        best = try c.decodeIfPresent(Int.self, forKey: .best) ?? 0
        xp = try c.decodeIfPresent([String: Int].self, forKey: .xp) ?? [:]
        totalXP = try c.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        goal = try c.decodeIfPresent(Int.self, forKey: .goal) ?? 50
        frozen = try c.decodeIfPresent([String].self, forKey: .frozen) ?? []
        freezes = try c.decodeIfPresent(Int.self, forKey: .freezes) ?? 0
        freezeGrant = try c.decodeIfPresent(String.self, forKey: .freezeGrant) ?? ""
        perfectRounds = try c.decodeIfPresent(Int.self, forKey: .perfectRounds) ?? 0
    }
}

/// XP rules, in one place.
enum XP {
    static let correct = 3
    static let wrong = 1
    /// A practice round of at least 5 questions without a mistake.
    static let perfectBonus = 10
    static let readingDone = 20
    static let readingTried = 10
    static let goals = [20, 50, 100]
    /// Correct answers in "My mistakes" count double.
    static let mistakeMultiplier = 2
    static let maxFreezes = 2
}

final class StreakStore: ObservableObject {
    static let shared = StreakStore()
    static let changed = Notification.Name("StreakChanged")

    @Published private(set) var state: StreakState
    private static let key = "learningDays"
    private let calendar = Calendar(identifier: .gregorian)

    private init() {
        if let data = UserDefaults.standard.data(forKey: StreakStore.key),
           let saved = try? JSONDecoder().decode(StreakState.self, from: data) {
            state = saved
        } else {
            state = StreakStore.migrated()
            save()
        }
    }

    /// First launch with this version: rebuild the days from the old per-level streaks.
    private static func migrated() -> StreakState {
        var result = StreakState()
        let calendar = Calendar(identifier: .gregorian)
        let parser = DateFormatter()
        parser.calendar = calendar
        parser.dateFormat = "yyyy-MM-dd"
        for level in LevelModels.practiceLevels {
            let saved = A1SavedState.load(level)
            guard saved.streak > 0, let last = parser.date(from: saved.lastDay) else { continue }
            for back in 0..<min(saved.streak, 400) {
                if let day = calendar.date(byAdding: .day, value: -back, to: last) {
                    result.days[A1Model.dayString(day), default: 0] += back == 0 ? max(1, saved.today) : 1
                }
            }
            result.best = max(result.best, saved.streak)
        }
        return result
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: StreakStore.key) }
    }

    /// Call for every learning action.
    func record(_ count: Int = 1) {
        let today = A1Model.dayString(Date())
        let wasActive = state.days[today] != nil
        state.days[today, default: 0] += count
        state.best = max(state.best, current)
        // Keep about a year and a half.
        if state.days.count > 550 {
            let keep = Set(state.days.keys.sorted().suffix(500))
            state.days = state.days.filter { keep.contains($0.key) }
        }
        save()
        if !wasActive {
            NotificationCenter.default.post(name: StreakStore.changed, object: nil)
            Reminders.cancelTodayStreakReminder()
        }
    }

    func merge(_ other: StreakState) {
        for (day, count) in other.days { state.days[day] = max(state.days[day] ?? 0, count) }
        for (day, points) in other.xp { state.xp[day] = max(state.xp[day] ?? 0, points) }
        state.totalXP = max(state.totalXP, other.totalXP, state.xp.values.reduce(0, +))
        state.best = max(state.best, other.best, current)
        save()
    }

    // MARK: XP and daily goal

    static let goalReached = Notification.Name("DailyGoalReached")

    func addXP(_ points: Int) {
        guard points > 0 else { return }
        let today = A1Model.dayString(Date())
        let before = state.xp[today] ?? 0
        state.xp[today] = before + points
        state.totalXP += points
        if state.xp.count > 550 {
            let keep = Set(state.xp.keys.sorted().suffix(500))
            state.xp = state.xp.filter { keep.contains($0.key) }
        }
        save()
        if before < state.goal && before + points >= state.goal {
            markGoalDay(today)
            NotificationCenter.default.post(name: StreakStore.goalReached, object: nil)
        }
    }

    var xpToday: Int { state.xp[A1Model.dayString(Date())] ?? 0 }
    func xp(on date: Date) -> Int { state.xp[A1Model.dayString(date)] ?? 0 }
    var goal: Int { state.goal }
    var goalProgress: Double { min(1, Double(xpToday) / Double(max(1, state.goal))) }
    var goalReachedToday: Bool { xpToday >= state.goal }

    func setGoal(_ goal: Int) {
        state.goal = goal
        save()
    }

    /// Learner level from total XP: level n starts at 50·n·(n−1) XP (0, 100, 300, 600, 1000, 1500 …).
    var xpLevel: Int {
        var n = 1
        while 50 * (n + 1) * n <= state.totalXP { n += 1 }
        return n
    }

    var xpLevelRange: (start: Int, end: Int) { (50 * xpLevel * (xpLevel - 1), 50 * (xpLevel + 1) * xpLevel) }

    func actions(on date: Date) -> Int { state.days[A1Model.dayString(date)] ?? 0 }
    func isActive(_ date: Date) -> Bool { actions(on: date) > 0 }

    var activeToday: Bool { isActive(Date()) }

    func isFrozen(_ date: Date) -> Bool { state.frozen.contains(A1Model.dayString(date)) }

    /// Days in a row ending today, or ending yesterday while today has no activity yet.
    /// A day covered by a streak freeze keeps the streak alive but does not add to it.
    var current: Int {
        var day = activeToday ? Date() : (calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        var count = 0
        while isActive(day) || isFrozen(day) {
            if isActive(day) { count += 1 }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: Streak freeze

    /// Gives the free freeze of this period (free: one a month, Pro: one a week) and uses freezes for
    /// missed days right before today, so a streak survives one or two missed days.
    func refreshFreezes(isPro: Bool) {
        var cal = calendar
        cal.firstWeekday = 2
        let now = Date()
        let period = isPro
            ? "W\(cal.component(.yearForWeekOfYear, from: now))-\(cal.component(.weekOfYear, from: now))"
            : "M\(cal.component(.year, from: now))-\(cal.component(.month, from: now))"
        if state.freezeGrant != period {
            state.freezeGrant = period
            state.freezes = min(XP.maxFreezes, state.freezes + 1)
        }
        // Missed days before today (newest first), then check there was a streak before them.
        var missed: [Date] = []
        var day = cal.date(byAdding: .day, value: -1, to: now) ?? now
        while !isActive(day) && !isFrozen(day) && missed.count <= XP.maxFreezes {
            missed.append(day)
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        if !missed.isEmpty, missed.count <= state.freezes, isActive(day) || isFrozen(day) {
            state.frozen.append(contentsOf: missed.map { A1Model.dayString($0) })
            state.frozen = Array(state.frozen.suffix(60))
            state.freezes -= missed.count
        }
        save()
    }

    func addPerfectRound() {
        state.perfectRounds += 1
        save()
    }

    /// Days on which the daily goal was reached, with the goal of that day. (Counting again with today's goal
    /// gave the goal badges at once when the goal was lowered.) The first time, seeded from the XP history.
    var goalDays: Int { goalDaySet().count }

    private static let goalDaysKey = "goalReachedDays"

    private func goalDaySet() -> Set<String> {
        if let saved = UserDefaults.standard.stringArray(forKey: StreakStore.goalDaysKey) { return Set(saved) }
        let seeded = Set(state.xp.filter { $0.value >= state.goal }.map(\.key))
        UserDefaults.standard.set(Array(seeded), forKey: StreakStore.goalDaysKey)
        return seeded
    }

    private func markGoalDay(_ day: String) {
        var days = goalDaySet()
        days.insert(day)
        UserDefaults.standard.set(Array(days), forKey: StreakStore.goalDaysKey)
    }

    /// The streak ends tonight unless the learner does something today.
    var atRisk: Bool { !activeToday && current > 0 }

    var best: Int { max(state.best, current) }
    var totalDays: Int { state.days.count }

    /// The last `weeks` weeks, Monday first, ending with the current week.
    func weeks(_ weeks: Int) -> [[Date]] {
        var cal = calendar
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekday = (cal.component(.weekday, from: today) + 5) % 7   // Monday = 0
        guard let monday = cal.date(byAdding: .day, value: -weekday, to: today),
              let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: monday) else { return [] }
        return (0..<weeks).map { w in
            (0..<7).compactMap { d in cal.date(byAdding: .day, value: w * 7 + d, to: start) }
        }
    }
}
