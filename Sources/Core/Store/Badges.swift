import SwiftUI

/// One achievement. Values come from data the app already keeps; only the earned ids are stored.
struct Badge: Identifiable, Hashable {
    enum Kind: String { case streak, xp, correct, perfect, reading, goal }

    let kind: Kind
    let target: Int

    var id: String { "\(kind.rawValue)-\(target)" }

    var icon: String {
        switch kind {
        case .streak: return "flame.fill"
        case .xp: return "star.fill"
        case .correct: return "checkmark.seal.fill"
        case .perfect: return "sparkles"
        case .reading: return "book.fill"
        case .goal: return "target"
        }
    }

    var colors: [Color] {
        switch kind {
        case .streak: return [Color(red: 1, green: 0.70, blue: 0.28), Color(red: 0.91, green: 0.35, blue: 0.05)]
        case .xp: return [Color(red: 0.43, green: 0.55, blue: 1), Color(red: 0.18, green: 0.36, blue: 0.92)]
        case .correct: return [Color(red: 0.37, green: 0.82, blue: 0.54), Color(red: 0.08, green: 0.48, blue: 0.25)]
        case .perfect: return [Color(red: 0.72, green: 0.61, blue: 1), Color(red: 0.36, green: 0.25, blue: 0.84)]
        case .reading: return [Color(red: 1, green: 0.88, blue: 0.54), Color(red: 0.95, green: 0.76, blue: 0.19)]
        case .goal: return [Color(red: 0.55, green: 0.84, blue: 0.91), Color(red: 0.05, green: 0.58, blue: 0.53)]
        }
    }

    var title: String { t("badge.\(kind.rawValue)", target) }
}

final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    static let all: [Badge] =
        [3, 7, 14, 30, 60, 100, 365].map { Badge(kind: .streak, target: $0) } +
        [100, 500, 1000, 2500, 5000, 10000].map { Badge(kind: .xp, target: $0) } +
        [50, 250, 1000, 2500].map { Badge(kind: .correct, target: $0) } +
        [1, 10, 50].map { Badge(kind: .perfect, target: $0) } +
        [1, 10, 30, 100].map { Badge(kind: .reading, target: $0) } +
        [1, 7, 30].map { Badge(kind: .goal, target: $0) }

    /// Streak days that get a full-screen celebration.
    static let milestones: Set<Int> = [7, 14, 30, 60, 100, 365]

    @Published private(set) var earned: Set<String>
    /// Earned but not celebrated yet (newest last).
    @Published private(set) var pending: [Badge] = []
    private static let key = "earnedBadges"

    private init() {
        earned = Set(UserDefaults.standard.stringArray(forKey: BadgeStore.key) ?? [])
    }

    func value(_ kind: Badge.Kind) -> Int {
        let streak = StreakStore.shared
        switch kind {
        case .streak: return streak.best
        case .xp: return streak.state.totalXP
        case .correct: return LevelModels.practiceLevels.reduce(0) { $0 + A1SavedState.load($1).correct.count }
        case .perfect: return streak.state.perfectRounds
        case .reading: return DailySavedState.load().quizzes.values.filter { $0 >= 100 }.count
        case .goal: return streak.goalDays
        }
    }

    func isEarned(_ badge: Badge) -> Bool { earned.contains(badge.id) }

    /// Checks all badges; newly earned ones are stored and queued for a celebration.
    /// The first run only stores what was already reached, without celebrating old achievements.
    @discardableResult
    func refresh() -> [Badge] {
        let firstRun = UserDefaults.standard.stringArray(forKey: BadgeStore.key) == nil
        var values: [Badge.Kind: Int] = [:]
        var new: [Badge] = []
        for badge in BadgeStore.all where !earned.contains(badge.id) {
            let value = values[badge.kind] ?? self.value(badge.kind)
            values[badge.kind] = value
            if value >= badge.target { new.append(badge) }
        }
        guard !new.isEmpty || firstRun else { return [] }
        earned.formUnion(new.map(\.id))
        UserDefaults.standard.set(Array(earned), forKey: BadgeStore.key)
        if firstRun { return [] }
        pending.append(contentsOf: new)
        return new
    }

    /// Takes the queued celebrations (shown once).
    func takePending() -> [Badge] {
        let items = pending
        pending = []
        return items
    }

    /// Next badge to aim for: the unearned one closest to done.
    var nextGoal: (badge: Badge, value: Int)? {
        var best: (Badge, Int, Double)?
        for badge in BadgeStore.all where !isEarned(badge) {
            let value = self.value(badge.kind)
            let ratio = Double(value) / Double(badge.target)
            if best == nil || ratio > best!.2 { best = (badge, value, ratio) }
        }
        return best.map { ($0.0, $0.1) }
    }
}
