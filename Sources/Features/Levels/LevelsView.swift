import SwiftUI

/// "Dein Weg": A1 to B2 as a vertical path. A1 opens the practice area; later levels arrive with updates.
struct LevelsView: View {
    @EnvironmentObject private var a1: A1Model

    private struct Level {
        let code: String
        let nameKey: String
        let topicsKey: String
    }

    private let levels = [
        Level(code: "A1", nameKey: "level.a1.name", topicsKey: "level.a1.topics"),
        Level(code: "A2", nameKey: "level.a2.name", topicsKey: "level.a2.topics"),
        Level(code: "B1", nameKey: "level.b1.name", topicsKey: "level.b1.topics"),
        Level(code: "B2", nameKey: "level.b2.name", topicsKey: "level.b2.topics"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Dein Weg").font(DS.display(38)).tracking(-1.4).foregroundColor(DS.ink).padding(.top, 8)
                Text(t("levels.subtitle")).font(DS.text(14)).foregroundColor(DS.muted).padding(.top, 6)
                VStack(spacing: 14) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        HStack(alignment: .top, spacing: 16) {
                            dot(index)
                            if level.code == "A1" { activeCard(level) } else { lockedRow(level, last: index == levels.count - 1) }
                        }
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 120)
        }
        .deschlyPage()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dot(_ index: Int) -> some View {
        Circle()
            .fill(index == 0 ? DS.gold : DS.ground)
            .overlay(Circle().stroke(index == 0 ? DS.ink : DS.muted.opacity(0.5), lineWidth: index == 0 ? 3 : 2))
            .frame(width: 14, height: 14)
            .padding(.top, 22)
            .accessibilityHidden(true)
    }

    private func activeCard(_ level: Level) -> some View {
        NavigationLink(value: AppRoute.practice(level.code)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.code).font(DS.display(34)).foregroundColor(DS.gold)
                        Text(t(level.topicsKey)).font(DS.text(13)).foregroundColor(DS.onNightMuted)
                    }
                    Spacer()
                    Text("\(Int((a1.readiness * 100).rounded()))%").font(DS.display(22, heavy: false)).foregroundColor(DS.onNight)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(DS.gold).frame(width: max(6, geo.size.width * a1.readiness))
                    }
                }
                .frame(height: 6)
                HStack {
                    Text(t("levels.continue")).font(DS.text(15, .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(DS.onGold)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(DS.gold, in: Capsule())
            }
            .padding(18)
            .background(DS.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func lockedRow(_ level: Level, last: Bool) -> some View {
        NavigationLink(value: AppRoute.practice(level.code)) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.code).font(DS.display(34)).foregroundColor(DS.muted)
                    Text(t(level.topicsKey)).font(DS.text(13)).foregroundColor(DS.muted)
                }
                Spacer()
                Text(t("levels.soon"))
                    .font(DS.text(12, .semibold))
                    .foregroundColor(DS.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
            }
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(DS.hairline).frame(height: 1) }
            }
        }
        .buttonStyle(.plain)
    }
}
