import Foundation
import Testing
@testable import quoteAnime

/// AdMob banners (Android `fcfcd28`, `438e1b4`, `727f872`): where they go today and who sees them.
@Suite("Banners de AdMob")
struct BannerAdPolicyTests {

    @Test("el detalle de frase abierto desde Explorar muestra banner sin premium")
    func catalogDetailShowsBannerForFreeUsers() {
        #expect(BannerAdPolicy.showsBanner(at: .catalogQuoteDetail, isPremium: false))
    }

    @Test("premium nunca ve un banner, en ningún lugar", arguments: BannerAdPlacement.allCases)
    func premiumNeverSeesBanners(placement: BannerAdPlacement) {
        #expect(!BannerAdPolicy.showsBanner(at: placement, isPremium: true))
    }

    /// Android's `HomeScreen.kt` has the banner commented out since the share interstitial replaced
    /// it. Replicating the current state, not the history: if Android turns it back on, this test
    /// is the one to flip.
    @Test("Home no muestra banner, igual que Android hoy", arguments: [false, true])
    func homeHasNoBanner(isPremium: Bool) {
        #expect(!BannerAdPolicy.showsBanner(at: .home, isPremium: isPremium))
    }

    /// The test target builds in Debug, so this pins what a development build requests.
    @Test("en DEBUG los anuncios piden las unidades de prueba de Google")
    func debugUsesGoogleTestUnits() {
        #expect(AdConstants.googleTestIDs.contains(AdConstants.bannerID))
        #expect(AdConstants.googleTestIDs.contains(AdConstants.shareInterstitialID))
        #expect(AdConstants.bannerID != AdConstants.shareInterstitialID)
    }

    @Test("Info.plist declara la red SKAdNetwork de Google")
    func infoPlistDeclaresGoogleSKAdNetwork() throws {
        let items = try #require(Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: String]])
        #expect(items.contains { $0["SKAdNetworkIdentifier"] == "cstr6suwn9.skadnetwork" })
    }
}
