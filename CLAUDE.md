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

# StoreKit testing: the shared scheme `quoteAnime` points at `quoteAnimeTests/Premium.storekit`,
# so running from Xcode uses the local store. `simctl launch` cannot: simctl has no StoreKit
# command, and `SKTestSession` aborts outside an XCTest runtime — the purchase flow has to be
# exercised from Xcode.

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
   - `GADApplicationIdentifier` — AdMob app ID, and `SKAdNetworkItems` (Google's
     `cstr6suwn9.skadnetwork`) — both already in `quoteAnime/Info.plist`. No ATT prompt and no
     `NSUserTrackingUsageDescription`: the app does not request tracking. Debug builds use Google's
     test ad units (`AdConstants`).
   - `BGTaskSchedulerPermittedIdentifiers` — if using background refresh
   - Visible Info.plist values (today only `CFBundleDisplayName`) are translated in `quoteAnime/InfoPlist.xcstrings`.

5. **App Group** for widget data sharing: Add capability `group.com.gonzadev.quoteAnime` to both the main app target and the widget extension target.

6. **Widget Extension target** (`QuoteAnimeWidgetExtension`, carpeta `QuoteAnimeWidget/`): ya existe. Sus fuentes viven en esa carpeta sincronizada; los *writers* (`WidgetDataWriter`, `HabitWidgetDataWriter`, `RoutineWidgetRefresher`) se quedan en el target de la app, en `quoteAnime/Widget/`. Deployment target 16.6, igual que la app.

---

## Architecture

**Clean Architecture + MVVM**, three layers: Domain → Data → Presentation.

```
quoteAnime/
├── App/                    # Entry point + DI composition root
│   ├── QuoteAnimeApp.swift     @main, creates AppDependencies + AppRouter
│   ├── AppDependencies.swift   manual DI container (@StateObject at app level)
│   ├── PremiumConfig.swift     THE switch: usesRealBilling (false = mock, StoreKit asleep)
│   ├── PremiumServices.swift   builds gate + store + test controls from that switch
│   └── AppRootView.swift       switches Splash / Onboarding / Main
├── Domain/
│   ├── Model/              Quote, Category, UserPreferences (pure structs)
│   ├── Analytics/          RoutineAnalytics (protocol, one `log(_:)`) + RoutineAnalyticsEvents
│   │                       (pure factories — names and params copied verbatim from Android)
│   ├── Premium/            PremiumGate + PremiumEntitlementSource (protocol) +
│   │                       PremiumEntitlementDecision (pure) + PremiumStore (protocol) +
│   │                       AppDistribution (debug / TestFlight / App Store, pure)
│   ├── Repository/         QuoteRepository, UserPreferencesRepository (protocols)
│   └── UseCase/            one struct per use case, each wraps a single repo call
├── Data/
│   ├── Premium/            MockPremiumEntitlementSource, UnavailablePremiumStore,
│   │                       AppTransactionDistributionDetector (switch off);
│   │                       StoreKitEntitlementSource, StoreKitPremiumStore,
│   │                       DebugPremiumOverrideSource (#if DEBUG only) (switch on)
│   ├── Analytics/          FirebaseRoutineAnalytics (Analytics.logEvent)
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
│   │                       HabitIcons + HabitIconSearch (buscador del selector),
│   │                       HabitThemeImages + ThemedSuggestionPreview (portadas de las plantillas)
│   ├── Subscription/       PaywallView/ViewModel, CancelSubscriptionSheet (hoja de
│   │                       retención), ManageSubscription, SubscriptionOfferText
│   ├── Common/             AppLinks (URLs legales y de App Store, espejo de AppLinks.kt)
│   └── Components/         QuoteCard, BannerAdView, ShareCardView, ActivityViewController
├── Notification/           NotificationScheduler + NotificationHelper
├── Widget/                 WidgetDataWriter (frase actual) + HabitWidgetDataWriter (snapshot de
│                           hábitos) + RoutineWidgetRefresher — todos en el target de la app

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

**Premium — mock until the production release, StoreKit asleep behind one switch.**
`PremiumConfig.usesRealBilling` (in `App/PremiumConfig.swift`) is **`false`** by product decision:
the subscription does not exist in App Store Connect yet. Its `///` lists what must be done before
flipping it (product, Paid Apps agreement, sandbox test on a device). `PremiumServices.make` reads
it once and builds everything premium; `PremiumGate.shared` and `AppDependencies.premium` both come
from `PremiumServices.live`, so there is exactly one entitlement source.

