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

/// Deschly Pro: purchases with StoreKit 2 (no account, Apple keeps the receipts) and the free daily limit.
@MainActor
final class ProStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool
    @Published private(set) var remaining: Int
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published var message: String?

    private let cacheKey = "proActive"
    private var updates: Task<Void, Never>?

    init() {
        // Last known state, so the app does not flash the limit while StoreKit answers.
        isPro = UserDefaults.standard.bool(forKey: cacheKey)
        remaining = DailyQuota.remaining
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    deinit { updates?.cancel() }

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
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, ProProduct.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
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
