import Foundation

/// Web destinations owned by the app. Mirrors Android's `presentation/common/AppLinks.kt`
/// so both platforms move together when a domain changes — the legal pages moved from
/// `quote-anime-web.vercel.app` to `animequote.app` in Android commit `0b76ed0`.
///
/// The legal pages open in-app (`SafariView`); the App Store links leave the app.
enum AppLinks {
    static let privacyPolicy      = URL(string: "https://www.animequote.app/privacy-policy")!
    static let termsAndConditions = URL(string: "https://www.animequote.app/terms-and-conditions")!

    /// App Store listing, used both for sharing and for the "write a review" deep link.
    static let appStore       = URL(string: "https://apps.apple.com/app/id6762100338")!
    static let appStoreReview = URL(string: "https://apps.apple.com/app/id6762100338?action=write-review")!
}