- **Switch `false` (today).** `MockPremiumEntitlementSource` + `UnavailablePremiumStore`. The
  StoreKit types are passed as factories and **never constructed**, so nothing loads products,
  listens to `Transaction.updates` or re-syncs. The paywall (`PremiumPurchaseAvailability.comingSoon`)
  shows the benefits with a disabled "Próximamente", no restore, no manage; free limits apply.
  DEBUG and TestFlight builds show "Activar/Quitar premium (solo pruebas)", which writes
  `pref_is_premium`; an App Store install ignores that flag even when it is `true`.
- **Where the app runs** is `AppDistribution`, decided by an injectable `AppDistributionDetecting`.
  DEBUG → `.debug`. Release → `.appStore` until proven TestFlight: only a binary whose
  `appStoreReceiptURL` ends in `sandboxReceipt` asks `AppTransaction.shared`, and only a verified
  `.sandbox` counts. **Never call `AppTransaction.shared` unconditionally**: with no local app
  transaction it triggers an interactive App Store sign-in at launch (seen on the simulator).
  App Review also runs in sandbox, so a reviewer sees the test switch — see `PARITY.md`.
- **Switch `true`.** Everything below applies again, unchanged from tanda 7.

**Premium (StoreKit 2), behind the switch**: the only type the app talks to about premium is `PremiumGate`
(`ObservableObject`, `.shared`), and it owns no state — it proxies a `PremiumEntitlementSource`.
Two implementations: `StoreKitEntitlementSource`, which reads `Transaction.currentEntitlements`
and listens to `Transaction.updates`, and `DebugPremiumOverrideSource`, which wraps it and is
compiled **only into DEBUG builds**, so a release binary has exactly one possible answer. The
entitlement is re-read at launch and on every return to the foreground (`scenePhase`), mirroring
Android — whose repository documents the foreground re-sync but never wires it up.

- **What actually grants premium** lives in `PremiumEntitlementDecision`, which is pure and takes
  `EntitlementSnapshot` values rather than `StoreKit.Transaction` (which cannot be constructed in
  a test). A `.unverified` transaction never grants premium: Android trusts anything Play reports
  because it has no backend, and that weakness is deliberately not ported.
- **The cache key is `pref_premium_entitlement_cache`, not `pref_is_premium`.** The old key
  belongs to the pre-billing mock, whose "Suscribirme" granted premium locally to anyone who
  tapped it; reusing it would hand all of those users a premium cache. With the switch on,
  `pref_is_premium` means "QA override" and only counts in DEBUG; with it off, it is the test
  premium flag and only counts in DEBUG and TestFlight.
- **Buying** is `PremiumStore` / `StoreKitPremiumStore`, mirroring Android's `BillingRepository`.
  Play's acknowledgement, its 72-hour deadline and its retry worker have no iOS counterpart:
  `Transaction.finish()` is local and cannot fail over the network. Restore, conversely, exists
  only on iOS — the App Store requires it and Play does not.
- **The four gates** read the same gate and nothing else: `CreateHabitUseCase` (active-habit cap),
  `HabitTemplate.isLocked(isPremium:)` (locked suggestions), `ShareAdPolicy` (share
  interstitial) and `BannerAdPolicy` (the banner in the quote opened from Explorar). Losing premium blocks the next creation and never deletes anything.
- Views that show premium state hold the gate as `@ObservedObject` (`SettingsView`,
  `HabitEditorView`, `PaywallView`), or they will not redraw when StoreKit changes its mind.

**Navigation**: `AppRouter` holds `currentScreen: AppScreen` (splash/onboarding/main) and `navigationPath: NavigationPath`. `AppRootView` switches the root; `MainContainerView` wraps `NavigationStack` for in-app push navigation using `AppRoute` enum cases.

**Widget data**: todo viaja por el App Group `group.com.gonzadev.quoteAnime`, porque la extensión
es otro binario y no puede abrir ni SwiftData ni `UserDefaults.standard` de la app.

- **Frase actual** — `WidgetDataWriter.write(_:)` escribe la frase que muestra Home.
- **Animes elegidos** — `UserPreferencesStore` espeja `pref_selected_category_ids` al grupo (misma
  clave), y migra una sola vez lo que ya estaba en `.standard` para no resetear a nadie. La
  extensión filtra con eso su fetch REST a Firebase, como `UpdateQuoteWidgetWorker` en Android.
- **Hábitos** — `HabitWidgetDataWriter` escribe un snapshot JSON (`habit_widget_snapshot`) con,
  por hábito: título, color, ícono ya resuelto a SF Symbol, racha, si está archivado y los días
  marcados de las últimas 9 semanas como texto `yyyy-MM-dd`. Los campos posteriores a la primera
  versión son opcionales: un snapshot viejo se sigue leyendo. **Único punto de entrada para
  reescribirlo: `RoutineWidgetRefresher`** (equivalente a `RoutineWidgetScheduler` de Android),
  inyectado en los view models de rutina, el editor, el onboarding y el delegate de notificaciones.

