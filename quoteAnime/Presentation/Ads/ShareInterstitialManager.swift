import UIKit
import GoogleMobileAds

/// Singleton that gates the share flow behind an interstitial ad every `sharesPerAd` shares.
/// The counter is session-only (not persisted). If the ad fails, the share always proceeds.
final class ShareInterstitialManager: NSObject {
    static let shared = ShareInterstitialManager()

    private var interstitial: InterstitialAd?
    private var pendingOnProceed: (() -> Void)?

    /// The "no ads" gate. Lives in one place so a future ad surface has somewhere to ask.
    private var policy = ShareAdPolicy()

    private override init() {
        super.init()
        preload()
    }

    // MARK: - Public

    /// Call when the user taps the share button from any screen.
    /// - Premium users never see this ad — proceeds immediately.
    /// - If this is the Nth share (multiple of `sharesPerAd`) and an ad is ready: shows it, then calls `onProceed`.
    /// - Otherwise: calls `onProceed` immediately.
    /// The share always proceeds even if the ad fails.
    func onShareRequested(onProceed: @escaping () -> Void) {
        guard policy.shouldShowAd(isPremium: PremiumGate.shared.isPremium) else {
            onProceed()
            return
        }
        if let ad = interstitial {
            interstitial = nil
            pendingOnProceed = onProceed
            guard let vc = rootViewController() else {
                // No root VC available — skip ad
                proceed()
                return
            }
            ad.present(from: vc)
        } else {
            onProceed()
        }
    }

    /// Pre-loads the next interstitial in background. Safe to call multiple times — no-ops if already loaded.
    func preload() {
        // Premium users never see this ad, so there is nothing to warm up — same as Android.
        guard !PremiumGate.shared.isPremium, interstitial == nil else { return }
        let request = Request()
        InterstitialAd.load(
            with: AdConstants.shareInterstitialID,
            request: request
        ) { [weak self] ad, error in
            guard let self, error == nil, let ad else { return }
            self.interstitial = ad
            self.interstitial?.fullScreenContentDelegate = self
        }
    }

    // MARK: - Private

    private func proceed() {
        pendingOnProceed?()
        pendingOnProceed = nil
        preload()
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - GADFullScreenContentDelegate

extension ShareInterstitialManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        proceed()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[ShareInterstitialManager] failed to present: \(error.localizedDescription)")
        proceed()
    }
}
