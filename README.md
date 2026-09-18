# QuoteAnime

iOS app that displays anime quotes in a full-screen, swipeable feed. Users can save favorites, filter by anime, share quotes with custom artwork, and pin the current quote to a home-screen widget.

---

## Features

- Full-screen vertical swipe feed of anime quotes
- Filter by anime category
- Pick which animes the feed and the notifications draw from (Settings → Contenido → Animes)
- Favorites (persisted locally)
- Share quote as a generated image card
- WidgetKit — current quote (home + lock screen), a routine summary, and a per-habit widget with its activity map
- Daily push notifications with a random quote
- "Mi Rutina" habits: themed suggestions with cover art, an icon picker you can search by name, a heatmap and a month calendar
- AdMob interstitial between every 3 shares (configurable), plus a banner under a quote opened from Explorar — none of either for premium
- "Mi Rutina" events in Firebase Analytics, with the same names and parameters as the Android app
- Dark-only UI
- Spanish and English, following the device language (String Catalogs)

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15+ |
| iOS target | 16.0+ |
| Swift | 5.9+ |

---

## Setup

1. **Clone the repo** and open `quoteAnime.xcodeproj`.

2. **Add Swift Package dependencies** via Xcode → File → Add Package Dependencies:
   - Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`  
     Products: `FirebaseDatabase`, `FirebaseCrashlytics`, `FirebaseAnalytics`
   - Google Mobile Ads: `https://github.com/googleads/swift-package-manager-google-mobile-ads`  
     Product: `GoogleMobileAds`

3. **Add `GoogleService-Info.plist`** (Firebase project config) to the app target root.

4. **Add source files to the target** — new files are not added automatically in Xcode. Drag any new files into the project navigator or use File → Add Files.

5. **Capabilities to enable** in Xcode → Signing & Capabilities:
   - App Groups: `group.com.gonzadev.quoteAnime` (both main target and widget extension)
   - Push Notifications
   - Background Modes → Background fetch (optional, for widget refresh)

6. **Widget Extension**: `QuoteAnimeWidgetExtension` already exists; its sources live in the synchronised `QuoteAnimeWidget/` folder. The writers (`WidgetDataWriter`, `HabitWidgetDataWriter`, `RoutineWidgetRefresher`) stay in the main target under `quoteAnime/Widget/`.

7. **Info.plist keys** (set in Build Settings → Info, the plist is auto-generated):
   - `GADApplicationIdentifier` — AdMob app ID
   - Visible Info.plist values are translated in `quoteAnime/InfoPlist.xcstrings`

### Build

```bash
xcodebuild -project quoteAnime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

---

## Architecture

The app follows **Clean Architecture + MVVM**, split into three layers with strict unidirectional dependencies: Domain ← Data ← Presentation.

```
quoteAnime/
├── App/                        # Entry point and DI composition root
├── Domain/                     # Business rules, no framework imports
│   ├── Model/                  # Quote, Category, UserPreferences
│   ├── Analytics/              # RoutineAnalytics protocol + event factories (Android's names)
│   ├── Repository/             # Protocols only
│   └── UseCase/                # One struct per operation
├── Data/                       # Implements domain protocols
│   ├── Remote/                 # Firebase + image fetching
│   ├── Analytics/              # FirebaseRoutineAnalytics
│   ├── Local/                  # SwiftData (iOS 17+) + UserDefaults fallback
│   └── Repository/             # Concrete implementations
├── Presentation/               # SwiftUI views + ViewModels
│   ├── Navigation/             # AppRouter ([AppRoute] path + screen enum) + AppDeepLink
│   ├── Home/                   # Full-screen quote feed
│   ├── Catalog/                # Browse/filter quotes by anime
│   ├── Settings/               # Preferences + anime selection + widget tutorial
│   ├── Onboarding/             # First-launch flow
│   ├── Routine/                # "Mi Rutina": habit list, detail (heatmap + month
│   │                           #  calendar with retroactive marking), editor
│   ├── Ads/                    # Interstitial manager, ShareAdPolicy, BannerAdPolicy
│   ├── Common/                 # AppLinks (legal + App Store URLs)
│   └── Components/             # Shared: QuoteDetailView, QuoteCard, ShareCardView
├── Notification/               # Local notification scheduling
├── Widget/                     # WidgetDataWriter + HabitWidgetDataWriter + RoutineWidgetRefresher
└── Theme/                      # Colors.swift, Typography.swift
```

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

**Deep links** go through one method, `AppRouter.open(_:)`: tapping a habit reminder and tapping a routine widget (`quoteanime://routine`) both open Mi Rutina. A link that arrives during the splash or the onboarding waits for them to finish.

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

### UI — always dark, portrait only

`preferredColorScheme(.dark)` is enforced at the root. All colors are `Color` static extensions in `Theme/Colors.swift`. Quote text uses Georgia (serif) via custom `Font` extensions.

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
- Minimum deployment: iOS 16.0
- Optimized features on iOS 17+: `scrollTargetBehavior(.paging)`, SwiftData
