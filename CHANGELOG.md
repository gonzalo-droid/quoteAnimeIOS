# Changelog

All notable changes to QuoteAnime are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow `MAJOR.MINOR.PATCH` — bumped in Xcode under `MARKETING_VERSION`.

---

## [Unreleased]

### Added
- SwiftUI `#Preview` blocks added to all presentation views: `QuoteCard`, `QuoteDetailView`, `SplashView`, `WidgetTutorialView`, `OnboardingView`, `SettingsView`, `CatalogView`. Views with ViewModels use inline mock repositories.
- **Settings — Apóyanos section**: in-app review prompt via `SKStoreReviewController` (falls back to App Store URL if no active scene), and "Compartir la app" via `ShareLink` with custom invite message.
- **Settings — Síguenos section**: Instagram and Facebook links with deep-link-first strategy (opens native app if installed, browser otherwise). Custom SVG brand icons added to `Assets.xcassets` (`icon_instagram`, `icon_facebook`, `icon_tiktok`).
- **Settings — Información section**: "Política de privacidad" and "Términos y condiciones" items that open their respective pages in-app via `SFSafariViewController` (new `SafariView` component in `Presentation/Components/`).

### Fixed
- Settings button in Home overlapping the status bar (safe area not respected).
- Back button in QuoteDetailView moved to `.overlay` so SwiftUI manages safe area automatically instead of manual `geo.safeAreaInsets.top` calculation.
- Widget always showing placeholder quote — Firebase REST query was missing required `orderBy=%22%24key%22` parameter when using `limitToFirst`, causing Firebase to return an error response that parsed as empty.
- Widget update frequency (set in Settings) now correctly controls the timeline refresh interval — `reloadAllTimelines()` is only called when the user changes the frequency, not on every app launch or quote swipe.

### Changed
- Removed decorative opening quote mark (`\u{201C}`) from `QuoteDetailView`, `OnboardingView`, widget Small/Medium/Inline views, and `ShareImageRenderer`.
- Typography: `quoteSerif` changed from `Georgia` to `Didot`; `quoteSerifItalic` changed from `Georgia-Italic` to `Georgia`.

---

## [1.1.0] — 2025

### Added
- **Category filter** — browse quotes by anime in the Catalog.
- **Background image** — anime artwork loaded behind each quote in the feed.
- **Share with background** — generated share card includes the anime background image.
- **Widget tutorial** — step-by-step guide inside Settings to add the home-screen widget.

### Changed
- Banner ad removed from the quote feed; replaced with an interstitial (`ShareInterstitialManager`) shown every 3 share taps.

---

## [1.0.0] — Initial release

### Added
- Full-screen vertical swipe feed of anime quotes (iOS 17: `scrollTargetBehavior(.paging)`; iOS 16: `TabView` pager).
- Favorites — toggle and persist locally (SwiftData on iOS 17+, UserDefaults JSON on iOS 16).
- Share quote as a generated image card via the system share sheet.
- WidgetKit extension — displays the current quote on the home screen via App Group UserDefaults.
- Daily push notifications — configurable frequency, start/end hour, and interval.
- Onboarding flow shown on first launch.
- Settings screen — notification preferences, widget update frequency, widget tutorial.
- AdMob banner ad integration (subsequently replaced in 1.1.0).
- Firebase Realtime Database as the quotes backend.
- Firebase Analytics + Crashlytics.
- Clean Architecture + MVVM project structure with manual dependency injection.
- Always-dark UI, portrait only, Georgia serif quote typography.
- iOS 16.0 minimum deployment target.
