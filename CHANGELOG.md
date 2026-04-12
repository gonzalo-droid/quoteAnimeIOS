# Changelog

All notable changes to QuoteAnime are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow `MAJOR.MINOR.PATCH` — bumped in Xcode under `MARKETING_VERSION`.

---

## [Unreleased]

### Fixed
- Settings button in Home overlapping the status bar (safe area not respected).
- Back button in QuoteDetailView moved to `.overlay` so SwiftUI manages safe area automatically instead of manual `geo.safeAreaInsets.top` calculation.

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
