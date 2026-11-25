import StoreKit
import SwiftUI

enum LegalLinks {
    static let privacy = URL(string: "https://yasindeger48.github.io/deschly-site/")!
    /// Apple's standard licence agreement (used when the app has no own terms).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Pro colours: deep navy into the Deschly blue, with gold accents.
private enum ProStyle {
    static let navy = Color(red: 0.055, green: 0.106, blue: 0.302)
    static let blue = Color(red: 0.184, green: 0.357, blue: 0.918)
    static let gradient = LinearGradient(colors: [navy, blue], startPoint: .top, endPoint: .bottom)
    static let diagonal = LinearGradient(colors: [navy, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Lina in a gold ring with a PRO tag.
struct LinaPro: View {
    var size: CGFloat = 104

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = UIImage(named: "lina") {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    DS.gold
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(DS.gold, lineWidth: max(3, size * 0.035)))
            ProTag(size: size > 80 ? 12 : 10)
                .offset(x: size * 0.06, y: -size * 0.02)
        }
        .accessibilityLabel("Lina, Deschly Pro")
    }
}

struct ProTag: View {
    var size: CGFloat = 12

    var body: some View {
        Text("PRO")
            .font(.system(size: size, weight: .heavy))
            .foregroundColor(DS.onGold)
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.28)
            .background(DS.gold, in: RoundedRectangle(cornerRadius: size * 0.7, style: .continuous))
    }
}

private struct ProWordmark: View {
    var size: CGFloat = 32

    var body: some View {
        (Text("deschly") + Text(".").foregroundColor(DS.gold) + Text(" pro"))
            .font(DS.brand(size))
            .tracking(-0.6)
            .foregroundColor(.white)
            .accessibilityLabel("Deschly Pro")
    }
}

// MARK: - Paywall

/// The Deschly Pro offer: features, plan choice with App Store prices, trial, restore and legal links.
/// After a purchase the same sheet shows the welcome screen.
struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected = ProProduct.yearly

    var body: some View {
        Group {
            if pro.showWelcome && pro.isPro {
                WelcomeProView {
                    pro.showWelcome = false
                    dismiss()
                }
            } else {
                offer
            }
        }
        .task { await pro.loadProducts() }
        .onChange(of: pro.isPro) { isPro in
            // Restored, or bought on another device: nothing to sell any more.
            if isPro && !pro.showWelcome { dismiss() }
        }
    }

