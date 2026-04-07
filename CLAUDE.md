# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Standard Xcode project. Open `quoteAnime.xcodeproj`. Build with:

```bash
xcodebuild -project quoteAnime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests (once a test target is added)
xcodebuild test -project quoteAnime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Required setup before building

1. **Add all new source files** to the Xcode project target (`quoteAnime`). Files created in the filesystem are not automatically included — drag them into Xcode or use File → Add Files. All subdirectories under `quoteAnime/` need to be added.

2. **Add Swift Package dependencies** via Xcode → File → Add Package Dependencies:
   - Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`  
     Products: `FirebaseDatabase`, `FirebaseCrashlytics`, `FirebaseAnalytics`
   - Google Mobile Ads: `https://github.com/googleads/swift-package-manager-google-mobile-ads`  
     Product: `GoogleMobileAds`

3. **Add `GoogleService-Info.plist`** (Firebase project config) to the app target root.

4. **Info.plist keys** needed (auto-generated plist via `GENERATE_INFOPLIST_FILE = YES`, add in Build Settings → Info):
   - `GADApplicationIdentifier` — AdMob app ID
   - `BGTaskSchedulerPermittedIdentifiers` — if using background refresh
   - `NSUserNotificationUsageDescription`

5. **App Group** for widget data sharing: Add capability `group.com.gonzadev.quoteAnime` to both the main app target and the widget extension target.

6. **Widget Extension target**: Create via File → New → Target → Widget Extension, name `QuoteAnimeWidget`. Move `quoteAnime/Widget/QuoteWidget.swift` to that target (remove from main target). `WidgetDataWriter.swift` stays in the main target.

---

## Architecture

**Clean Architecture + MVVM**, three layers: Domain → Data → Presentation.

```
quoteAnime/
├── App/                    # Entry point + DI composition root
│   ├── QuoteAnimeApp.swift     @main, creates AppDependencies + AppRouter
│   ├── AppDependencies.swift   manual DI container (@StateObject at app level)
│   └── AppRootView.swift       switches Splash / Onboarding / Main
├── Domain/
│   ├── Model/              Quote, Category, UserPreferences (pure structs)
│   ├── Repository/         QuoteRepository, UserPreferencesRepository (protocols)
│   └── UseCase/            one struct per use case, each wraps a single repo call
├── Data/
│   ├── Remote/             QuoteRemoteDataSource (Firebase) + DTOs
│   ├── Local/
│   │   ├── SwiftData/      FavoriteQuoteDAO (iOS 17+), UserDefaultsFavoriteStorage (iOS 16)
│   │   └── Preferences/    UserPreferencesStore (UserDefaults)
│   └── Repository/         QuoteRepositoryImpl, UserPreferencesRepositoryImpl
├── Presentation/
│   ├── Navigation/         AppRouter (ObservableObject, NavigationPath + AppScreen enum)
│   ├── Splash/             SplashView (no ViewModel, callback-based)
│   ├── Onboarding/         OnboardingView + OnboardingViewModel
│   ├── Home/               HomeContainerView → HomeContentView + HomeViewModel
│   ├── Catalog/            CatalogView + CatalogViewModel
│   ├── Settings/           SettingsView + SettingsViewModel + WidgetTutorialView
│   └── Components/         QuoteCard, BannerAdView, ShareCardView, ActivityViewController
├── Notification/           NotificationScheduler + NotificationHelper
├── Widget/                 QuoteWidget.swift (widget target) + WidgetDataWriter.swift (main target)
└── Theme/                  Colors.swift (Color extensions), Typography.swift (Font extensions)
```

### Key patterns

**Dependency injection**: `AppDependencies` (created once as `@StateObject` in `QuoteAnimeApp`) holds all use cases and is injected as `@EnvironmentObject`. ViewModels receive individual use cases via `setup()` called from `.task {}`.

**ViewModel lifecycle**: ViewModels are `ObservableObject` (`@StateObject` in container views). They use a two-phase init — created with defaults, then `setup(deps...)` is called from `.task` once the view appears and environment objects are available. The `setupDone` guard prevents re-initialization on re-render.

**Favorites storage**:
- iOS 17+: `FavoriteQuoteDAO` backed by SwiftData (`FavoriteQuoteModel @Model`). The `ModelContext` is created inside `AppDependencies.init()` — not via the SwiftUI environment.
- iOS 16: `UserDefaultsFavoriteStorage` (JSON-encoded `[Quote]` in UserDefaults).
- Both conform to `FavoriteStorageProtocol`. Selection happens at runtime in `AppDependencies.init()`.

**Navigation**: `AppRouter` holds `currentScreen: AppScreen` (splash/onboarding/main) and `navigationPath: NavigationPath`. `AppRootView` switches the root; `MainContainerView` wraps `NavigationStack` for in-app push navigation using `AppRoute` enum cases.

**Widget data**: `WidgetDataWriter.write(_:)` writes the current quote to `UserDefaults(suiteName: "group.com.gonzadev.quoteAnime")` and calls `WidgetCenter.shared.reloadAllTimelines()`. The Widget extension (`QuoteWidget.swift`) reads from the same App Group.

### Domain models (identical to Android)

```swift
struct Quote: Identifiable, Codable, Hashable { id, quote, author, anime, isFavorite }
struct Category: Identifiable, Hashable { id, name }  // derived from unique anime values
struct UserPreferences { selectedCategoryIds, notificationsEnabled, notificationStart/EndHour/Minute,
                         notificationFrequency (1–10), widgetUpdateTimesPerDay (1–8) }
```

### Firebase structure

- Node `/quotes` — flat array of `{ id, quote, author, anime }` objects
- `QuoteRemoteDataSource` handles both array and dictionary root structures
- Categories derived dynamically from unique `anime` field values

### Theme

Always dark (`.preferredColorScheme(.dark)` at root). All colors defined as `Color` static extensions in `Theme/Colors.swift`. Quote text uses Georgia (serif) via `Font.quoteSerif(size:)` / `Font.quoteSerifItalic(size:)`.

## Deployment

- Minimum: iOS 16.0
- Optimized: iOS 17+ (vertical scroll paging via `scrollTargetBehavior(.paging)`, SwiftData)
- Portrait only
- Bundle ID: `com.gonzadev.quoteAnime`
- No linting configured
