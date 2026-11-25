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

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([String: Int].self, forKey: .days) ?? [:]
        best = try c.decodeIfPresent(Int.self, forKey: .best) ?? 0
        xp = try c.decodeIfPresent([String: Int].self, forKey: .xp) ?? [:]
        totalXP = try c.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        goal = try c.decodeIfPresent(Int.self, forKey: .goal) ?? 50
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
        if !wasActive { NotificationCenter.default.post(name: StreakStore.changed, object: nil) }
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

    /// Days in a row ending today, or ending yesterday while today has no activity yet.
    var current: Int {
        var day = activeToday ? Date() : (calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        var count = 0
        while isActive(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
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
