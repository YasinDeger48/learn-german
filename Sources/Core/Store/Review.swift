import Foundation

/// Spaced repetition (Leitner boxes): every answered practice question gets a box and a due day.
/// Right answers move it up a box (next review later), a wrong answer sends it back to box 0 (tomorrow).
struct ReviewItem: Codable, Equatable {
    var box: Int
    /// "yyyy-MM-dd"
    var due: String
}

enum ReviewStore {
    /// Days until the next review, per box.
    static let intervals = [1, 3, 7, 14, 30, 60]
    static let changed = Notification.Name("ReviewsChanged")

    private static func key(_ level: String) -> String { "\(level.lowercased())Reviews" }

    /// Read from UserDefaults once per level, then kept in memory; every change goes through save().
    private static var memory: [String: [String: ReviewItem]] = [:]
    private static let lock = NSLock()

    static func load(_ level: String) -> [String: ReviewItem] {
        lock.lock()
        defer { lock.unlock() }
        if let items = memory[level] { return items }
        let items = UserDefaults.standard.data(forKey: key(level))
            .flatMap { try? JSONDecoder().decode([String: ReviewItem].self, from: $0) } ?? [:]
        memory[level] = items
        return items
    }

    static func save(_ items: [String: ReviewItem], _ level: String) {
        lock.lock()
        memory[level] = items
        lock.unlock()
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key(level)) }
    }

    static func day(_ offset: Int, from date: Date = Date()) -> String {
        let day = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: date) ?? date
        return A1Model.dayString(day)
    }

    /// After an answer: up a box when right, back to box 0 when wrong.
    static func record(_ id: String, correct: Bool, level: String) {
        var items = load(level)
        let old = items[id]
        let box = correct ? min((old.map { $0.box + 1 }) ?? 1, intervals.count - 1) : 0
        // A question answered right the first time is checked again in 3 days, then later and later.
        items[id] = ReviewItem(box: box, due: day(intervals[box]))
        save(items, level)
        NotificationCenter.default.post(name: changed, object: nil)
    }

    /// Questions due today or earlier, oldest first.
    static func due(_ level: String, today: Date = Date()) -> [String] {
        let now = A1Model.dayString(today)
        return load(level).filter { $0.value.due <= now }.sorted { $0.value.due < $1.value.due }.map(\.key)
    }

    static func merge(_ other: [String: ReviewItem], _ level: String) {
        var items = load(level)
        for (id, item) in other where items[id] == nil || items[id]!.box < item.box { items[id] = item }
        save(items, level)
    }

    /// All levels, for the backup.
    static func all() -> [String: [String: ReviewItem]] {
        Dictionary(uniqueKeysWithValues: LevelModels.practiceLevels.map { ($0, load($0)) })
    }
}

extension A1Model {
    /// Today's reviews that still exist in this level's questions.
    var dueReviewIDs: [String] { ReviewStore.due(level).filter { byID[$0] != nil } }

    /// A review round: due questions, oldest first, at most `count`.
    func reviewSession(count: Int = 20) -> [A1Question] {
        Array(dueReviewIDs.prefix(count).compactMap { byID[$0] }.shuffled())
    }
}
