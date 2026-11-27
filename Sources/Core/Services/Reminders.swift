import Foundation
import UserNotifications

/// Local notifications, no server. The phone schedules the next days itself:
/// - the daily text at the reminder time,
/// - two learning moments during the day: an article quiz answered right on the lock screen
///   (der / die / das buttons) and a word of the day with an example,
/// - an evening streak reminder, only on days without any learning (cancelled at the first answer).
/// Called again on every launch, when the app becomes active and when a setting changes.
enum Reminders {
    private static let dailyPrefix = "daily-"
    private static let wordPrefix = "word-"
    private static let quizPrefix = "quiz-"
    private static let streakPrefix = "streak-"
    private static let awayPrefix = "away-"
    private static let days = 14
    /// "Lina misses you": days after the last time the app was opened, with Lina's picture.
    /// Every opening schedules them again from that day, so they only fire while the app stays closed.
    private static let away: [(day: Int, picture: String)] = [(2, "lina-sad-3"), (4, "lina-sad-3"), (7, "lina-sad-2"), (14, "lina-sad-2")]

    static let quizCategory = "ARTICLE_QUIZ"
    static let wordCategory = "WORD"

    // Settings (UserDefaults, so @AppStorage in Settings can bind to them).
    static let wordsKey = "notifyWords"
    static let streakKey = "notifyStreak"
    static var wordsOn: Bool { UserDefaults.standard.object(forKey: wordsKey) as? Bool ?? true }
    static var streakOn: Bool { UserDefaults.standard.object(forKey: streakKey) as? Bool ?? true }

    /// Learning moments during the day (hour, minute): quiz at noon, word in the afternoon.
    private static let quizTime = (12, 30)
    private static let wordTime = (17, 30)
    private static let streakTime = (20, 0)

    static func requestPermission(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    /// The der / die / das buttons and the word actions; registered once at launch.
    static func registerCategories() {
        let articles = ["der", "die", "das"].map {
            UNNotificationAction(identifier: "article.\($0)", title: $0, options: [])
        }
        let quiz = UNNotificationCategory(identifier: quizCategory, actions: articles, intentIdentifiers: [],
                                          hiddenPreviewsBodyPlaceholder: "", options: [])
        let practice = UNNotificationAction(identifier: "word.practice", title: t("notify.practiceAction"), options: [.foreground])
        let word = UNNotificationCategory(identifier: wordCategory, actions: [practice], intentIdentifiers: [],
                                          hiddenPreviewsBodyPlaceholder: "", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([quiz, word])
    }

    /// Nouns and other words with an example per level, made once (the level file is up to 2 MB).
    private static var lists: [String: (nouns: [A1Word], others: [A1Word])] = [:]
    private static let listLock = NSLock()

    private static func wordLists(_ level: String) -> (nouns: [A1Word], others: [A1Word]) {
        listLock.lock()
        if let known = lists[level] { listLock.unlock(); return known }
        listLock.unlock()
        let words = A1Content.load(level)?.words ?? []
        let made = (nouns: words.filter { $0.isNoun && $0.theme != A1BankBuilder.coreTheme },
                    others: words.filter { !$0.isNoun && !$0.ex.isEmpty && $0.theme != A1BankBuilder.coreTheme })
        listLock.lock()
        lists[level] = made
        listLock.unlock()
        return made
    }

    static func refresh(_ model: DailyModel) {
        let center = UNUserNotificationCenter.current()
        let enabled = model.remindersOn
        let minutes = model.reminderMinutes
        let level = model.level
        let wordsOn = self.wordsOn
        let streakOn = self.streakOn
        let upcoming: [(Date, DailyText)] = (0..<days).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()),
                  let text = model.text(on: date, level: level) else { return nil }
            return (date, text)
        }
        let activeToday = StreakStore.shared.activeToday
        DispatchQueue.global(qos: .utility).async {
            // Words of the learner's level (practice levels only; others use A1).
            let (nouns, others) = wordLists(LevelModels.practiceLevels.contains(level) ? level : "A1")
            center.getPendingNotificationRequests { pending in
                let ours = pending.map(\.identifier).filter {
                    $0.hasPrefix(dailyPrefix) || $0.hasPrefix(wordPrefix) || $0.hasPrefix(quizPrefix) || $0.hasPrefix(streakPrefix)
                        || $0.hasPrefix(awayPrefix)
                }
                center.removePendingNotificationRequests(withIdentifiers: ours)
                guard enabled else { return }
                center.getNotificationSettings { settings in
                    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                    for (offset, item) in upcoming.enumerated() {
                        let (date, text) = item
                        let dayNumber = DailyModel.dayNumber(date)
                        // Daily text.
                        add(center, dailyPrefix, date, (minutes / 60, minutes % 60)) { c in
                            c.title = t("notify.title")
                            c.body = t("notify.body", text.title, text.level, text.minutes)
                            c.userInfo = ["textID": text.id]
                        }
                        // Article quiz on the lock screen.
                        if wordsOn, !nouns.isEmpty {
                            let word = nouns[(dayNumber * 53 + 7) % nouns.count]
                            add(center, quizPrefix, date, quizTime) { c in
                                c.title = t("notify.quizTitle")
                                c.body = "___ \(word.de)  ·  \(word.mean.text)"
                                c.categoryIdentifier = quizCategory
                                c.userInfo = ["article": word.type, "word": word.de, "meaning": word.mean.text, "level": level]
                            }
                        }
                        // Word of the day with an example.
                        if wordsOn, !others.isEmpty {
                            let word = others[(dayNumber * 37 + 3) % others.count]
                            let example = word.ex.first
                            add(center, wordPrefix, date, wordTime) { c in
                                c.title = t("notify.wordTitle", word.de)
                                c.subtitle = word.mean.text
                                c.body = example.map { "„\($0.de)“\n\($0.mean.text)" } ?? ""
                                c.categoryIdentifier = wordCategory
                                c.userInfo = ["level": level]
                            }
                        }
                        // Evening streak reminder; today's is skipped when the learner was already active,
                        // and on a "Lina misses you" day that one comes instead.
                        if streakOn && !(offset == 0 && activeToday) && !away.contains(where: { $0.day == offset }) {
                            add(center, streakPrefix, date, streakTime) { c in
                                c.title = t("notify.streakTitle")
                                c.body = t("notify.streakBody")
                            }
                        }
                    }
                    // "Lina misses you" while the app stays closed (same switch as the streak reminder).
                    if streakOn {
                        for (n, item) in away.enumerated() {
                            guard let date = Calendar.current.date(byAdding: .day, value: item.day, to: Date()) else { continue }
                            add(center, awayPrefix, date, streakTime) { c in
                                c.title = t("notify.away\(n + 1)Title")
                                c.body = t("notify.away\(n + 1)Body")
                                if let picture = linaPicture(item.picture) { c.attachments = [picture] }
                            }
                        }
                    }
                }
            }
        }
    }

