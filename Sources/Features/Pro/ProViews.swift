import StoreKit
import SwiftUI

enum LegalLinks {
    static let privacy = URL(string: "https://yasindeger48.github.io/deschly-site/")!
    /// Apple's standard licence agreement (used when the app has no own terms).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// The Deschly Pro offer: features, the three products with App Store prices, restore and legal links.
struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        LinaAvatar(size: 84)
                        Text("Deschly Pro").font(DS.display(30))
                        Text(t("pro.subtitle")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    Label(t("pro.feature.unlimited"), systemImage: "infinity")
                    Label(t("pro.feature.noAds"), systemImage: "nosign")
                    Label(t("pro.feature.levels"), systemImage: "chart.bar.fill")
                    Label(t("pro.feature.support"), systemImage: "heart.fill")
                }
                if pro.isPro {
                    Section {
                        Label(t("pro.active"), systemImage: "checkmark.seal.fill").foregroundStyle(DS.success)
                    }
                } else {
                    Section {
                        if pro.products.isEmpty {
                            HStack(spacing: 10) {
                                if pro.loading { ProgressView() }
                                Text(pro.loading ? t("pro.loading") : t("pro.unavailable")).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(pro.products, id: \.id) { product in
                            Button {
                                Task { await pro.buy(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name(product)).font(.headline).foregroundStyle(DS.ink)
                                        if product.id == ProProduct.yearly {
                                            Text(t("pro.yearlyNote")).font(.caption).foregroundStyle(DS.success)
                                        }
                                    }
                                    Spacer()
                                    Text(price(product)).font(.headline).monospacedDigit()
                                }
                            }
                            .disabled(pro.busy)
                        }
                    } footer: {
                        Text(t("pro.legal"))
                    }
                }
                Section {
                    Button(t("pro.restore")) { Task { await pro.restore() } }.disabled(pro.busy)
                    Link(t("pro.terms"), destination: LegalLinks.terms)
                    Link(t("settings.privacy"), destination: LegalLinks.privacy)
                } footer: {
                    if let message = pro.message { Text(message) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.close")) { dismiss() }
                }
            }
            .task { await pro.loadProducts() }
        }
    }

    private func name(_ product: Product) -> String {
        switch product.id {
        case ProProduct.yearly: return t("pro.yearly")
        case ProProduct.monthly: return t("pro.monthly")
        default: return t("pro.lifetime")
        }
    }

    private func price(_ product: Product) -> String {
        switch product.id {
        case ProProduct.yearly: return t("pro.perYear", product.displayPrice)
        case ProProduct.monthly: return t("pro.perMonth", product.displayPrice)
        default: return t("pro.once", product.displayPrice)
        }
    }
}

/// Shown in a quiz when today's free questions are used up.
struct DailyLimitView: View {
    @EnvironmentObject private var pro: ProStore
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            LinaAvatar(size: 96)
            Text(t("limit.title")).font(DS.display(26)).multilineTextAlignment(.center)
            Text(t("limit.body", DailyQuota.freePerDay))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(t("limit.button")) { showPaywall = true }
                .buttonStyle(PillButtonStyle())
            Text(t("limit.tomorrow")).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
    }
}

/// Settings section: Pro status, upgrade, restore, manage subscription.
struct ProSettingsSection: View {
    @EnvironmentObject private var pro: ProStore
    @State private var showPaywall = false
    @State private var manage = false

    var body: some View {
        Section {
            if pro.isPro {
                Label(t("pro.active"), systemImage: "checkmark.seal.fill").foregroundStyle(DS.success)
                Button(t("pro.manage")) { manage = true }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Label("Deschly Pro", systemImage: "star.fill")
                        Spacer()
                        Text(t("practice.freeLeft", pro.remaining)).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Button(t("pro.restore")) { Task { await pro.restore() } }.disabled(pro.busy)
            }
        } footer: {
            if let message = pro.message { Text(message) }
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
        .manageSubscriptionsSheet(isPresented: $manage)
        .onAppear { pro.refreshQuota() }
    }
}
