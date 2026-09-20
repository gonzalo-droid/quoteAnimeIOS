# QuoteAnime

![Version](https://img.shields.io/badge/version-1.0.6%20(16)-blue)
![Platform](https://img.shields.io/badge/iOS-16.6%2B-brightgreen)
![License](https://img.shields.io/badge/license-Proprietary-lightgrey)

[App Store](https://apps.apple.com/app/id6762100338)

QuoteAnime shows motivational quotes from the anime you already love, one per screen, read
the way you read a feed: swipe up for the next one. Pick which series the feed draws from,
save the ones that stick, share any of them as an image card, and pin one to your home or
lock screen.

On iOS 17 and later it also ships **Mi Rutina**, an anime-themed habit tracker — pick habits
from themed templates, mark them done, and watch a streak counter and a heatmap fill in.

---

## Screenshots

> Pending. Screens to capture, in flow order: Onboarding · Quote feed · Catalog ·
> Mi Rutina · Settings · Widgets

<!-- TODO: capturar y reemplazar por la tabla de imágenes -->

---

## Features

| Feature | Detail |
|---|---|
| **Full-screen quote feed** | Vertical paging, one quote per screen, drawn from the animes you selected |
| **Anime selection** | Settings → Contenido → Animes; drives the feed, the notifications and the quote widget |
| **Catalog** | Browse and filter quotes by anime, or list only favorites |
| **Favorites** | SwiftData on iOS 17+, a JSON fallback in UserDefaults on iOS 16 — both offline |
| **Share as image** | Renders a quote card and opens the system share sheet |
| **Quote notifications** | Time window plus 1–10 per day, spread end to end across the window; up to 64 are pre-scheduled and refilled in the background |
| **Mi Rutina (habit tracker)** | iOS 17+ only: habits from themed templates, current and best streak, heatmap, month calendar with retroactive marking, archive / restore / delete |
| **Habit reminders** | Per-habit local notification with a "Hecho" action that marks the day without opening the app |
| **Home-screen widgets** | Quote (small, medium), Mi Rutina summary (small, medium, large) and a single-habit widget whose habit is chosen in its configuration picker |
| **Lock-screen widget** | Quote in the rectangular and inline accessory families |
| **Deep links** | Tapping a reminder or a routine widget opens Mi Rutina; tapping the quote widget opens Home on that quote |
| **Premium** | Lifts the three-habit free limit and removes ads. **Currently a mock**: StoreKit 2 is implemented but disabled by `PremiumConfig.usesRealBilling`, so the paywall shows a disabled "Próximamente" button |
| **Ads** | Interstitial every third share plus one banner in a quote opened from Explorar; premium users see neither |
| **Localization** | Spanish and English via String Catalogs, English for any other device language |
| **Dark theme** | Always dark |

---

## Tech Stack

- **Language**: Swift (the project builds in the Swift 5 language mode; `SWIFT_VERSION = 5.0`)
- **UI**: SwiftUI, always dark
- **Architecture**: Clean Architecture + MVVM, manual DI (`AppDependencies`)
- **Remote**: Firebase Realtime Database (firebase-ios-sdk 12.12.0) + Analytics + Crashlytics
- **Local persistence**: SwiftData (iOS 17+), UserDefaults fallback for favorites on iOS 16
- **Billing**: StoreKit 2 — written, currently switched off (see Features)
- **Widgets**: WidgetKit + AppIntents, data shared through an App Group
- **Notifications**: UserNotifications (local only)
- **Ads**: Google Mobile Ads 13.2.0
- **Localization**: String Catalogs (`.xcstrings`), English source language
- **Tests**: Swift Testing — 437 cases across 38 files

---

## Architecture

```
quoteAnime/
├── App/                  # Entry point, AppDependencies (DI), PremiumConfig, PremiumServices
├── Domain/               # Model/, Repository/ (protocols), UseCase/, Premium/, Analytics/
├── Data/
│   ├── Remote/           # Quote, anime images and habit templates from RTDB + DTOs
│   ├── Local/            # SwiftData DAOs, UserDefaults stores, preferences
│   ├── Premium/          # StoreKit and mock entitlement sources
│   └── Repository/       # Concrete implementations of the domain protocols
├── Presentation/
│   ├── Navigation/       # AppRouter (AppScreen + typed AppRoute path)
│   ├── Splash/ Onboarding/ Home/ Catalog/ Settings/
│   ├── Routine/          # Mi Rutina
│   ├── Subscription/     # Paywall, manage subscription
│   └── Ads/ Common/ Components/
├── Notification/         # Quote scheduling + slot calculator, habit reminders, background refresh
├── Widget/               # Writers that feed the extension through the App Group
└── Theme/                # Colors, typography

QuoteAnimeWidget/         # Extension: quote, lock screen, routine summary, per-habit widget
quoteAnimeTests/          # Swift Testing suite
```

---

## Requirements & Setup

| Tool | Version |
|---|---|
| Xcode | builds with 26.2 |
| iOS deployment target | 16.6 (app and widget extension) |
| Swift language mode | 5 |

The project file on disk is **`quoteanime.xcodeproj`** — lowercase, unlike the target name.

### Files that are not in the repo

| File | Why |
|---|---|
| `quoteAnime/GoogleService-Info.plist` | Firebase config, git-ignored. Download it from the Firebase console and add it to the app target. |

### Steps

1. Clone the repo and open `quoteanime.xcodeproj`.
2. Let Xcode resolve the Swift packages (pinned in `Package.resolved`): Firebase iOS SDK and
   Google Mobile Ads.
3. Add `GoogleService-Info.plist` to the app target.
4. In Signing & Capabilities, on **both** the app and the widget extension, enable the App
   Group `group.com.gonzadev.quoteAnime`. The app target also needs Push Notifications.

Source files are picked up automatically: the project uses Xcode 16 synchronised folder
groups, so nothing has to be dragged into the navigator. A new *target* or build setting
still means editing `project.pbxproj`.

### Build and test

```bash
xcodebuild -project quoteanime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild test -project quoteanime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Versioning

Current release: **1.0.6** (build 16)

This project follows [Semantic Versioning](https://semver.org/). The full release history
lives in [CHANGELOG.md](CHANGELOG.md).

---

## Privacy Policy

The published privacy policy and terms of service open inside the app and are declared in
`Presentation/Common/AppLinks.swift`:

- https://www.animequote.app/privacy-policy
- https://www.animequote.app/terms-and-conditions

---

## Technical Decisions

### Dependency Injection — manual, no framework

`AppDependencies` is a manual DI container created once as `@StateObject` in `QuoteAnimeApp` and injected via `@EnvironmentObject`. ViewModels receive only the use cases they need through a `setup()` call from `.task {}`.

**Why manual DI:** The object graph is small and stable. A DI framework would add a compile-time dependency for minimal gain at this scale.

### ViewModel lifecycle — two-phase init

ViewModels are instantiated with `@StateObject` (empty defaults), then `setup(deps...)` is called from `.task` once the view appears and environment objects are available. A `setupDone` guard prevents re-running on re-render.

**Why:** Avoids a circular dependency between `@StateObject` init and `@EnvironmentObject` availability. The pattern keeps ViewModels testable in isolation without SwiftUI.

### Favorites storage — runtime strategy selection

- **iOS 17+**: `FavoriteQuoteDAO` backed by SwiftData (`@Model`).
- **iOS 16**: `UserDefaultsFavoriteStorage` (JSON-encoded `[Quote]`).

Both conform to `FavoriteStorageProtocol`. Selection is made at runtime in `AppDependencies.init()` via `#available(iOS 17, *)`.

**Why SwiftData:** Native persistence with `@Observable`-compatible models. The UserDefaults fallback keeps the iOS 16 minimum deployment target viable without shipping CoreData boilerplate.

### Habits storage — SwiftData only, and a named store per schema

"Mi Rutina" is iOS 17+ only: `HabitDAO` over SwiftData, with no UserDefaults fallback, so `AppDependencies.habitRepository` is nil below iOS 17 and the feature hides itself there.

Both SwiftData containers (favorites and habits) pass a **named** `ModelConfiguration`. An anonymous one defaults to a shared `default.store`, which two different schemas cannot share: each container would find the file incompatible and recreate it, wiping the other's data on every cold launch.

### Navigation — AppRouter + a typed path

`AppRouter` is an `ObservableObject` that owns two pieces of state:
- `currentScreen: AppScreen` — switches the root view between splash / onboarding / main.
- `navigationPath: [AppRoute]` — drives the `NavigationStack` inside main.

Routes are typed via the `AppRoute` enum (`catalog`, `settings`, `routine`, `habitDetail`, `habitEditor`, `paywall`…).

**Deep links** go through one method, `AppRouter.open(_:)`: tapping a habit reminder and tapping a routine widget (`quoteanime://routine`) both open Mi Rutina; tapping the quote widget (`quoteanime://home?quoteId=…`) opens Home on that quote. A link that arrives during the splash or the onboarding waits for them to finish.

**Why not a coordinator pattern:** SwiftUI's `NavigationStack` with a typed path already provides type-safe push navigation. A coordinator layer would duplicate that state.

### Firebase — flat array structure

Quotes are stored under `/quotes` as a flat array of `{ id, quote, author, anime }`. Categories are derived at runtime from the unique set of `anime` field values — no separate `/categories` node exists.

**Why:** Reduces Firebase read overhead and avoids keeping two nodes in sync. Category filtering happens in memory after a single fetch.

### Ad strategy — interstitial on share, one banner in Explorar

`ShareInterstitialManager` shows a full-screen interstitial every `sharesPerAd` (default: 3) share taps. If the ad fails to load or present, the share always proceeds immediately. A 320×50 banner sits under the actions of a quote opened from Explorar; Home has none. That is exactly what the Android app ships today (its Home banner is commented out since the interstitial replaced it). Premium users see neither: `ShareAdPolicy` and `BannerAdPolicy` are the only places that ask.

Debug builds request Google's public test ad units (`AdConstants`); serving live ads to our own devices is invalid traffic. The app does not request App Tracking Transparency, so the SDK never reads the IDFA.

**Why:** Interstitials at natural breakpoints (sharing intent) are less disruptive than a persistent banner and typically yield higher eCPM; the single banner mirrors Android so both apps monetise the same screens.

### Widget data sharing — App Group UserDefaults

`WidgetDataWriter.write(_:)` writes the active quote to `UserDefaults(suiteName: "group.com.gonzadev.quoteAnime")` and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget extension reads from the same suite.

The same App Group carries the user's anime selection (`pref_selected_category_ids`, mirrored from `UserDefaults.standard` by `UserPreferencesStore`), which the quote widget filters its own fetch with, and a JSON snapshot of the user's habits (`habit_widget_snapshot`) written by `HabitWidgetDataWriter` — title, colour, glyph, streak, archived flag and the last 9 weeks of marked days. `RoutineWidgetRefresher` is the only thing that rewrites it, and does so after every habit change.

**Why a snapshot and not SwiftData:** the widget extension is a separate binary and cannot open the app's `ModelContainer`. The snapshot is also what the per-habit widget's `EntityQuery` reads to list habits in its configuration picker.

**Why not CloudKit / background fetch:** The widget only needs to reflect what the user is currently reading. App Group UserDefaults is synchronous, requires no network, and reloads immediately.

### Localization — String Catalogs, English source language, Spanish keys

`Localizable.xcstrings` in the app and a separate one in the widget extension (an extension can't read the app bundle's catalog). English is the development/source language, so any device language other than Spanish or English falls back to English, as on Android. Keys are still the Spanish text, and both languages have an explicit value for every key; English translations reuse the Android app's wording where one exists. Plurals ("1 día seguido" / "5 días seguidos") are catalog plural variations, not `if` branches. The Spanish register is "tú" throughout. `LocalizationTests` fails if any key is missing its Spanish or English value. See `CLAUDE.md` → Localization for the rules.

### UI — always dark

`preferredColorScheme(.dark)` is enforced at the root. The project declares all four interface orientations and nothing locks them in code, so the app does rotate. All colors are `Color` static extensions in `Theme/Colors.swift`. Quote text uses Georgia (serif) via custom `Font` extensions.

**Why always dark:** Anime artwork reads better on dark backgrounds and the intended aesthetic is cinematic.

---

## Theme

| Token | Usage |
|-------|-------|
| `Color.bgDark` | Main background |
| `Color.accentPurple` | Interactive elements, anime label |
| `Color.textSecondary` | Captions, metadata |
| `Color.heartRed` | Favorite state |
| `Font.quoteSerif(size:)` | Quote body text (Georgia) |
| `Font.quoteSerifItalic(size:)` | Italic quote variant |

---

## Bundle

- Bundle ID: `com.gonzadev.quoteAnime`
- App Group: `group.com.gonzadev.quoteAnime`
- Minimum deployment: iOS 16.6
- Optimized features on iOS 17+: `scrollTargetBehavior(.paging)`, SwiftData

---

## License

Copyright © 2026 Gondroid. All rights reserved.

This source code is proprietary. It may be viewed for reference, but it may not be
copied, modified, redistributed, or published to any app store without written
permission.

Quotes, characters, and artwork belong to their respective rights holders. The license
above covers this application's source code only, not third-party content.