    /// A copy of Lina's picture for a notification (the system moves the attached file into its own store).
    private static func linaPicture(_ name: String) -> UNNotificationAttachment? {
        guard let source = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name).png")
        do {
            try FileManager.default.copyItem(at: source, to: copy)
            return try UNNotificationAttachment(identifier: name, url: copy, options: nil)
        } catch {
            return nil
        }
    }

    /// The first learning action of the day removes tonight's streak reminder.
    static func cancelTodayStreakReminder() {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let id = streakPrefix + "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func add(_ center: UNUserNotificationCenter, _ prefix: String, _ date: Date, _ time: (Int, Int),
                            fill: (UNMutableNotificationContent) -> Void) {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        parts.hour = time.0
        parts.minute = time.1
        guard let fire = Calendar.current.date(from: parts), fire > Date() else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.threadIdentifier = prefix
        fill(content)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let id = prefix + "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Answers from the lock screen and taps on notifications.
final class NotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    /// A daily text to open (tap on the daily notification).
    @Published var openTextID: String?
    /// A level to practise (tap on "Practise" in the word notification).
    @Published var openPractice: String?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        if action.hasPrefix("article."), let answer = info["article"] as? String, let word = info["word"] as? String {
            let picked = String(action.dropFirst("article.".count))
            let right = picked == answer
            let meaning = info["meaning"] as? String ?? ""
            DispatchQueue.main.async {
                StreakStore.shared.record()
                StreakStore.shared.addXP(right ? XP.correct : XP.wrong)
                Reminders.cancelTodayStreakReminder()
            }
            let content = UNMutableNotificationContent()
            content.title = right ? t("notify.quizRight") : t("notify.quizWrong")
            content.body = "\(answer) \(word) · \(meaning)" + (right ? "  +\(XP.correct) XP" : "")
            content.sound = right ? .default : nil
            content.threadIdentifier = "quiz-answer"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            center.add(UNNotificationRequest(identifier: "quiz-answer-\(UUID().uuidString)", content: content, trigger: trigger)) { _ in
                completionHandler()
            }
            return
        }
        if action == "word.practice" || response.notification.request.content.categoryIdentifier == Reminders.wordCategory {
            DispatchQueue.main.async { self.openPractice = info["level"] as? String }
        } else if let id = info["textID"] as? String {
            DispatchQueue.main.async { self.openTextID = id }
        }
        completionHandler()
    }

    /// Show notifications as banners also while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
