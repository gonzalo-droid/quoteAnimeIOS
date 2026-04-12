# QuoteAnime

iOS app that displays anime quotes in a full-screen, swipeable feed. Users can save favorites, filter by anime, share quotes with custom artwork, and pin the current quote to a home-screen widget.

---

## Features

- Full-screen vertical swipe feed of anime quotes
- Filter by anime category
- Favorites (persisted locally)
- Share quote as a generated image card
- WidgetKit integration — current quote on the home screen
- Daily push notifications with a random quote
- AdMob interstitial between every 3 shares (configurable)
- Dark-only UI

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

6. **Widget Extension**: Create via File → New → Target → Widget Extension, name `QuoteAnimeWidget`. Move `quoteAnime/Widget/QuoteWidget.swift` to that target. `WidgetDataWriter.swift` stays in the main target.

7. **Info.plist keys** (set in Build Settings → Info, the plist is auto-generated):
   - `GADApplicationIdentifier` — AdMob app ID
   - `NSUserNotificationUsageDescription` — notification permission prompt text

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
│   ├── Repository/             # Protocols only
│   └── UseCase/                # One struct per operation
├── Data/                       # Implements domain protocols
│   ├── Remote/                 # Firebase + image fetching
│   ├── Local/                  # SwiftData (iOS 17+) + UserDefaults fallback
│   └── Repository/             # Concrete implementations
├── Presentation/               # SwiftUI views + ViewModels
│   ├── Navigation/             # AppRouter (NavigationPath + screen enum)
│   ├── Home/                   # Full-screen quote feed
│   ├── Catalog/                # Browse/filter quotes by anime
│   ├── Settings/               # Preferences + widget tutorial
│   ├── Onboarding/             # First-launch flow
│   ├── Ads/                    # Interstitial ad manager
│   └── Components/             # Shared: QuoteDetailView, QuoteCard, ShareCardView
├── Notification/               # Local notification scheduling
├── Widget/                     # WidgetDataWriter (main) + QuoteWidget (extension)
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

### Navigation — AppRouter + NavigationPath

`AppRouter` is an `ObservableObject` that owns two pieces of state:
- `currentScreen: AppScreen` — switches the root view between splash / onboarding / main.
- `navigationPath: NavigationPath` — drives the `NavigationStack` inside main.

Routes are typed via the `AppRoute` enum (`catalog`, `settings`, `widgetTutorial`).

**Why not a coordinator pattern:** SwiftUI's `NavigationStack` + `NavigationPath` already provides type-safe push navigation. A coordinator layer would duplicate that state.

### Firebase — flat array structure

Quotes are stored under `/quotes` as a flat array of `{ id, quote, author, anime }`. Categories are derived at runtime from the unique set of `anime` field values — no separate `/categories` node exists.

**Why:** Reduces Firebase read overhead and avoids keeping two nodes in sync. Category filtering happens in memory after a single fetch.

### Ad strategy — interstitial on share

A banner ad was evaluated and removed. Instead, `ShareInterstitialManager` shows a full-screen interstitial every `sharesPerAd` (default: 3) share taps. If the ad fails to load or present, the share always proceeds immediately.

**Why:** Interstitials at natural breakpoints (sharing intent) are less disruptive than a persistent banner and typically yield higher eCPM.

### Widget data sharing — App Group UserDefaults

`WidgetDataWriter.write(_:)` writes the active quote to `UserDefaults(suiteName: "group.com.gonzadev.quoteAnime")` and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget extension reads from the same suite.

**Why not CloudKit / background fetch:** The widget only needs to reflect what the user is currently reading. App Group UserDefaults is synchronous, requires no network, and reloads immediately.

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
