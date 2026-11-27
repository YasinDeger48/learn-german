import StoreKit
import SwiftUI

/// In-app products. Create them in App Store Connect with exactly these ids
/// (monthly and yearly in one subscription group, lifetime as a non-consumable).
enum ProProduct {
    static let yearly = "com.yasindeger.almanca.pro.yearly"
    static let monthly = "com.yasindeger.almanca.pro.monthly"
    static let lifetime = "com.yasindeger.almanca.pro.lifetime"
    static let all = [yearly, monthly, lifetime]
}

/// Free practice questions per day, for all levels together. The daily reading text and its quiz stay free.
enum DailyQuota {
    static let freePerDay = 30
    private static let dayKey = "quotaDay"
    private static let usedKey = "quotaUsed"
    private static let bonusKey = "quotaBonus"
    private static var defaults: UserDefaults { .standard }

    /// Starts a new count on a new day.
    private static func roll() {
        let today = A1Model.dayString(Date())
        guard defaults.string(forKey: dayKey) != today else { return }
        defaults.set(today, forKey: dayKey)
        defaults.set(0, forKey: usedKey)
        defaults.set(0, forKey: bonusKey)
    }

    /// Free questions answered today.
    static var usedToday: Int {
        roll()
        return defaults.integer(forKey: usedKey)
    }

    static var remaining: Int {
        roll()
        return max(0, freePerDay + defaults.integer(forKey: bonusKey) - defaults.integer(forKey: usedKey))
    }

    static func use() {
        roll()
        defaults.set(defaults.integer(forKey: usedKey) + 1, forKey: usedKey)
    }

    /// Extra questions for today (for example after a rewarded ad).
    static func addBonus(_ count: Int) {
        roll()
        defaults.set(defaults.integer(forKey: bonusKey) + count, forKey: bonusKey)
    }
}

/// A thank-you for people who used Deschly while it was free for everyone: 30 days of Pro, counted from the first
/// launch of a version with sales on. Decided once on that launch: someone who had already picked a language used an
/// earlier version; a new install does not get it.
enum ProGift {
    static let days = 30
    private static let untilKey = "pro.giftUntil"
    private static let checkedKey = "pro.giftChecked"
    private static let welcomedKey = "pro.giftWelcomed"
    private static var defaults: UserDefaults { .standard }

    static func grantIfEarlyUser() {
        // Not in the owner's preview IPA (sample prices): there the free version itself is being tested.
        guard !ProStore.freeForAll, !ProPreview.enabled, !defaults.bool(forKey: checkedKey) else { return }
        defaults.set(true, forKey: checkedKey)
        guard defaults.bool(forKey: Localizer.chosenKey) else { return }
        let end = Date().addingTimeInterval(Double(days) * 86_400)
        defaults.set(end, forKey: untilKey)
        Reminders.scheduleGiftEnding(end)
    }

    static var until: Date? { defaults.object(forKey: untilKey) as? Date }
    static var isActive: Bool { until.map { $0 > Date() } ?? false }

    /// The gift screen, once, right after it was granted.
    static var shouldWelcome: Bool { isActive && !defaults.bool(forKey: welcomedKey) }
    static func markWelcomed() { defaults.set(true, forKey: welcomedKey) }
}

/// Deschly Pro: purchases with StoreKit 2 (no account, Apple keeps the receipts) and the free daily limit.
@MainActor
final class ProStore: ObservableObject {
    /// Info.plist "DeschlyFreeForAll" = true: everyone gets Pro (no ads, no daily limit, no paywall).
    /// A switch for launch periods; set it back to false to turn ads and Pro sales on again.
    nonisolated static let freeForAll = Bundle.main.object(forInfoDictionaryKey: "DeschlyFreeForAll") as? Bool ?? false

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool
    @Published private(set) var remaining: Int
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published var message: String?
    /// The yearly plan has a free trial this Apple ID can still use.
    @Published private(set) var trialDays: Int?
    /// End of the running free trial, if any.
    @Published private(set) var trialEnds: Date?
    /// A verified purchase or subscription (not the gift, not free-for-all).
    @Published private(set) var purchased: Bool
    /// Set after a purchase in this session: the paywall shows the welcome screen.
    @Published var showWelcome = false

    private let cacheKey = "proActive"

    /// Pro as last known (also inside sheets): free-for-all or a purchase StoreKit confirmed earlier.
    nonisolated static var isProNow: Bool { freeForAll || ProGift.isActive || UserDefaults.standard.bool(forKey: "proActive") }
    private var updates: Task<Void, Never>?

    init() {
        ProGift.grantIfEarlyUser()
        // Last known state, so the app does not flash the limit while StoreKit answers.
        let bought = UserDefaults.standard.bool(forKey: "proActive")
        purchased = bought
        isPro = ProStore.freeForAll || ProGift.isActive || bought
        remaining = DailyQuota.remaining
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    var canPractice: Bool { isPro || remaining > 0 }

    func countAnswer() {
        guard !isPro else { return }
        DailyQuota.use()
        remaining = DailyQuota.remaining
    }

    func refreshQuota() { remaining = DailyQuota.remaining }

    func addBonus(_ count: Int) {
        DailyQuota.addBonus(count)
        remaining = DailyQuota.remaining
    }

    func loadProducts() async {
        guard products.isEmpty, !loading else { return }
        loading = true
        defer { loading = false }
        guard let items = try? await Product.products(for: ProProduct.all) else { return }
        products = items.sorted { (ProProduct.all.firstIndex(of: $0.id) ?? 9) < (ProProduct.all.firstIndex(of: $1.id) ?? 9) }
        if let subscription = product(ProProduct.yearly)?.subscription, let offer = subscription.introductoryOffer,
           offer.paymentMode == .freeTrial, await subscription.isEligibleForIntroOffer {
            let period = offer.period
            switch period.unit {
            case .day: trialDays = period.value
            case .week: trialDays = period.value * 7
            case .month: trialDays = period.value * 30
            case .year: trialDays = period.value * 365
            @unknown default: trialDays = nil
            }
        } else {
            trialDays = nil
        }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// How much cheaper the yearly plan is than twelve months, in percent (nil when unknown or small).
    var yearlySaving: Int? {
        guard let yearly = product(ProProduct.yearly), let monthly = product(ProProduct.monthly), monthly.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly.price / (monthly.price * 12)).doubleValue
        let saving = Int(((1 - ratio) * 100).rounded())
        return saving >= 10 ? saving : nil
    }

    /// The yearly price split over twelve months, formatted in the store's currency.
    var yearlyPerMonth: String? {
        guard let yearly = product(ProProduct.yearly) else { return nil }
        return (yearly.price / 12).formatted(yearly.priceFormatStyle)
    }

    func refreshEntitlements() async {
        var active = false
        var trialEnd: Date?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, ProProduct.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
                if transaction.offerType == .introductory { trialEnd = transaction.expirationDate }
            }
        }
        trialEnds = trialEnd
        purchased = active
        isPro = active || ProStore.freeForAll || ProGift.isActive
        UserDefaults.standard.set(active, forKey: cacheKey)
    }

    func buy(_ product: Product) async {
        busy = true
        defer { busy = false }
        message = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    showWelcome = true
                    await refreshEntitlements()
                } else {
                    message = t("pro.failed")
                }
            case .pending:
                message = t("pro.pending")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = t("pro.failed")
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        message = isPro ? t("pro.restored") : t("pro.nothingRestored")
    }
}
