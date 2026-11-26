import SwiftUI

/// Mistakes of one part of the app, practised on their own: grammar, articles or listening.
/// The same wrong answers stay in the general mistakes list too; a correct answer removes them from both.
enum MistakeGroup: String, CaseIterable, Hashable {
    case grammar, artikel, hoeren

    var modes: Set<A1Mode> {
        switch self {
        case .grammar: return [.grammar]
        case .artikel: return [.artikel]
        case .hoeren: return [.hoeren, .listen]
        }
    }

    var title: String { t("mistakes.\(rawValue)") }
}

extension A1Model {
    private func mistakes(_ group: MistakeGroup) -> [A1Question] {
        state.wrong.compactMap { byID[$0] }.filter { group.modes.contains($0.mode) }
    }

    func mistakeCount(_ group: MistakeGroup) -> Int { mistakes(group).count }

    func mistakeSession(_ group: MistakeGroup, count: Int = 20) -> [A1Question] {
        Array(mistakes(group).shuffled().prefix(count))
    }
}

/// A red row at the top of the grammar list, the Hören page and Wortschatz; hidden when there is nothing to fix.
struct MistakeGroupRow: View {
    @ObservedObject var model: A1Model
    let group: MistakeGroup

    var body: some View {
        let count = model.mistakeCount(group)
        if count > 0 {
            NavigationLink(value: A1Route.mistakesOf(group)) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(DS.error, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.title).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                        Text(t("mistakes.groupSub", count)).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.system(size: 13, weight: .heavy).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(DS.error, in: Capsule())
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.error.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
    }
}

/// The small red mistake count on a Today tile; tapping it opens only that part's mistakes.
struct MistakeGroupBadge: View {
    @ObservedObject var model: A1Model
    let group: MistakeGroup

    var body: some View {
        let count = model.mistakeCount(group)
        if count > 0 {
            NavigationLink(value: A1Route.mistakesOf(group)) {
                Label("\(count)", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .heavy).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(DS.error, in: Capsule())
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(t("mistakes.badgeA11y", group.title, count))
        }
    }
}
