import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// Ad unit ids. Real ids go into Info.plist (GADApplicationIdentifier, DeschlyAdBanner, DeschlyAdInterstitial,
/// DeschlyAdRewarded). Debug and TestFlight builds always use Google's test ads: clicking your own live ads
/// can close the AdMob account.
enum AdUnits {
    private static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    private static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
    private static let testRewarded = "ca-app-pub-3940256099942544/1712485313"

    static var useTestAds: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    private static func id(_ key: String, test: String) -> String {
        if useTestAds { return test }
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? test : value
    }

    static var banner: String { id("DeschlyAdBanner", test: testBanner) }
    static var interstitial: String { id("DeschlyAdInterstitial", test: testInterstitial) }
    static var rewarded: String { id("DeschlyAdRewarded", test: testRewarded) }
}

extension UIApplication {
    /// The view controller on top, for presenting consent forms and full-screen ads.
    static func topViewController() -> UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Ads for the free version: consent (UMP, required in the EU/UK/CH), App Tracking Transparency, then
/// a banner on list screens, an interstitial after every third finished quiz (at most every 3 minutes)
/// and a rewarded ad for +10 questions when the daily limit is reached. Pro users never see ads.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var canShowAds = false
    @Published private(set) var rewardedReady = false
    @Published private(set) var privacyOptionsRequired = false

    private var started = false
    private var adsStarted = false
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var lastInterstitial = Date.distantPast
    private let quizCountKey = "adsQuizzesSinceInterstitial"

    /// Once per launch, after onboarding, for free users.
    func start() {
        guard !started else { return }
        started = true
        // Consent given at an earlier launch: ads can start right away.
        if ConsentInformation.shared.canRequestAds { consentDone() }
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard let controller = UIApplication.topViewController() else {
                    self.consentDone()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: controller) { [weak self] _ in
                    Task { @MainActor in self?.consentDone() }
                }
            }
        }
    }

    private func consentDone() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds, !adsStarted else { return }
        adsStarted = true
        requestTracking { [weak self] in
            MobileAds.shared.start(completionHandler: nil)
            self?.canShowAds = true
            self?.loadInterstitial()
            self?.loadRewarded()
        }
    }

    /// Apple's tracking prompt, once. Ads work either way (without it they are not personalised).
    private func requestTracking(then next: @escaping @MainActor () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            next()
            return
        }
        // The prompt only shows while the app is active; a short wait lets the consent form close first.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            _ = await ATTrackingManager.requestTrackingAuthorization()
            next()
        }
    }

    /// Settings row "Ad privacy options" (UMP requires a way to change the choice).
    func showPrivacyOptions() {
        guard let controller = UIApplication.topViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: controller) { [weak self] _ in
            Task { @MainActor in self?.consentDone() }
        }
    }

    // MARK: Interstitial

    private func loadInterstitial() {
        guard canShowAds, interstitial == nil else { return }
        InterstitialAd.load(with: AdUnits.interstitial, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                ad?.fullScreenContentDelegate = self
                self?.interstitial = ad
            }
        }
    }

    /// Call when a quiz result appears.
    func quizFinished(isPro: Bool) {
        guard !isPro, canShowAds else { return }
        let count = UserDefaults.standard.integer(forKey: quizCountKey) + 1
        UserDefaults.standard.set(count, forKey: quizCountKey)
        guard count >= 3, Date().timeIntervalSince(lastInterstitial) > 180, let ad = interstitial else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let controller = UIApplication.topViewController() else { return }
            UserDefaults.standard.set(0, forKey: quizCountKey)
            lastInterstitial = Date()
            interstitial = nil
            ad.present(from: controller)
        }
    }

    // MARK: Rewarded

    private func loadRewarded() {
        guard canShowAds, rewarded == nil else { return }
        RewardedAd.load(with: AdUnits.rewarded, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                ad?.fullScreenContentDelegate = self
                self?.rewarded = ad
                self?.rewardedReady = ad != nil
            }
        }
    }

    /// Shows the rewarded ad; `onReward` runs only when the viewer earned it.
    func showRewarded(onReward: @escaping @MainActor () -> Void) {
        guard let ad = rewarded, let controller = UIApplication.topViewController() else { return }
        rewarded = nil
        rewardedReady = false
        ad.present(from: controller) {
            Task { @MainActor in onReward() }
        }
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.loadInterstitial()
            self.loadRewarded()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.loadInterstitial()
            self.loadRewarded()
        }
    }
}

/// Anchored adaptive banner for list screens. Nothing for Pro users or before consent.
struct AdBanner: View {
    @EnvironmentObject private var pro: ProStore
    @ObservedObject private var ads = AdsManager.shared

    var body: some View {
        if !pro.isPro && ads.canShowAds {
            let size = currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
            BannerRepresentable(size: size)
                .frame(width: size.size.width, height: size.size.height)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let size: AdSize

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: size)
        view.adUnitID = AdUnits.banner
        view.rootViewController = UIApplication.topViewController()
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
