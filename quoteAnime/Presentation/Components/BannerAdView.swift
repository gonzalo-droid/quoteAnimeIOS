import SwiftUI
import GoogleMobileAds

/// UIViewRepresentable wrapping GADBannerView.
/// Usage: BannerAdView(adUnitID: AdConstants.homeBannerID).frame(height: 50)
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

/// Centralized ad unit IDs. Replace with real IDs before production.
enum AdConstants {
    static let homeBannerID       = "ca-app-pub-1427341798923689/4873365993" // AdMob test banner ID
    static let shareInterstitialID = "ca-app-pub-1427341798923689/7805407829" // AdMob test interstitial ID
}
