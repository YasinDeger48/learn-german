import Foundation
import UserNotifications

/// Local daily-reading reminders. No server: the phone schedules the next 30 days itself,
/// each with that day's text title. Called again on every launch and settings change.
enum Reminders {
    private static let prefix = "daily-"
    private static let days = 30

    static func requestPermission(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    static func refresh(_ model: DailyModel) {
        let center = UNUserNotificationCenter.current()
        let enabled = model.remindersOn
        let minutes = model.reminderMinutes
        let level = model.level
        let upcoming: [(Date, DailyText)] = (0..<days).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()),
                  let text = model.text(on: date, level: level) else { return nil }
            return (date, text)
        }
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard enabled else { return }
            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
                for (date, text) in upcoming {
                    var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    parts.hour = minutes / 60
                    parts.minute = minutes % 60
                    guard let fire = Calendar.current.date(from: parts), fire > Date() else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = t("notify.title")
                    content.body = t("notify.body", text.title, text.level, text.minutes)
                    content.sound = .default
                    content.userInfo = ["textID": text.id]
                    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                    let id = prefix + "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}