**Widgets de la extensión** (`QuoteAnimeWidget/`): `QuoteAnimeWidget` + `QuoteAnimeLockWidget`
(frases), `RoutineSummaryWidget` (hábitos activos) y `HabitWidget` (un hábito por instancia, con su
heatmap de 9 semanas). `HabitWidget` usa `AppIntentConfiguration` — el equivalente iOS de
`HabitWidgetConfigureActivity` — y por eso **requiere iOS 17**; el `@available` va en el miembro del
`WidgetBundle` para que el resto siga en 16.6. Guarda el **id** del hábito en un `@Parameter` de
tipo `String` y la lista del selector sale de un `DynamicOptionsProvider`: un `AppEntity` fue el
primer intento y no sobrevivió el viaje de ida y vuelta por la configuración guardada (la hoja de
edición mostraba el hábito elegido y la extensión recibía `nil`). Ver el comentario en
`HabitWidget.swift` antes de volver a intentarlo.

**Duplicación deliberada en el target del widget**: `QuoteAnimeWidget/WidgetSharedModel.swift`
reúne las copias a mano del App Group, el snapshot, `HeatmapGrid` y `HabitPalette`; los tokens de
color (`w`-prefijados) viven en `QuoteAnimeWidget.swift`. **Cuando cambies un lado, cambia el
otro.** `HabitWidgetSnapshot.activeHabits` / `habit(id:)` existen también en el target de la app,
sin llamador, sólo para que los tests puedan fijar lo que decide el selector del widget.

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

### Localization — String Catalogs, English source, Spanish keys, "tú"

The app ships **English and Spanish**, and follows the device language (plus iOS's per-app
language setting). There is no in-app language picker, same as Android. **Nothing user-visible is
hardcoded any more**: every string goes through a catalog.

- **English is the development region and the catalogs' `sourceLanguage`** (`developmentRegion =
  en` in the pbxproj → `CFBundleDevelopmentRegion = en`). That is what makes a phone in any other
  language (pt-BR, fr, de…) fall back to **English**, as Android does with `values/`. Every
  Spanish variant (`es`, `es-ES`, `es-419`, `es-MX`) still resolves to `es.lproj`.
- **Both languages carry an explicit value for every key** — English is the source language but
  its value is never the key. If a key ever lacked its Spanish value, a Spanish speaker would get
  the English one: `LocalizationTests` checks the catalogs *and* the compiled `es.lproj`/`en.lproj`
  tables, and pins the fallback for a table of device languages.

- `quoteAnime/Localizable.xcstrings` — app strings. `QuoteAnimeWidget/Localizable.xcstrings` —
  the widget extension's own catalog (an extension bundle can't read the app's; both targets are
  synchronised folders, so each catalog belongs to its folder's target with no pbxproj change).
  A string used in both places lives in both catalogs.
  `quoteAnime/InfoPlist.xcstrings` — `CFBundleDisplayName`/`CFBundleName`.
- **Keys are the Spanish text itself** (a leftover of the Spanish-source era, kept on purpose:
  migrating ~180 keys across every view was more likely to lose a string than to fix anything).
  In Xcode's catalog editor the English column is therefore an *override* of the key, and a new
  string starts with no English value until you add one. A literal in `Text("…")`, `Button("…")`,
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
  `xcodebuild -exportLocalizations -project quoteanime.xcodeproj -localizationPath /tmp/l10n -exportLanguage en -exportLanguage es`
  and look for units without a `<target>` in both `.xliff` files. The only expected gaps are the
  widget extension's `InfoPlist` keys (`CFBundleDisplayName`, `CFBundleName`,
  `NSHumanReadableCopyright`), which have no catalog.

### Theme

Always dark (`.preferredColorScheme(.dark)` at root). All colors defined as `Color` static extensions in `Theme/Colors.swift`. Quote text uses the system serifs Didot (`Font.quoteSerif(size:)`) and Georgia (`Font.quoteSerifItalic(size:)`) — no bundled fonts; Android bundles Fraunces/Lora/Playfair (see `PARITY.md`).

## Deployment

- Minimum: iOS 16.6 (app and widget extension)
- Optimized: iOS 17+ (vertical scroll paging via `scrollTargetBehavior(.paging)`, SwiftData)
- Portrait only
- Bundle ID: `com.gonzadev.quoteAnime`
- No linting configured
