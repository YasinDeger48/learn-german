import SwiftUI

// MARK: - Content (Resources/content/memorize.json, made by tools/memorize.py)

struct MemorizeRow: Decodable, Hashable {
    let q: LocText
    let a: String
    let x: String?
    /// The example's meaning in the learner's language.
    let xm: LocText?
}

struct MemorizeSheet: Decodable, Identifiable, Hashable {
    let id: String
    let level: String
    let icon: String
    /// "drill" (with a test) or "rules" (read only).
    let kind: String
    let title: LocText
    let intro: LocText
    let ask: String
    let rows: [MemorizeRow]
}

private struct MemorizeFile: Decodable {
    let sheets: [MemorizeSheet]
}

enum MemorizeBank {
    private static let all = Bundled.decode(MemorizeFile.self, "memorize")?.sheets ?? []

    /// Sheets of the level and the levels below it.
    static func sheets(upTo level: String) -> [MemorizeSheet] {
        let order = LevelModels.practiceLevels
        let limit = order.firstIndex(of: level) ?? 0
        return all.filter { (order.firstIndex(of: $0.level) ?? 0) <= limit }
    }

    static func sheet(_ id: String) -> MemorizeSheet? { all.first { $0.id == id } }

    static func best(_ id: String) -> Int? { UserDefaults.standard.object(forKey: "mem.best.\(id)") as? Int }

    static func save(_ id: String, percent: Int) {
        if percent > (best(id) ?? -1) { UserDefaults.standard.set(percent, forKey: "mem.best.\(id)") }
    }

    /// Up to 15 questions from the sheet's rows; wrong options are the sheet's other answers.
    static func drill(_ sheet: MemorizeSheet) -> [A1Question] {
        let answers = Array(Set(sheet.rows.map(\.a)))
        return sheet.rows.enumerated().shuffled().prefix(15).compactMap { index, row in
            let wrong = answers.filter { $0 != row.a }.shuffled().prefix(3)
            guard wrong.count >= 2 else { return nil }
            return A1Question(id: "mz-\(sheet.id)-\(index)", mode: .grammar, kind: .choice, label: sheet.title.text,
                              prompt: sheet.ask.replacingOccurrences(of: "{q}", with: row.q.text),
                              speakAfter: row.x ?? row.a, options: ([row.a] + wrong).shuffled(), answer: row.a,
                              explanation: row.x.map { "\(row.a) · \($0)" } ?? row.a)
        }
    }
}

// MARK: - List

struct MemorizeHomeView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        let sheets = MemorizeBank.sheets(upTo: model.level)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("mem.intro")).font(.subheadline).foregroundColor(DS.muted)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(sheets) { sheet in
                        NavigationLink(value: AppRoute.memorizeSheet(sheet.id)) { tile(sheet) }
                            .buttonStyle(.pressable)
                    }
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("mem.title"))
    }

    private func tile(_ sheet: MemorizeSheet) -> some View {
        let best = MemorizeBank.best(sheet.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sheet.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.indigo)
                    .frame(width: 34, height: 34)
                    .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                if let best {
                    Text("\(best)%").font(.caption.monospacedDigit().weight(.bold))
                        .foregroundColor(best >= 90 ? DS.success : DS.muted)
                }
            }
            Text(sheet.title.text).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                .lineLimit(2).multilineTextAlignment(.leading)
            Text(t("mem.rows", sheet.rows.count)).font(.caption).foregroundColor(DS.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - One sheet

struct MemorizeSheetView: View {
    let sheet: MemorizeSheet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(sheet.intro.text, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundColor(DS.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(sheet.rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider() }
                        // The whole row plays it, not only the speaker icon at the end (owner's request 2026-11-26).
                        Button { A1Speaker.shared.say(row.x ?? row.a) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(row.q.text).font(DS.text(14)).foregroundColor(DS.muted)
                                    .frame(width: sheet.kind == "rules" ? 120 : 130, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.a).font(DS.text(16, .semibold)).foregroundColor(DS.ink)
                                    if let x = row.x { Text(x).font(.caption).italic().foregroundColor(DS.muted) }
                                    // Its meaning under it, in the same type (owner's request).
                                    if let meaning = row.xm?.text, !meaning.isEmpty {
                                        Text(meaning).font(.caption).italic().foregroundColor(DS.muted)
                                    }
                                }
                                .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "speaker.wave.2").font(.subheadline).foregroundColor(DS.muted)
                                    .frame(width: 36, height: 36)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(t("common.listen"))
                    }
                }
                .padding(.horizontal, 14)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if sheet.kind != "rules" {
                    NavigationLink(value: AppRoute.memorizeDrill(sheet.id)) {
                        Label(t("mem.drill", min(15, sheet.rows.count)), systemImage: "brain.head.profile")
                            .font(DS.text(16, .semibold))
                            .foregroundColor(DS.onGold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DS.gold, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(sheet.title.text)
        .navigationBarTitleDisplayMode(.inline)
    }
}
