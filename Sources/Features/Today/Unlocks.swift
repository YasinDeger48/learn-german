import SwiftUI

/// The parts that open step by step for a beginner (design: https://claude.ai/artifact/4YXtDvZx5SNnd77o434hWX).
enum UnlockFeature: String, CaseIterable {
    case match, wordRun, songs, lazy, linaChat, camera, exam

    var title: String {
        switch self {
        case .match: return t("practice.match")
        case .wordRun: return t("run.title")
        case .songs: return t("song.title")
        case .lazy: return t("lazy.title")
        case .linaChat: return t("lina.chatTitle")
        case .camera: return t("cam.title")
        case .exam: return t("tab.exam")
        }
    }
}

/// Slow opening for new A1 learners: day 1 the lesson and the matching game, day 2 the word run, day 3 songs and
/// Lazy mode, after A1 unit 2 Lina's chat and the camera, after A1 unit 5 the exam. A "day" is a day the app was
/// used, not a calendar day. Learners who start above A1 or already used the app (an update) get everything;
/// Settings → "Open all features" ends it at any time.
enum Unlocks {
    private static let beginnerKey = "unlock.beginner"
    private static let allKey = "unlock.all"
    private static let seenKey = "unlock.seen"
    private static var defaults: UserDefaults { .standard }

    /// Decided once, the first time any screen asks (all of them come after onboarding), from the learner's level
    /// (DailyModel's "dailyLevel"), so the very first drawing of Today already shows the locks.
    private static func decideIfNeeded() {
        guard defaults.object(forKey: beginnerKey) == nil else { return }
        let level = defaults.string(forKey: "dailyLevel") ?? "A1"
        defaults.set(level.uppercased() == "A1" && StreakStore.shared.state.totalXP == 0, forKey: beginnerKey)
        // What is open from the start is not "new".
        defaults.set(UnlockFeature.allCases.filter { isOpen($0) }.map(\.rawValue), forKey: seenKey)
    }

    static var isBeginner: Bool {
        decideIfNeeded()
        return defaults.bool(forKey: beginnerKey)
    }
    static var active: Bool { isBeginner && !defaults.bool(forKey: allKey) }

    static func openAll() {
        defaults.set(true, forKey: allKey)
        defaults.set(UnlockFeature.allCases.map(\.rawValue), forKey: seenKey)
    }

    /// Today counts as day 1 + the earlier days with practice.
    static var day: Int {
        let today = A1Model.dayString(Date())
        return 1 + StreakStore.shared.state.days.keys.filter { $0 < today }.count
    }

    static func isOpen(_ feature: UnlockFeature) -> Bool {
        guard active else { return true }
        switch feature {
        case .match: return true
        case .wordRun: return day >= 2
        case .songs, .lazy: return day >= 3
        case .linaChat, .camera: return UnitStore.passed("a1-02")
        case .exam: return UnitStore.passed("a1-05")
        }
    }

    /// "Opens on day 2" / "Opens after unit 2".
    static func hint(_ feature: UnlockFeature) -> String {
        switch feature {
        case .match: return ""
        case .wordRun: return t("unlock.day", 2)
        case .songs, .lazy: return t("unlock.day", 3)
        case .linaChat, .camera: return t("unlock.unit", 2)
        case .exam: return t("unlock.unit", 5)
        }
    }

    /// A feature that opened since the learner last looked (Lina tells about it once on Today).
    static func takeNew() -> UnlockFeature? {
        guard isBeginner else { return nil }
        var seen = Set(defaults.stringArray(forKey: seenKey) ?? [])
        guard let fresh = UnlockFeature.allCases.first(where: { isOpen($0) && !seen.contains($0.rawValue) }) else { return nil }
        seen.insert(fresh.rawValue)
        defaults.set(Array(seen), forKey: seenKey)
        return fresh
    }
}

/// Shows its content when the feature is open; otherwise dimmed, not tappable, with a lock and when it opens.
struct UnlockGate<Content: View>: View {
    let feature: UnlockFeature
    @ViewBuilder let content: () -> Content

    var body: some View {
        if Unlocks.isOpen(feature) {
            content()
        } else {
            content()
                .disabled(true)
                .opacity(0.45)
                .overlay(alignment: .topTrailing) {
                    Label(Unlocks.hint(feature), systemImage: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(DS.ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(DS.surface, in: Capsule())
                        .padding(6)
                }
                .accessibilityHint(Unlocks.hint(feature))
        }
    }
}

/// Lina's note on Today when something new opened.
struct UnlockedBanner: View {
    let feature: UnlockFeature

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            LinaAvatar(size: 40)
            Text(t("unlock.new", feature.title))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DS.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
