import SwiftUI

/// One achievement. Values come from data the app already keeps; only the earned ids are stored.
struct Badge: Identifiable, Hashable {
    /// `welcome`: "Curious about German", earned by starting the app.
    /// `match`: finished word matching games (MatchGameView).
    /// `song`: songs sung to the end (SongPlayerView).
    enum Kind: String { case welcome, streak, xp, correct, perfect, reading, goal, match, song }

    let kind: Kind
    let target: Int

    var id: String { "\(kind.rawValue)-\(target)" }

    var icon: String {
        switch kind {
        case .welcome: return "lightbulb.fill"
        case .streak: return "flame.fill"
        case .xp: return "star.fill"
        case .correct: return "checkmark.seal.fill"
        case .perfect: return "sparkles"
        case .reading: return "book.fill"
        case .goal: return "target"
        case .match: return "square.grid.2x2.fill"
        case .song: return "music.note"
        }
    }

    var colors: [Color] {
        switch kind {
        case .welcome: return [Color(red: 1, green: 0.62, blue: 0.70), Color(red: 0.86, green: 0.22, blue: 0.45)]
        case .streak: return [Color(red: 1, green: 0.70, blue: 0.28), Color(red: 0.91, green: 0.35, blue: 0.05)]
        case .xp: return [Color(red: 0.43, green: 0.55, blue: 1), Color(red: 0.18, green: 0.36, blue: 0.92)]
        case .correct: return [Color(red: 0.37, green: 0.82, blue: 0.54), Color(red: 0.08, green: 0.48, blue: 0.25)]
        case .perfect: return [Color(red: 0.72, green: 0.61, blue: 1), Color(red: 0.36, green: 0.25, blue: 0.84)]
        case .reading: return [Color(red: 1, green: 0.88, blue: 0.54), Color(red: 0.95, green: 0.76, blue: 0.19)]
        case .goal: return [Color(red: 0.55, green: 0.84, blue: 0.91), Color(red: 0.05, green: 0.58, blue: 0.53)]
        case .match: return [Color(red: 1, green: 0.62, blue: 0.43), Color(red: 0.85, green: 0.33, blue: 0.16)]
        case .song: return [Color(red: 0.62, green: 0.48, blue: 1), Color(red: 0.36, green: 0.20, blue: 0.80)]
        }
    }

    var title: String { t("badge.\(kind.rawValue)", target) }
}

final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()

    /// Targets per kind, in the order shown. (Built in a loop: one long `+` chain is too slow for the type checker.)
    private static let targets: [(Badge.Kind, [Int])] = [
        (.welcome, [1]),
        (.streak, [3, 7, 14, 30, 60, 100, 365]),
        (.xp, [100, 500, 1000, 2500, 5000, 10000]),
        (.correct, [50, 250, 1000, 2500]),
        (.perfect, [1, 10, 50]),
        (.reading, [1, 10, 30, 100]),
        (.goal, [1, 7, 30]),
        (.match, [1, 10, 50]),
        (.song, [1, 5, 12]),
    ]

    /// Finished word matching games (5 rounds each), counted by MatchGameView.
    static let matchGamesKey = "matchGamesFinished"

    static let all: [Badge] = {
        var badges: [Badge] = []
        for (kind, values) in targets {
            for target in values { badges.append(Badge(kind: kind, target: target)) }
        }
        return badges
    }()

    /// Streak days that get a full-screen celebration.
    static let milestones: Set<Int> = [7, 14, 30, 60, 100, 365]

    @Published private(set) var earned: Set<String>
    /// Earned but not celebrated yet (newest last).
    @Published private(set) var pending: [Badge] = []
    private static let key = "earnedBadges"

    private init() {
        earned = Set(UserDefaults.standard.stringArray(forKey: BadgeStore.key) ?? [])
    }

    /// Values of this moment (the badges page asks for every kind several times per render; some decode saved data).
    private var memo: [Badge.Kind: Int] = [:]
    private var memoAt = Date.distantPast

    func value(_ kind: Badge.Kind) -> Int {
        if Date().timeIntervalSince(memoAt) > 1 {
            memo = [:]
            memoAt = Date()
        }
        if let known = memo[kind] { return known }
        let result = computeValue(kind)
        memo[kind] = result
        return result
    }

    private func computeValue(_ kind: Badge.Kind) -> Int {
        let streak = StreakStore.shared
        switch kind {
        case .welcome: return 1
        case .streak: return streak.best
        case .xp: return streak.state.totalXP
        case .correct: return LevelModels.practiceLevels.reduce(0) { $0 + A1SavedState.load($1).correct.count }
        case .perfect: return streak.state.perfectRounds
        case .reading: return DailySavedState.load().quizzes.values.filter { $0 >= 100 }.count
        case .goal: return streak.goalDays
        case .match: return UserDefaults.standard.integer(forKey: BadgeStore.matchGamesKey)
        case .song: return SongBank.finished.count
        }
    }

    func isEarned(_ badge: Badge) -> Bool { earned.contains(badge.id) }

    /// Checks all badges; newly earned ones are stored and queued for a celebration.
    /// The first run only stores what was already reached, without celebrating old achievements.
    @discardableResult
    func refresh() -> [Badge] {
        memo = [:]  // fresh values for earning
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
        // On the first run old achievements are stored quietly; only the welcome badge is celebrated.
        let celebrate = firstRun ? new.filter { $0.kind == .welcome } : new
        pending.append(contentsOf: celebrate)
        return celebrate
    }

    /// Posted when a screen that held celebrations back closes: RootView checks the badges again.
    static let recheck = Notification.Name("BadgesRecheck")

    /// Quiz screens on display. While one is open, new badges are stored but not celebrated over the questions:
    /// the round summary shows them (RootView celebrates everything else at once).
    private(set) var openQuizzes: Set<UUID> = []
    func quizShown(_ id: UUID) { openQuizzes.insert(id) }
    func quizHidden(_ id: UUID) {
        openQuizzes.remove(id)
        if openQuizzes.isEmpty { NotificationCenter.default.post(name: BadgeStore.recheck, object: nil) }
    }

    /// Takes the queued celebrations (shown once).
    func takePending() -> [Badge] {
        let items = pending
        pending = []
        return items
    }

    /// Only the welcome badge (or nothing) earned so far.
    var onlyWelcome: Bool { earned.subtracting([Badge(kind: .welcome, target: 1).id]).isEmpty }

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
