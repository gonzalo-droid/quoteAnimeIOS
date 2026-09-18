import SwiftUI
import GoogleMobileAds

/// A standard 320×50 AdMob banner — Android's `BannerAd` (`AdSize.BANNER`, fixed, not adaptive).
///
/// It keeps its 50 pt while the ad loads, so a successful load doesn't shove the content, and
/// collapses to nothing if the load fails (no fill, no network, an ad unit AdMob rejects) instead of
/// leaving an empty strip. Android registers no listener and just stays blank; an empty box at the
/// bottom of a screen reads as a layout bug on iOS.
///
/// Whether to show one at all is `BannerAdPolicy`'s call, never the call site's.
struct BannerAdView: View {
    let adUnitID: String
    @State private var didFail = false

    var body: some View {
        BannerAdRepresentable(adUnitID: adUnitID, didFail: $didFail)
            .frame(width: 320, height: didFail ? 0 : 50)
            .opacity(didFail ? 0 : 1)
    }
}

private struct BannerAdRepresentable: UIViewRepresentable {
    let adUnitID: String
    @Binding var didFail: Bool

    func makeCoordinator() -> Coordinator { Coordinator(didFail: $didFail) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.keyWindowRootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = Self.keyWindowRootViewController()
        }
    }

    private static func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let didFail: Binding<Bool>

        init(didFail: Binding<Bool>) {
            self.didFail = didFail
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[BannerAdView] no ad: \(error.localizedDescription)")
            didFail.wrappedValue = true
        }
    }
}

/// AdMob ad unit ids — Android's `buildConfigField`s. **Debug builds use Google's public iOS test
/// units**: serving live ads to our own devices is invalid traffic and can get the AdMob account
/// suspended (Android's own comment says the same). The real units only exist in release.
///
/// These ids are per platform and must never be copied from Android: an ad unit belongs to one
/// AdMob app, and this app's id (`GADApplicationIdentifier` in `Info.plist`) is the iOS one.
enum AdConstants {
    #if DEBUG
    static let bannerID            = "ca-app-pub-3940256099942544/2934735716" // Google test: iOS banner
    static let shareInterstitialID = "ca-app-pub-3940256099942544/4411468910" // Google test: iOS interstitial
    #else
    /// ⚠️ This is the value Android's release build uses for its banner (`BANNER_AD_UNIT_ID`),
    /// not an iOS unit: it predates the port and nothing records where it came from. If AdMob
    /// rejects it for this app the banner just collapses. Create a banner unit under the iOS app
    /// in AdMob and replace it — see `PARITY.md` → Pendiente.
    static let bannerID            = "ca-app-pub-1427341798923689/4873365993"
    static let shareInterstitialID = "ca-app-pub-1427341798923689/7805407829"
    #endif

    /// Google's public test units, for the test that pins the DEBUG ids.
    static let googleTestIDs: Set<String> = [
        "ca-app-pub-3940256099942544/2934735716",
        "ca-app-pub-3940256099942544/4411468910",
    ]
}
