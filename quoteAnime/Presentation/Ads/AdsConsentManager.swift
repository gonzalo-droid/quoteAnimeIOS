import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// Google's User Messaging Platform (UMP), Android's `AdsConsentManager`: asks for ad consent
/// where the law requires it (EEA, UK, Switzerland and some US states) and starts the ads SDK only
/// once ads may be requested. Elsewhere Google answers that no form is needed and ads start at once.
///
/// The form, its texts and the regions it covers are configured in AdMob → Privacy & messaging,
/// not here. The app still does not ask for tracking (no ATT prompt): consent covers what the law
/// requires, not the IDFA.
///
/// `UserMessagingPlatform` is not linked as its own product: it comes in through the Google Mobile
/// Ads package, which depends on it (see `Package.resolved`). If Xcode ever reports "No such
/// module", add the `GoogleUserMessagingPlatform` product to the app target.
final class AdsConsentManager: ObservableObject {
    static let shared = AdsConsentManager()

    /// True once ads may be requested and the SDK has been started. The banner waits for it.
    @Published private(set) var canRequestAds = false
    /// True when Settings must offer a way to change the ad consent (a UMP policy requirement).
    @Published private(set) var privacyOptionsRequired = false

    private var adsStarted = false
    private var isGathering = false

    private init() {}

    /// Starts the ads SDK if a consent saved in an earlier launch already allows it. Shows nothing.
    func startAdsIfAllowed() {
        guard ConsentInformation.shared.canRequestAds else { return }
        canRequestAds = true
        guard !adsStarted else { return }
        adsStarted = true
        MobileAds.shared.start()
        ShareInterstitialManager.shared.preload()
    }

    /// Refreshes the consent status and shows the form if this user still has to answer it.
    /// Called on every launch, as Google recommends: the status can change between launches.
    func gatherConsent() async {
        startAdsIfAllowed()
        guard !isGathering else { return }
        isGathering = true
        defer { isGathering = false }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            if let root = Self.rootViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // No network or a misconfigured form: keep whatever an earlier launch allowed.
            print("[AdsConsentManager] consent update failed: \(error.localizedDescription)")
        }
        refreshPrivacyOptions()
        startAdsIfAllowed()
    }

    /// Opens the form again so the user can change their choice (Settings → ad privacy).
    func presentPrivacyOptions() async {
        guard let root = Self.rootViewController() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: root)
        } catch {
            print("[AdsConsentManager] privacy options failed: \(error.localizedDescription)")
        }
        refreshPrivacyOptions()
        startAdsIfAllowed()
    }

    private func refreshPrivacyOptions() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// The topmost presented controller, so the form never lands under a sheet.
    private static func rootViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