    private var offer: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(spacing: 12) {
                    features
                    plans
                }
                .padding(16)
            }
        }
        .background(DS.ground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.16), in: Circle())
                }
                .accessibilityLabel(t("common.close"))
                Spacer()
                Button(t("pro.restoreShort")) { Task { await pro.restore() } }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.85))
                    .disabled(pro.busy)
            }
            .foregroundColor(.white)
            LinaPro(size: 104)
            ProWordmark(size: 32)
            Text(t("pro.subtitle"))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.92))
                .frame(maxWidth: 300)
            if let message = pro.message {
                Text(message).font(.footnote).foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(ProStyle.gradient.ignoresSafeArea(edges: .top))
    }

    private var features: some View {
        VStack(spacing: 0) {
            featureRow("infinity", .init(red: 0.184, green: 0.357, blue: 0.918), t("pro.feature.unlimited"))
            Divider().padding(.leading, 42)
            featureRow("chart.bar.fill", .purple, t("pro.feature.levels"))
            Divider().padding(.leading, 42)
            featureRow("nosign", .init(red: 0.784, green: 0.196, blue: 0.227), t("pro.feature.noAds"))
            Divider().padding(.leading, 42)
            featureRow("snowflake", .init(red: 0.36, green: 0.64, blue: 0.92), t("pro.feature.freeze"))
            Divider().padding(.leading, 42)
            featureRow("arrow.uturn.backward", .init(red: 0.082, green: 0.478, blue: 0.255), t("pro.feature.mistakes"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func featureRow(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text).font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    @ViewBuilder private var plans: some View {
        if pro.isPro {
            Label(t("pro.active"), systemImage: "checkmark.seal.fill")
                .foregroundColor(DS.success)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if pro.products.isEmpty {
            HStack(spacing: 10) {
                if pro.loading { ProgressView() }
                Text(pro.loading ? t("pro.loading") : t("pro.unavailable")).foregroundColor(DS.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            if let yearly = pro.product(ProProduct.yearly) { yearlyCard(yearly) }
            HStack(spacing: 10) {
                if let monthly = pro.product(ProProduct.monthly) {
                    smallCard(monthly, t("pro.monthly"), t("pro.perMonth", monthly.displayPrice))
                }
                if let lifetime = pro.product(ProProduct.lifetime) {
                    smallCard(lifetime, t("pro.lifetime"), t("pro.once", lifetime.displayPrice))
                }
            }
        }
    }

    private func yearlyCard(_ product: Product) -> some View {
        let isOn = selected == product.id
        let note: String = {
            if let days = pro.trialDays, let perMonth = pro.yearlyPerMonth { return t("pro.trialThen", days, perMonth) }
            if let perMonth = pro.yearlyPerMonth { return t("pro.perMonthOnly", perMonth) }
            return ""
        }()
        return Button {
            selected = product.id
        } label: {
            HStack(spacing: 12) {
                radio(isOn)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("pro.yearly")).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                    if !note.isEmpty {
                        Text(note).font(.system(size: 13, weight: .semibold)).foregroundColor(DS.success)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                    Text(t("pro.perYearShort")).font(.caption).foregroundColor(DS.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isOn ? DS.accent : DS.hairline, lineWidth: isOn ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if let saving = pro.yearlySaving {
                    Text(t("pro.save", saving))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(DS.onGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DS.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .offset(x: -14, y: -11)
                }
            }
        }
        .buttonStyle(.pressable)
        .padding(.top, 6)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func smallCard(_ product: Product, _ title: String, _ price: String) -> some View {
        let isOn = selected == product.id
        return Button {
            selected = product.id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                Text(price).font(.system(size: 13)).foregroundColor(DS.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isOn ? DS.accent : DS.hairline, lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func radio(_ on: Bool) -> some View {
        ZStack {
            Circle().stroke(on ? DS.accent : DS.hairline, lineWidth: 2).frame(width: 22, height: 22)
            if on {
                Circle().fill(DS.accent).frame(width: 22, height: 22)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if !pro.isPro {
            let product = pro.product(selected)
            let trial = selected == ProProduct.yearly ? pro.trialDays : nil
            VStack(spacing: 8) {
                Button {
                    if let product { Task { await pro.buy(product) } }
                } label: {
                    Group {
                        if pro.busy {
                            ProgressView().tint(.white)
                        } else {
                            Text(trial.map { t("pro.startTrial", $0) } ?? t("pro.continue"))
                        }
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DS.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(product == nil || pro.busy)
                Text(selected == ProProduct.lifetime ? t("pro.legalLifetime")
                     : (trial == nil ? "" : t("pro.legalTrial") + " ") + t("pro.legal"))
                    .font(.caption)
                    .foregroundColor(DS.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Link(t("pro.terms"), destination: LegalLinks.terms)
                    Link(t("settings.privacy"), destination: LegalLinks.privacy)
                }
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }
}

// MARK: - Welcome

/// Shown once right after a purchase.
struct WelcomeProView: View {
    @EnvironmentObject private var pro: ProStore
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            LinaPro(size: 160)
                .background(confetti)
            Text("Willkommen bei\nDeschly Pro!")
                .font(DS.display(34))
                .multilineTextAlignment(.center)
            Text(t("welcome.body"))
                .multilineTextAlignment(.center)
                .foregroundColor(DS.muted)
                .frame(maxWidth: 320)
            VStack(spacing: 0) {
                check(t("pro.feature.unlimited"))
                Divider().padding(.leading, 40)
                check(t("pro.feature.noAds"))
                Divider().padding(.leading, 40)
                check(t("pro.feature.levels"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let end = pro.trialEnds {
                Text(t("welcome.trialEnds", end.formatted(date: .long, time: .omitted)))
                    .font(.footnote)
                    .foregroundColor(DS.muted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Los geht's!", action: onDone)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(DS.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(DS.ground.ignoresSafeArea())
    }

    private func check(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(DS.success)
                .frame(width: 28, height: 28)
                .background(DS.successSoft, in: Circle())
            Text(text).font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    /// A few coloured bits around Lina.
    private var confetti: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(DS.gold).frame(width: 10, height: 10).rotationEffect(.degrees(20)).offset(x: -110, y: -70)
            Circle().fill(ProStyle.blue).frame(width: 8, height: 8).offset(x: 112, y: -40)
            RoundedRectangle(cornerRadius: 3).fill(DS.die).frame(width: 7, height: 14).rotationEffect(.degrees(-30)).offset(x: -96, y: 40)
            RoundedRectangle(cornerRadius: 3).fill(DS.das).frame(width: 12, height: 6).rotationEffect(.degrees(35)).offset(x: 100, y: 64)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Daily limit

/// Shown in a quiz when today's free questions are used up: a small celebration, progress, and the ways on.
struct DailyLimitView: View {
    @EnvironmentObject private var pro: ProStore
    var answered = 0
    var correct = 0
    var streak = 0
    var level = ""
    var readiness: Double = 0
    /// Rewarded ad (+10 questions); nil hides the button.
    var onWatchAd: (() -> Void)? = nil
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(Color(UIColor.systemFill), lineWidth: 10)
                        Circle().trim(from: 0, to: 1).stroke(DS.gold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        LinaAvatar(size: 132).clipShape(Circle())
                    }
                    .frame(width: 168, height: 168)
                    .padding(.top, 12)
                    Text("Super gemacht!\n" + t("limit.solved", DailyQuota.usedToday))
                        .font(DS.display(28))
                        .multilineTextAlignment(.center)
                    Text(t("limit.body"))
                        .multilineTextAlignment(.center)
                        .foregroundColor(DS.muted)
                        .frame(maxWidth: 330)
                    HStack(spacing: 10) {
                        tile("\(streak)", t("limit.streak"), .orange)
                        if answered > 0 {
                            tile("\(Int((Double(correct) / Double(answered) * 100).rounded()))%", t("limit.correct"), DS.success)
                        }
                        if !level.isEmpty {
                            tile(level, t("limit.ready", Int((readiness * 100).rounded())), DS.accent)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 10) {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        ProTag(size: 11)
                        Text(pro.trialDays.map { t("limit.proTrial", $0) } ?? t("limit.button"))
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DS.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let onWatchAd {
                    Button(action: onWatchAd) {
                        Label(t("limit.watchAd", 10), systemImage: "play.rectangle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DS.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.hairline))
                    }
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(t("limit.next", hoursLeft(context.date).0, hoursLeft(context.date).1))
                        .font(.footnote)
                        .foregroundColor(DS.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .task { await pro.loadProducts() }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(DS.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(minWidth: 84)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Hours and minutes until the free questions come back (local midnight).
    private func hoursLeft(_ now: Date) -> (Int, Int) {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now).addingTimeInterval(86_400)
        let minutes = max(0, Int(midnight.timeIntervalSince(now) / 60))
        return (minutes / 60, minutes % 60)
    }
}

// MARK: - Level page banner

/// "N free questions left today" with a ring, opens the paywall.
struct FreeQuestionsBanner: View {
    @EnvironmentObject private var pro: ProStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(1, Double(pro.remaining) / Double(DailyQuota.freePerDay)))
                        .stroke(DS.gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(pro.remaining)").font(.system(size: 13, weight: .heavy))
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("practice.freeLeft", pro.remaining)).font(.system(size: 15, weight: .bold))
                    Text(pro.trialDays.map { t("practice.proHintTrial", $0) } ?? t("practice.proHint"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
                ProTag(size: 12)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(ProStyle.diagonal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
        .task { await pro.loadProducts() }
    }
}

// MARK: - Settings

/// Settings: a Pro card (or the active state), restore and manage subscription.
struct ProSettingsSection: View {
    @EnvironmentObject private var pro: ProStore
    @State private var showPaywall = false
    @State private var manage = false

    var body: some View {
        Group {
            if ProStore.freeForAll {
                // Everything is free for now: no Pro section at all.
                EmptyView()
            } else if pro.isPro {
                Section {
                    Label(t("pro.active"), systemImage: "checkmark.seal.fill").foregroundColor(DS.success)
                    if let end = pro.trialEnds {
                        Text(t("welcome.trialEnds", end.formatted(date: .long, time: .omitted)))
                            .font(.footnote).foregroundColor(DS.muted)
                    }
                    Button(t("pro.manage")) { manage = true }
                }
            } else {
                Section {
                    card
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    Button(t("pro.restore")) { Task { await pro.restore() } }.disabled(pro.busy)
                } header: {
                    Text(t("settings.purchases"))
                } footer: {
                    if let message = pro.message { Text(message) }
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
        .manageSubscriptionsSheet(isPresented: $manage)
        .onAppear { pro.refreshQuota() }
        .task { await pro.loadProducts() }
    }

    private var card: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    LinaPro(size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        ProWordmark(size: 22)
                        Text(t("settings.proCardSub")).font(.footnote).foregroundColor(.white.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Text(t("settings.freeToday", pro.remaining, DailyQuota.freePerDay)).font(.subheadline)
                    Spacer(minLength: 8)
                    Text(pro.trialDays.map { t("pro.trialChip", $0) } ?? "Pro")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(DS.onGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DS.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .foregroundColor(.white)
            .padding(16)
            .background(ProStyle.diagonal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
