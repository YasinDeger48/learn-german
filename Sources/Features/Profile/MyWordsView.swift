import SwiftUI

/// "Kelimelerim": the learner's own words in one place (design: https://claude.ai/artifact/UR4SupytQYdc9vFCF9RZgu):
/// what is due for review first, then saved words and the learner's own pool. (Mistakes and Wortschatz have their
/// own rows in Practice.)
/// It only links the lists that already exist, so no saved data moves.
struct MyWordsView: View {
    @EnvironmentObject private var daily: DailyModel
    @ObservedObject var model: A1Model
    @State private var pool: Set<Int> = []

    var body: some View {
        let due = model.ready ? model.dueReviewIDs.count : 0
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink(value: A1Route.review) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(due > 0 ? t("words.due", due) : t("words.noneDue"))
                            .font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(t("words.dueSub")).font(.subheadline).foregroundColor(DS.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if due > 0 {
                            Text(t("words.reviewNow"))
                                .font(DS.text(15, .semibold))
                                .foregroundColor(DS.onGold)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(DS.gold, in: Capsule())
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)
                .disabled(due == 0)

                VStack(spacing: 0) {
                    NavigationLink(value: AppRoute.savedWords) {
                        ModuleRow(icon: "bookmark.fill", color: DS.accent, title: t("words.saved"), subtitle: t("words.savedSub"),
                                  value: "\(daily.state.savedWords.count)")
                    }
                    Divider().padding(.leading, 56)
                    NavigationLink {
                        LazyPoolView(level: model.level, nouns: (model.content?.words ?? []).filter(\.isNoun),
                                     themes: model.content?.themes ?? [], pool: $pool)
                            .onDisappear { LazyPool.save(pool, level: model.level) }
                    } label: {
                        ModuleRow(icon: "sofa.fill", color: DS.das, title: t("words.pool"), subtitle: t("words.poolSub"),
                                  value: "\(pool.count)")
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("words.title"))
        .safeAreaInset(edge: .bottom) { AdBanner() }
        .onAppear { pool = LazyPool.ids(model.level) }
    }
}
