import Foundation

/// Learning days for the whole app: any answered practice question (every level), a finished reading quiz
/// or a sprint counts. The streak is the number of days in a row up to today (or yesterday, while today is
/// still open).
struct StreakState: Codable {
    /// "yyyy-MM-dd" → actions that day.
    var days: [String: Int] = [:]
    var best = 0
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
        state.best = max(state.best, other.best, current)
        save()
    }

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
