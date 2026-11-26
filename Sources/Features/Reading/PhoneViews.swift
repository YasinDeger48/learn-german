import SwiftUI

/// Phone calls and voicemail messages (Resources/content/phone_<level>.json, made by tools/phone.py). Stored like
/// daily texts: the reading screen plays the recorded call (phone line sound and background, tools/audio.py),
/// shows who says what and asks the quiz.
enum PhoneBank {
    private struct File: Decodable {
        let texts: [DailyText]
    }

    private static let all: [String: [DailyText]] = Dictionary(uniqueKeysWithValues: ["a1", "a2", "b1", "b2"].map { level in
        (level, Bundled.decode(File.self, "phone_\(level)")?.texts ?? [])
    })

    static func texts(_ level: String) -> [DailyText] { all[level.lowercased()] ?? [] }
    static func calls(_ level: String) -> [DailyText] { texts(level).filter { $0.topic == "call" } }
    static func messages(_ level: String) -> [DailyText] { texts(level).filter { $0.topic == "message" } }
    static func text(id: String) -> DailyText? { all.values.lazy.flatMap { $0 }.first { $0.id == id } }
}

struct PhoneCallsView: View {
    @EnvironmentObject private var daily: DailyModel
    let level: String

    var body: some View {
        List {
            section(t("phone.calls"), PhoneBank.calls(level), icon: "phone.fill", note: t("phone.callsNote"))
            section(t("phone.messages"), PhoneBank.messages(level), icon: "recordingtape", note: t("phone.messagesNote"))
        }
        .navigationTitle(t("phone.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ title: String, _ texts: [DailyText], icon: String, note: String) -> some View {
        if !texts.isEmpty {
            Section {
                ForEach(texts) { text in row(text, icon: icon) }
            } header: {
                Text(title)
            } footer: {
                Text(note)
            }
        }
    }

    private func row(_ text: DailyText, icon: String) -> some View {
        NavigationLink {
            DailyReadingView(text: text)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: daily.isCompleted(text) ? "checkmark.circle.fill" : icon)
                    .foregroundColor(daily.isCompleted(text) ? DS.success : DS.goldDeep)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.title).font(.headline)
                    Text("\(text.level) · " + t("exam.minutes", text.minutes)).font(.caption).foregroundColor(DS.muted)
                }
            }
        }
    }
}
