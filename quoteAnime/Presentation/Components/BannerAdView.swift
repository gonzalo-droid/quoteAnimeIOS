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
    static let homeBannerID = "ca-app-pub-3940256099942544/2934735716" // AdMob test ID
}
