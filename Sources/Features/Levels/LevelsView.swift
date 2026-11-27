import SwiftUI

/// Levels A1–B2 as cards: colour band, readiness ring, what the level covers, and "your level".
/// The only place to change the level: a tap asks first, then Today, the path, Practice and the exam move to it.
struct LevelsView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel
    /// The level the learner tapped, waiting for "are you sure?".
    @State private var pending: String?

    private struct Level {
        let code: String
        let nameKey: String
        let topicsKey: String
        let colors: [Color]
    }

    private let rows = [
        Level(code: "A1", nameKey: "level.a1.name", topicsKey: "level.a1.topics",
              colors: [Color(red: 0.37, green: 0.82, blue: 0.54), Color(red: 0.08, green: 0.48, blue: 0.25)]),
        Level(code: "A2", nameKey: "level.a2.name", topicsKey: "level.a2.topics",
              colors: [Color(red: 0.43, green: 0.55, blue: 1), Color(red: 0.18, green: 0.36, blue: 0.92)]),
        Level(code: "B1", nameKey: "level.b1.name", topicsKey: "level.b1.topics",
              colors: [Color(red: 0.72, green: 0.61, blue: 1), Color(red: 0.36, green: 0.25, blue: 0.84)]),
        Level(code: "B2", nameKey: "level.b2.name", topicsKey: "level.b2.topics",
              colors: [Color(red: 1, green: 0.70, blue: 0.28), Color(red: 0.91, green: 0.35, blue: 0.05)]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(rows, id: \.code) { level in
                    Button {
                        if level.code != daily.level { pending = level.code }
                    } label: { card(level) }
                        .buttonStyle(.pressable)
                        .disabled(!daily.isAvailable(level.code))
                }
                Text(t("levels.subtitle"))
                    .font(.footnote)
                    .foregroundColor(DS.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("tab.levels"))
        .alert(t("levels.confirmTitle", pending ?? ""), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
               presenting: pending) { code in
            Button(t("levels.confirmYes", code)) { choose(code) }
            Button(t("common.cancel"), role: .cancel) { pending = nil }
        } message: { _ in
            Text(t("levels.confirmBody"))
        }
    }

    private func choose(_ code: String) {
        daily.level = code
        if levels.hasPractice(code) { levels.active = code }
        pending = nil
    }

    private func card(_ level: Level) -> some View {
        let practice = levels.hasPractice(level.code)
        let readiness = practice ? levels.model(level.code).readiness : 0
        let mine = daily.level == level.code
        return HStack(spacing: 14) {
            Text(level.code)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(LinearGradient(colors: level.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(t(level.nameKey)).font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                    if mine {
                        Text(t("levels.mine"))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(DS.onGold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(DS.gold, in: Capsule())
                    }
                }
                Text(t(level.topicsKey)).font(.footnote).foregroundColor(DS.muted).lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            if practice {
                GoalRing(progress: readiness, size: 50, lineWidth: 6, color: level.colors.last ?? DS.accent) {
                    Text("\(Int((readiness * 100).rounded()))%").font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundColor(DS.ink)
                }
            } else {
                Text(daily.isAvailable(level.code) ? t("levels.readingOnly") : t("levels.soon"))
                    .font(.caption).foregroundColor(DS.muted)
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if mine {
                RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.gold, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
