# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Standard Xcode project. Open `quoteAnime.xcodeproj`. Build with:

```bash
# The project file is lowercase on disk: quoteanime.xcodeproj
xcodebuild -project quoteanime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project quoteanime.xcodeproj -scheme QuoteAnimeWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Tests (target quoteAnimeTests, Swift Testing)
xcodebuild test -project quoteanime.xcodeproj -scheme quoteAnime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run the app in a given language without touching the simulator's settings
xcrun simctl launch booted com.gonzadev.quoteAnime -AppleLanguages "(en)" -AppleLocale en_US
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
   - Visible Info.plist values (today only `CFBundleDisplayName`) are translated in `quoteAnime/InfoPlist.xcstrings`.

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
│   │   │                   HabitDAO + HabitModel/HabitCompletionModel (iOS 17+, sin fallback)
│   │   └── Preferences/    UserPreferencesStore (UserDefaults)
│   └── Repository/         QuoteRepositoryImpl, UserPreferencesRepositoryImpl
├── Presentation/
│   ├── Navigation/         AppRouter (ObservableObject, NavigationPath + AppScreen enum)
│   ├── Splash/             SplashView (no ViewModel, callback-based)
│   ├── Onboarding/         OnboardingView + OnboardingViewModel
│   ├── Home/               HomeContainerView → HomeContentView + HomeViewModel
│   ├── Catalog/            CatalogView + CatalogViewModel
│   ├── Settings/           SettingsView + SettingsViewModel + WidgetTutorialView
│   │                       + CategorySelectionView/ViewModel (elegir animes)
│   ├── Routine/            RoutineView/ViewModel (lista "Mi Rutina"),
│   │                       HabitDetailView/ViewModel (heatmap 26 semanas + calendario
│   │                       mensual con marcado retroactivo), HabitEditorView/ViewModel,
│   │                       HabitCardView, HabitHeatmapView, HabitCalendarMonthView,
│   │                       HeatmapGrid + CalendarMonthGrid (geometría pura), HabitPalette,
│   │                       HabitIcons
│   ├── Common/             AppLinks (URLs legales y de App Store, espejo de AppLinks.kt)
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

**Habits storage ("Mi Rutina")**: `HabitDAO` over SwiftData, iOS 17+ only — there is no iOS 16 fallback, so `AppDependencies.habitRepository` is nil below 17 and every entry point checks `isRoutineAvailable` before offering the feature.

**Two SwiftData stores, both named**: the app builds two `ModelContainer`s with different schemas (favorites, habits). Each `ModelConfiguration` **must** be given a name (`"Favorites"`, `"Habits"`). An anonymous configuration defaults every store to the same `default.store` file; with two schemas pointing at it, each container finds the file incompatible with its own model and SwiftData recreates it, so every cold launch wiped the other container's data. Never make either configuration anonymous again.

**Habit schema migration**: adding `endDate` (optional) to `HabitModel` is resolved by SwiftData's implicit lightweight migration — verified by installing the previous build, creating habits and completions, and installing the new one over it. A rename, a removal, or an optional becoming non-optional would need a real `VersionedSchema` + `SchemaMigrationPlan`.

**Habit validation lives in the use cases**, mirroring Android: `CreateHabitUseCase` / `UpdateHabitUseCase` own the blank-title and `endDate < startDate` checks plus the trimming, and `ToggleHabitCompletionUseCase` rejects an unknown habit, a future day and a day outside the habit's window (`Habit.isActiveOn`). Views must not duplicate these rules — `HabitCalendarMonthView` only *disables* the days the use case would reject.

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
- Categories derived dynamically from unique `anime` field values (19 hoy, 307 frases)
- `selectedCategoryIds` guarda **nombres de anime**, no ids remotos. Set vacío = todos, igual que
  en Android. Se aplica en `GetAllQuotesUseCase.filtered` (feed) y en
  `RescheduleQuoteNotificationsUseCase` (pozo de notificaciones); se elige en
  Ajustes → Contenido → Animes

### Localization — String Catalogs, Spanish source, "tú"

The app ships **Spanish (source/development language, `es`) and English**, and follows the
device language (plus iOS's per-app language setting). There is no in-app language picker, same
as Android. **Nothing user-visible is hardcoded any more**: every string goes through a catalog.

- `quoteAnime/Localizable.xcstrings` — app strings. `QuoteAnimeWidget/Localizable.xcstrings` —
  the widget extension's own catalog (an extension bundle can't read the app's; both targets are
  synchronised folders, so each catalog belongs to its folder's target with no pbxproj change).
  A string used in both places lives in both catalogs.
  `quoteAnime/InfoPlist.xcstrings` — `CFBundleDisplayName`/`CFBundleName`.
- **Keys are the Spanish text itself** (Xcode's default). A literal in `Text("…")`, `Button("…")`,
  `Label`, `.navigationTitle`, `.accessibilityLabel`, `Toggle`, `LocalizedStringKey` or
  `LocalizedStringResource` is extracted automatically. Text that lives in a `String` (view
  models, models, notification content, alert bodies) must be built with
  `String(localized: "…")`. Content that must never be translated — quotes, authors, anime
  names, the habit's own title — goes through `Text(verbatim:)` or a `String` variable.
- **Every new string needs its English entry in the catalog in the same change.**
  `LocalizationTests` fails if any key lacks a `translated` Spanish or English value, or if a
  translation drops/adds a `%@`/`%lld`. It reads the catalogs from the source tree.
- **Register: tú, never vos.** "Toca", "Elige", "puedes", "Ya eres premium". Reuse Android's
  wording (`app/src/main/res/values{,-es}/strings.xml`) whenever a string has an equivalent.
- **Counts use plural variations in the catalog**, never `if count == 1`: interpolate the number
  (`"\(n) días seguidos"`) and give the key `one`/`other` forms. Tests in `LocalizationTests`
  pin each plural in both languages.
- **Changing a Spanish text changes its key.** Update the catalog entry (both languages) in the
  same commit, or the old key goes stale and the new one ships untranslated.
- Keys looked up at runtime instead of from a literal (the habit reminder body, resolved at
  delivery time with `localizedUserNotificationString(forKey:)`) are marked
  `extractionState: manual` in the catalog so Xcode doesn't flag them as stale.
- Dates, month names and weekday initials come from `Calendar`/`FormatStyle` with the user's
  locale (`veryShortStandaloneWeekdaySymbols` for initials); never hardcode "L M X…".
- Persistence keys, Firestore ids (`"motivación"`), `print("[Type] …")` logs and `#Preview` data
  stay as they are.
- To check that everything the compiler extracts is in the catalogs, run
  `xcodebuild -exportLocalizations -project quoteanime.xcodeproj -localizationPath /tmp/l10n -exportLanguage en`
  and look for units without a `<target>` in `en.xcloc/Localized Contents/en.xliff`.

### Theme

Always dark (`.preferredColorScheme(.dark)` at root). All colors defined as `Color` static extensions in `Theme/Colors.swift`. Quote text uses Georgia (serif) via `Font.quoteSerif(size:)` / `Font.quoteSerifItalic(size:)`.

## Deployment

- Minimum: iOS 16.6 (app and widget extension)
- Optimized: iOS 17+ (vertical scroll paging via `scrollTargetBehavior(.paging)`, SwiftData)
- Portrait only
- Bundle ID: `com.gonzadev.quoteAnime`
- No linting configured
