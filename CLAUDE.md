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

1. **New source files need no Xcode step**: `quoteAnime/`, `QuoteAnimeWidget/` and `quoteAnimeTests/` are synchronised folder groups, so a file created on disk is compiled into its target. A new *target* or build setting does touch `project.pbxproj`.

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
   - `CFBundleURLTypes` — the `quoteanime://` scheme, so the widgets' `widgetURL` opens the app (see Navigation). Already in `quoteAnime/Info.plist`.
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
│   ├── Remote/             QuoteRemoteDataSource (Firebase) + DTOs,
│   │                       HabitTemplateRemoteDataSource (`/habitTemplates`) + HabitTemplateDTO
│   ├── Local/
│   │   ├── SwiftData/      FavoriteQuoteDAO (iOS 17+), UserDefaultsFavoriteStorage (iOS 16)
│   │   │                   HabitDAO + HabitModel/HabitCompletionModel (iOS 17+, sin fallback)
│   │   └── Preferences/    UserPreferencesStore (UserDefaults)
│   └── Repository/         QuoteRepositoryImpl, UserPreferencesRepositoryImpl
├── Presentation/
│   ├── Navigation/         AppRouter (ObservableObject, [AppRoute] path + AppScreen enum)
│   │                       + AppDeepLink (reminder tap / widget URL → one entry point)
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
├── Notification/           NotificationScheduler (quote notifications, 64-request budget shared
│                           with habit reminders) + QuoteNotificationSlotCalculator (pure, the
│                           slot arithmetic of Android 4b5d21f) + HabitReminderScheduler + NotificationHelper
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

**Navigation**: `AppRouter` holds `currentScreen: AppScreen` (splash/onboarding/main) and `navigationPath: [AppRoute]` (typed, so a deep link can see what is on screen). `AppRootView` switches the root; `MainContainerView` wraps `NavigationStack` for in-app push navigation using `AppRoute` enum cases.

