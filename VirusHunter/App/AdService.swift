import SwiftUI
import AppTrackingTransparency
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// Ads policy for Virus Hunter.
/// - Banner on the home screen only.
/// - Interstitial between runs only (never mid-run).
/// - Rewarded: revive once per run, and double coins on the result screen.
/// Debug builds use Google's test units so development never creates invalid traffic.
enum AdService {
    // App ID: ca-app-pub-1172711111790014~5616909596 (Info.plist GADApplicationIdentifier)
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let bannerUnitID = "ca-app-pub-1172711111790014/4686447868"
    static let interstitialUnitID = "ca-app-pub-1172711111790014/2060284526"
    static let rewardedUnitID = "ca-app-pub-1172711111790014/3844761605"
    #endif

    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uitesting") }
    static var shouldShowAds: Bool { !isUITesting }

    static func shouldShowInterstitial(gamesPlayed: Int) -> Bool {
        guard shouldShowAds, gamesPlayed >= 3, gamesPlayed % 2 == 1 else { return false }
        let last = UserDefaults.standard.double(forKey: "ads.lastInterstitial")
        return Date().timeIntervalSince1970 - last > 90
    }

    private(set) static var started = false

    /// Consent: Google UMP (GDPR / US-state messages) → Apple ATT → Mobile Ads SDK.
    @MainActor
    static func start() {
        guard shouldShowAds, !started else { return }
        started = true
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { _ in
            Task { @MainActor in
                ConsentForm.loadAndPresentIfRequired(from: rootViewController()) { _ in
                    Task { @MainActor in requestTrackingThenStart() }
                }
            }
        }
        #else
        requestTrackingThenStart()
        #endif
    }

    @MainActor
    private static func requestTrackingThenStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { _ in DispatchQueue.main.async { startSDK() } }
            } else {
                startSDK()
            }
        }
    }

    @MainActor
    private static func startSDK() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { _ in
            Task { @MainActor in
                InterstitialController.shared.preload()
                RewardedController.shared.preload()
            }
        }
        #endif
    }

    @MainActor
    static func rootViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

#if canImport(GoogleMobileAds)
/// Adaptive anchored banner.
struct BannerAdView: View {
    var body: some View {
        if AdService.shouldShowAds {
            GeometryReader { geo in
                BannerRepresentable(width: geo.size.width)
                    .frame(width: geo.size.width, height: 60)
            }
            .frame(height: 60)
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: max(320, width)))
        view.adUnitID = AdService.bannerUnitID
        view.rootViewController = AdService.rootViewController()
        view.load(Request())
        return view
    }
    func updateUIView(_ uiView: BannerView, context: Context) {}
}

@MainActor
final class InterstitialController: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialController()
    private var ad: InterstitialAd?
    private var onDone: (() -> Void)?

    func preload() {
        guard AdService.shouldShowAds, ad == nil else { return }
        InterstitialAd.load(with: AdService.interstitialUnitID, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                self?.ad = ad
                ad?.fullScreenContentDelegate = self
            }
        }
    }

    /// Shows an interstitial if the policy allows and one is loaded; `then` runs afterwards either way.
    func showIfAllowed(gamesPlayed: Int, then: @escaping () -> Void) {
        guard AdService.shouldShowInterstitial(gamesPlayed: gamesPlayed), let ad, let root = AdService.rootViewController() else {
            then(); return
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "ads.lastInterstitial")
        onDone = then
        ad.present(from: root)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finish() }
    }
    private func finish() {
        ad = nil
        let done = onDone; onDone = nil
        done?()
        preload()
    }
}

@MainActor
final class RewardedController: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = RewardedController()
    @Published private(set) var isReady = false
    private var ad: RewardedAd?
    private var earned = false
    private var completion: ((Bool) -> Void)?

    func preload() {
        guard AdService.shouldShowAds, ad == nil else { return }
        RewardedAd.load(with: AdService.rewardedUnitID, request: Request()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.ad = ad
                ad?.fullScreenContentDelegate = self
                self.isReady = ad != nil
            }
        }
    }

    /// Presents the rewarded ad; `completion(true)` only if the reward was earned.
    func show(completion: @escaping (Bool) -> Void) {
        guard let ad, let root = AdService.rootViewController() else { completion(false); return }
        earned = false
        self.completion = completion
        ad.present(from: root) { [weak self] in
            Task { @MainActor in self?.earned = true }
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }
    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finish() }
    }
    private func finish() {
        let ok = earned
        ad = nil; isReady = false
        let c = completion; completion = nil
        c?(ok)
        preload()
    }
}
#else
struct BannerAdView: View { var body: some View { EmptyView() } }

@MainActor
final class InterstitialController {
    static let shared = InterstitialController()
    func preload() {}
    func showIfAllowed(gamesPlayed: Int, then: @escaping () -> Void) { then() }
}

@MainActor
final class RewardedController: ObservableObject {
    static let shared = RewardedController()
    @Published private(set) var isReady = false
    func preload() {}
    func show(completion: @escaping (Bool) -> Void) { completion(false) }
}
#endif
