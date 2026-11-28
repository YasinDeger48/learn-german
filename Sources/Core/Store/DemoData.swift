import Foundation

/// Sample progress for App Store screenshots. Only in the "Ekran-Demo" IPA from CI, whose Info.plist has
/// `DeschlyDemoData = true`; the App Store build never has the key. Filled once, at the first launch:
/// a 5-day streak (today included), A1 units 1 and 2 passed, a passed A1 mock exam with its certificate,
/// and a few entries in "My mistakes". Today's text stays unread, so Today still shows "Lesen".
enum DemoData {
    private static let doneKey = "demo.seeded"

    static var enabled: Bool { Bundle.main.object(forInfoDictionaryKey: "DeschlyDemoData") as? Bool == true }

    static func seedIfRequested() {
        let defaults = UserDefaults.standard
        guard enabled, !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)

        // Streak: the last five days, today included, with some XP each day.
        var streak = StreakState()
        let calendar = Calendar(identifier: .gregorian)
        for back in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: -back, to: Date()) else { continue }
            let key = A1Model.dayString(day)
            streak.days[key] = [14, 22, 9, 31, 18][back]
            streak.xp[key] = [55, 70, 40, 95, 60][back]
        }
        streak.totalXP = streak.xp.values.reduce(0, +)
        streak.best = 5
        StreakStore.shared.merge(streak)

        // Path: A1 units 1 and 2 passed (every step done).
        for (unit, score) in [("a1-01", 92), ("a1-02", 88)] {
            defaults.set(UnitStep.allCases.map(\.rawValue), forKey: "unit.\(unit)")
            defaults.set(score, forKey: "unit.test.\(unit)")
        }
        defaults.set(A1Model.dayString(Date()), forKey: "unit.lastStepDay")

        // My mistakes: "find the mistake" and "what do you say" questions from the A1 content.
        var a1 = A1SavedState.load("A1")
        let wrong = ["fx-0", "fx-3", "fx-7", "sit-5"]
        let right = ["fx-1", "fx-2", "sit-0", "sit-1", "sit-2"]
        a1.seen.formUnion(wrong + right)
        a1.correct.formUnion(right)
        for id in wrong where !a1.wrong.contains(id) { a1.wrong.append(id) }
        a1.save("A1")

        // A passed A1 mock exam: the certificate appears in Profile → My certificates. Sample name, not the owner's.
        defaults.set("Lena Schmidt", forKey: ExamStore.nameKey)
        let date = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        ExamStore.record(ExamAttempt(level: "A1", date: date,
                                     scores: ["lesen": 22, "hoeren": 20, "schreiben": 19, "sprechen": 18]))
    }
}
