import Foundation

/// Where a banner could go, and whether it does — pure, so the rule is testable without an ad.
///
/// Mirrors what Android ships **today**, not its history: the banner was born on Home (`fcfcd28`),
/// moved to the quote detail opened from the catalog (`727f872`), and Home's call is commented out
/// since the share interstitial replaced it (`HomeScreen.kt`). Premium never sees one, like
/// `if (!uiState.isPremium)` in Android's `CatalogScreen` — and like `ShareAdPolicy`, the question
/// is asked here and only here.
enum BannerAdPlacement: CaseIterable {
    /// The full-screen quote opened from Explorar.
    case catalogQuoteDetail
    /// Home's quote pager. Off on both platforms since the share interstitial replaced it.
    case home
}

enum BannerAdPolicy {
    static func showsBanner(at placement: BannerAdPlacement, isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        switch placement {
        case .catalogQuoteDetail: return true
        case .home: return false
        }
    }
}
