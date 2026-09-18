import Foundation

/// Whether a share has to wait for an interstitial. Pure, so the rule can be checked without
/// loading a real ad.
///
/// It also gives the "no ads" gate a single home. Android has two independent ones — a volatile
/// flag inside `ShareInterstitialManager` and a bare `if (!uiState.isPremium)` at the catalog's
/// banner call site — which means a new ad surface there can forget to check premium.
struct ShareAdPolicy {
    /// Number of shares between each interstitial. Same cadence as Android's `SHARES_PER_AD`.
    let sharesPerAd: Int

    private var shareCount = 0

    init(sharesPerAd: Int = 3) {
        self.sharesPerAd = sharesPerAd
    }

    /// Counts the share and answers whether this one is an ad slot. Premium users never are, and
    /// their shares are not even counted — cancelling premium should not fire an ad on the very
    /// next share because of a counter that kept running.
    mutating func shouldShowAd(isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        shareCount += 1
        return shareCount % sharesPerAd == 0
    }
}
