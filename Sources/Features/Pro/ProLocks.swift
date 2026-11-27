import SwiftUI

/// What the free version keeps back for Deschly Pro (owner's choice 2026-11-27): the units from number 4 on,
/// in every level. The first three units of each level, the daily text and the daily free questions stay free.
enum ProLocks {
    static let freeUnits = 3

    static func needsPro(_ unit: LearningUnit) -> Bool { unit.number > freeUnits && !openedByAd(unit) }

    private static func adKey(_ unit: LearningUnit) -> String { "pro.adUnlock.\(unit.id)" }

    /// A rewarded ad opened this unit less than 24 hours ago.
    static func openedByAd(_ unit: LearningUnit) -> Bool {
        guard let date = UserDefaults.standard.object(forKey: adKey(unit)) as? Date else { return false }
        return Date().timeIntervalSince(date) < 24 * 3600
    }

    static func openForADay(_ unit: LearningUnit) { UserDefaults.standard.set(Date(), forKey: adKey(unit)) }
}

/// A gold "PRO" chip for things that need Deschly Pro.
struct ProChip: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy)).kerning(0.8)
            .foregroundColor(DS.onGold)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(DS.gold, in: Capsule())
            .accessibilityLabel("Deschly Pro")
    }
}

/// A unit that needs Pro: its picture, goal and what is inside, so the learner sees what waits, then the offer.
struct ProLockedUnitView: View {
    let unit: LearningUnit
    @EnvironmentObject private var pro: ProStore
    @EnvironmentObject private var levels: LevelModels
    @ObservedObject private var ads = AdsManager.shared
    @State private var showPaywall = false
    /// Opened for 24 hours with a rewarded ad: the unit itself is shown here.
    @State private var opened = false

    var body: some View {
        if opened {
            UnitView(unit: unit).environmentObject(levels.model(unit.level))
        } else {
            preview
        }
    }

    private var preview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UnitPicture(unit: unit, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .topTrailing) { ProChip().padding(12) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("path.unitOf", unit.level, unit.number).uppercased())
                        .font(.caption.weight(.bold)).foregroundColor(DS.goldDeep)
                    Text(unit.title.text).font(DS.display(28)).foregroundColor(DS.ink)
                    Text(t("path.goal", unit.goal.text)).font(.subheadline).foregroundColor(DS.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("pro.unitInside")).font(.headline)
                    ForEach(UnitStep.allCases) { step in
                        Label(step.title, systemImage: step.icon).font(.subheadline).foregroundColor(DS.ink)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(t("pro.unitLocked", ProLocks.freeUnits)).font(.subheadline).foregroundColor(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button { showPaywall = true } label: {
                    Label(t("pro.unlockUnit"), systemImage: "lock.open.fill")
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                if ads.rewardedReady && !pro.isPro {
                    Button {
                        ads.showRewarded {
                            ProLocks.openForADay(unit)
                            withAnimation { opened = true }
                        }
                    } label: {
                        Label(t("pro.unitByAd"), systemImage: "play.rectangle.fill")
                            .font(DS.text(15, .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("path.unit", unit.number))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
    }
}