**Deep links — one door, `AppRouter.open(_:)`**: `AppDeepLink` has two cases. `.quote(id:)` (`quoteanime://home?quoteId=<id>`, Android's `widget_quote_id` → `home?quoteId=`) comes from the quote widgets' `widgetURL`: the router pops to Home and publishes `quoteFocusRequest`, which `HomeContainerView` hands to `HomeViewModel.focus(onQuoteId:)` — it waits for the feed, and a quote the feed doesn't hold (removed, or outside the anime selection) leaves Home where it was. The widget sends the RTDB node key, the same id rule as `QuoteDTO` (`WidgetQuoteID`). `.routine` (Mi Rutina's list, Android's `EXTRA_OPEN_ROUTINE`) has two entry points: the body of a habit reminder (`HabitReminderNotificationDelegate`, via `AppDeepLink.forNotification`) and the routine widgets' `widgetURL(quoteanime://routine)` (received by `.onOpenURL` in `QuoteAnimeApp`). Before `.main` the link is kept as `pendingDeepLink` and applied by `navigateToMain()`, so neither the splash nor an unfinished onboarding is skipped; in `.main` the path becomes `[.routine]`, never a second copy. Below iOS 17 (`isRoutineAvailable == false`) the router ignores `.routine`; `.quote` works everywhere. `QuoteAnimeApp.init` builds `AppDependencies` eagerly — not lazily through `StateObject` — because the notification delegate must exist before launch finishes to receive the tap that cold-launched the app. The widget extension keeps its own copy of both URLs (`WidgetDeepLink`: the routine URL, and the quote host/parameter); `AppDeepLinkTests` reads its source and fails if they drift.

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
reúne las copias a mano del App Group, el snapshot, `HeatmapGrid`, `HabitPalette` y la URL del deep
link (`WidgetDeepLink`); los tokens de
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
- Node `/habitTemplates/{id}` — `title` (an **Android string-resource key**, e.g. `template_theme_ninja`,
  or a literal text), `iconKey`, `order`, `themeColorIndex?`, `themeKey?`, `isPremiumOnly`. Read once
  per editor / onboarding with `getData()`; `GetHabitTemplatesUseCase` falls back to
  `DefaultHabitTemplates` when it is empty, missing, unreachable or entirely invalid. Screens show
  the bundled list first and swap in the remote one. `HabitTemplateTitles` maps Android keys to
  catalog text; an unknown key drops the template (never shown raw). **Absent in production as of
  2026-09-18** — the root only has `imagenes` and `quotes`.
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

---

## Perfil de paridad

Capa específica de este proyecto para el agente `android-to-ios-sync`. El agente es genérico y no
sabe nada de quoteAnime: todo lo concreto lo lee de aquí. Si algo de esta sección deja de ser
cierto, corrígelo aquí — el agente la trata como autoridad por encima de sus propios hábitos.

**1. El par**

| | Ruta | Remoto |
|---|---|---|
| Android (sólo lectura) | `/Volumes/Neko/AndroidStudioProjects/quoteAnime` | `gonzalo-droid/quoteAnime` |
| iOS (donde se escribe) | `/Volumes/Neko/apps_ios/quoteAnime` | `gonzalo-droid/quoteAnimeIOS` |

No hay tag de sincronización en el repo Android: `ios-synced` nunca se ha creado. El alcance sale
de **`PARITY.md`**, que es el libro mayor de este par: léelo antes de calcular cualquier brecha.

**2. Build y tests** — ver [Build & Run](#build--run). Proyecto Xcode clásico,
`quoteanime.xcodeproj` (**minúscula en disco**, el target no). Dos schemes que compilan por
separado: `quoteAnime` y `QuoteAnimeWidgetExtension` — toca el widget y compila los dos.
Tests en el target `quoteAnimeTests` con **Swift Testing** (`@Test`, `#expect`, `@Test(arguments:)`),
fakes a mano sobre protocolos, sin framework de mocking. Correr siempre con
`-parallel-testing-enabled NO`: en esta máquina los clones paralelos del simulador fallan con
`Mach error -308`, que es un problema de entorno y no un test roto.

**3. Arquitectura** — ver [Architecture](#architecture) y [Key patterns](#key-patterns).
Clean Architecture + MVVM; DI manual con `AppDependencies` (**nunca introducir un framework de DI**);
navegación con `AppRouter` + `AppScreen`/`AppRoute` sobre `NavigationStack`; persistencia SwiftData
en iOS 17+ con fallback `UserDefaults` donde existe. Los ViewModels son `ObservableObject` con
`@Published` — este repo **no** usa `@Observable`, y mezclar los dos sistemas rompe la observación.

**4. Design system** — ver [Theme](#theme). Colores sólo desde `Theme/Colors.swift`, tipografía sólo
vía `Font.quoteSerif(size:)` / `.quoteSerifItalic(size:)`; nunca un hex ni un nombre de fuente en una
vista. La app es **dark-only** (`.preferredColorScheme(.dark)` en la raíz): no agregues variante
clara salvo que se pida. `#Preview` en cada vista nueva — el repo los tiene en todas.

Busca aquí antes de escribir algo nuevo: `QuoteDetailView`, `HabitCardView`, `HeatmapGrid`,
`CalendarMonthGrid`, `ActivityViewController`, `ShareCardView`, `QuoteCard`, `HabitPalette`,
`HabitIcons`. Lo compartido vive en `Presentation/Components/`.

**5. Localización** — ver [Localization](#localization--string-catalogs-english-source-spanish-keys-tú),
que es el reglamento completo. En corto: **nada visible se hardcodea**, todo pasa por String Catalog;
la clave es el texto en español; cada clave nueva viaja con su valor en inglés en el mismo commit;
los conteos usan variaciones de plural, nunca `if count == 1`; el registro es **tuteo, nunca voseo**
— `values-es/strings.xml` de Android trae ~16 strings en voseo ("Desbloqueá", "sos", "Cancelá"),
que se convierten al portarlos y se reportan como deuda de Android. `LocalizationTests` falla si a
una clave le falta cualquiera de los dos idiomas.

**6. Decisiones de producto que condicionan el port**

- **StoreKit 2 está implementado pero dormido, por decisión de producto.** Todo el premium pasa
  por un interruptor, `PremiumConfig.usesRealBilling`, que hoy está en **`false`**: el mock responde,
  y los tipos de StoreKit ni siquiera se construyen. Ver
  [Key patterns → Premium](#key-patterns), que es el reglamento completo, y `PARITY.md` para la
  divergencia con Play Billing. Portar trabajo de billing de Android significa respetar el
  interruptor: el comportamiento tiene que funcionar con el switch en `false` (paywall
  "Próximamente") y en `true`. **Nunca cambies el switch a `true`**: requiere el producto en App
  Store Connect, el acuerdo de apps pagas y una prueba en sandbox — es un fork, pregunta.
  **Nunca llames `AppTransaction.shared` sin condición**: dispara un login interactivo del App Store
  al arrancar.
- **Sin selector de idioma en la app**, igual que Android: se sigue el idioma del dispositivo.

**7. Valores que nunca cruzan de plataforma**

- **`selectedCategoryIds`** — espacios de ids distintos. Android guarda ids de Firestore
  (`amor`, `motivación`); iOS guarda **nombres de anime**. Sincronizar el valor corrompe en silencio
  la selección del usuario.
- **El orden de `HabitPalette.colors` y las claves de `HabitIcons`** — se persisten por índice y por
  clave. Reordenar o renombrar repinta todos los hábitos existentes y ningún test lo detecta.
- **Bundle id, App Group (`group.com.gonzadev.quoteAnime`), product ids, firma y keystore** —
  específicos de plataforma por definición.
- **El nombre visible de la app** — distinto a propósito (`QuoteAnime` en iOS, `Frases Anime` /
  `Anime Quotes` en Android). Renombrarlo le cambia el nombre instalado a los usuarios actuales:
  es una decisión de marca, no de paridad.

**8. Documentos que hay que mantener ciertos**

- `CHANGELOG.md` — **Keep a Changelog**: entradas bajo `[Unreleased]` en `Added` / `Changed` /
  `Fixed`, escritas para el usuario, en español, una línea cada una. No subir `MARKETING_VERSION`
  salvo que se pida una release.
- `PARITY.md` — el libro mayor de paridad: una fila por feature con el SHA de Android del que salió,
  y cada divergencia deliberada con su porqué. Se actualiza en el mismo pase que el código.
- `CLAUDE.md` (este archivo) y `README.md` — si el trabajo vuelve falsa una afirmación, se corrige
  en el mismo pase.

**9. Rama, commits y PR**

- Rama en el repo iOS: `feature/ios-sync-<slug>`.
- **Nunca mergear a `main` y nunca pushear.** El usuario revisa la rama, la mergea a `main` él mismo
  (commits `merge: …`) y la pushea; se dice al final del reporte, no se pregunta a mitad del trabajo.
- Commits Conventional Commits con scope `(ios)` y asunto en español, como el historial reciente.

**10. Trampas del repo**

- `core.fileMode` ya está en `false` (el volumen externo hacía ver ~83 archivos modificados por
  cambios de permisos). Si vuelve a aparecer esa avalancha, revísalo antes de commitear.
- **Nunca `git add -A` aquí.** Stagea tus archivos por nombre: el árbol suele cargar trabajo sin
  commitear que es de otro run y no tuyo.
- Los archivos fuente nuevos **no** necesitan paso en Xcode — el proyecto usa carpetas
  sincronizadas. Un **target** nuevo o un build setting sí tocan `project.pbxproj`, y eso es un
  fork: pregunta primero.
- **Probar un recordatorio o un deep link en el simulador**: `xcrun simctl push <udid> com.gonzadev.quoteAnime payload.apns`
  con `"aps": {"category": "HABIT_REMINDER", …}` y `"habitId"` simula el recordatorio, pero **sólo
  se muestra si la app ya tiene permiso de notificaciones** (actívalo desde Ajustes → "Activar
  notificaciones", con un `swipe` corto: el `tap` no mueve el `Toggle`). El banner dura ~5 s: haz
  `push` y el `tap` sobre el banner en llamadas seguidas, sin captura en medio. Tocar la
  notificación desde el Centro de notificaciones **no** abrió la app en el simulador. `simctl openurl
  quoteanime://routine` con la app en segundo plano o cerrada pide confirmar "Open in QuoteAnime?".
  Prueba de que la respuesta llegó: `log show --predicate 'eventMessage CONTAINS "UNNotificationDefaultActionIdentifier"'`.
- **Ver las notificaciones de frases pendientes en el simulador**: en DEBUG, `NotificationScheduler`
  escribe cada horario pendiente en el log (subsistema `com.gonzadev.quoteAnime`, categoría
  `QuoteNotifications`, nivel debug). Los debug no se guardan por defecto: primero
  `xcrun simctl spawn <udid> log config --subsystem com.gonzadev.quoteAnime --mode "level:debug,persist:debug"`,
  después `log show --start "<hora>" --debug --info --predicate 'category == "QuoteNotifications"'`.
  La línea `scheduled N … (M other pending …)` dice cuántos recordatorios de hábitos hay pendientes.
- **Cambiar preferencias de la app sin la UI**: `defaults write` sobre el `.plist` del contenedor
  **desde el Mac** lo pisa el `cfprefsd` del simulador al abrir la app (el valor vuelve). Hay que
  escribir por el simulador, con la ruta completa y la app cerrada:
  `xcrun simctl spawn <udid> defaults write "$(xcrun simctl get_app_container <udid> com.gonzadev.quoteAnime data)/Library/Preferences/com.gonzadev.quoteAnime" pref_notification_frequency -int 3`.
  El `Slider` de Ajustes tampoco responde a un `touch_path` del simulador.
- **Recordatorio de hábito = interruptor + al menos un día.** `Habit.normaliseReminder()` (lo llaman
  `CreateHabitUseCase` y `UpdateHabitUseCase`) guarda "encendido sin días" como apagado, y el editor
  elige los siete días al encender el interruptor. Un hábito viejo guardado así se abre apagado.
- **Duplicación deliberada del widget**: la extensión no puede importar tipos del target de la app,
  así que `QuoteAnimeWidget/WidgetSharedModel.swift` y los tokens `w`-prefijados repiten a mano el
  App Group, el snapshot, `HeatmapGrid`, `HabitPalette` y la URL del deep link. Cuando cambies un lado, cambia el otro y
  dilo en el reporte.
