import SwiftUI

/// Levels A1–B2 as a native grouped list. A1 opens the practice area; the others show their status.
struct LevelsView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel

    private struct Level {
        let code: String
        let nameKey: String
        let topicsKey: String
        let color: Color
    }

    private let rows = [
        Level(code: "A1", nameKey: "level.a1.name", topicsKey: "level.a1.topics", color: DS.das),
        Level(code: "A2", nameKey: "level.a2.name", topicsKey: "level.a2.topics", color: DS.accent),
        Level(code: "B1", nameKey: "level.b1.name", topicsKey: "level.b1.topics", color: .purple),
        Level(code: "B2", nameKey: "level.b2.name", topicsKey: "level.b2.topics", color: .orange),
    ]

    var body: some View {
        List {
            Section {
                ForEach(rows, id: \.code) { level in
                    NavigationLink(value: AppRoute.practice(level.code)) { row(level) }
                }
            } footer: {
                Text(t("levels.subtitle"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(t("tab.levels"))
    }

    private func row(_ level: Level) -> some View {
        HStack(spacing: 14) {
            Text(level.code)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(level.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t(level.nameKey)).font(.body.weight(.semibold))
                Text(t(level.topicsKey)).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                if levels.hasPractice(level.code) {
                    ProgressView(value: levels.model(level.code).readiness).tint(level.color).padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            if levels.hasPractice(level.code) {
                Text("\(Int((levels.model(level.code).readiness * 100).rounded()))%").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            } else if daily.isAvailable(level.code) {
                Text(t("levels.readingOnly")).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(t("levels.soon")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
