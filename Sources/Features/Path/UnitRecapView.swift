import SwiftUI

/// After a unit test is passed (and from the unit page later): "Now you can say this", three phrases of the unit,
/// how many words and grammar topics it had and the test score (design: https://claude.ai/artifact/UR4SupytQYdc9vFCF9RZgu).
struct UnitRecapView: View {
    let unit: LearningUnit
    @Environment(\.dismiss) private var dismiss

    private var wordCount: Int { unit.vocab?.count ?? ((unit.pictures?.count ?? 0) + (unit.extra?.count ?? 0)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LinaAvatar(size: 84, mood: .happy)
                    .clipShape(Circle())
                    .padding(.top, 20)
                Text(t("recap.done", unit.number).uppercased())
                    .font(.caption.weight(.bold)).kerning(0.6).foregroundColor(DS.goldDeep)
                Text(t("recap.title")).font(DS.display(26)).foregroundColor(DS.ink).multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    ForEach(unit.phrases.prefix(3), id: \.de) { phrase in
                        Button { A1Speaker.shared.say(phrase.de) } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(phrase.de).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                                    Text(phrase.meaning).font(.caption).foregroundColor(DS.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "speaker.wave.2.fill").foregroundColor(DS.accent)
                            }
                            .padding(12)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                HStack(spacing: 8) {
                    stat("\(wordCount)", t("recap.words"))
                    stat("\(unit.grammar.count)", t("recap.grammar"))
                    stat(UnitStore.testScore(unit.id).map { "\($0)" } ?? "–", t("recap.test"))
                }
                Button { dismiss() } label: {
                    Text(t("recap.next"))
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy).monospacedDigit()).foregroundColor(DS.ink)
            Text(label).font(.caption).foregroundColor(DS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
