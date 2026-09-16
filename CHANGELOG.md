# Changelog

All notable changes to QuoteAnime are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow `MAJOR.MINOR.PATCH` — bumped in Xcode under `MARKETING_VERSION`.

---

## [Unreleased]

### Added
- **Elegí de qué animes querés frases.** Nueva sección en Ajustes → Contenido → Animes: una lista con los 19 animes disponibles donde marcás los que te interesan. La elección se aplica al feed del inicio y a las frases que te llegan por notificación; si no elegís ninguno, seguís viendo todos.
- Tests del filtro por animes, de su persistencia y del onboarding (49 casos nuevos en `quoteAnimeTests`, 107 en total).
- Suite de tests (`quoteAnimeTests`, con Swift Testing): cubre el cálculo de racha actual y mejor racha, la racha global entre hábitos, el límite de 3 hábitos del plan gratuito y el marcado por día. Es el primer target de tests del proyecto.
- SwiftUI `#Preview` blocks added to all presentation views: `QuoteCard`, `QuoteDetailView`, `SplashView`, `WidgetTutorialView`, `OnboardingView`, `SettingsView`, `CatalogView`. Views with ViewModels use inline mock repositories.
- **Settings — Apóyanos section**: "Déjanos una reseña" abre directamente la App Store (`?action=write-review`), y "Compartir la app" via `ShareLink` con mensaje de invitación personalizado.
- **Settings — Síguenos section**: Instagram and Facebook links with deep-link-first strategy (opens native app if installed, browser otherwise). Custom SVG brand icons added to `Assets.xcassets` (`icon_instagram`, `icon_facebook`, `icon_tiktok`).
- **Settings — Información section**: "Política de privacidad" and "Términos y condiciones" items that open their respective pages in-app via `SFSafariViewController` (new `SafariView` component in `Presentation/Components/`).

### Fixed
- **La política de privacidad y los términos abren la página correcta.** Seguían apuntando al dominio viejo; ahora van a animequote.app, igual que en Android.
- **El onboarding ya no ofrece elegir un hábito donde no se puede guardar.** En iPhones con iOS 16 la última página dejaba elegir un primer hábito que después se perdía sin aviso; ahora esa página no aparece.
- **El widget ya se puede instalar.** La extensión del widget exigía una versión de iOS mucho más nueva que la app, así que en la práctica no aparecía en la galería de widgets de casi ningún iPhone. Ahora pide lo mismo que la app: iOS 16.6.
- **Mi Rutina ya no se ofrece donde no funciona.** En iPhones con iOS 16 el botón 🔥 del inicio llevaba a una pantalla que solo avisaba que la función no estaba disponible. Ahora el botón directamente no aparece en esas versiones.
- **Tutorial del widget**: el paso 2 decía "Toca el botón" sin mostrar el signo `+` que hay que tocar.
- Settings button in Home overlapping the status bar (safe area not respected).
- Back button in QuoteDetailView moved to `.overlay` so SwiftUI manages safe area automatically instead of manual `geo.safeAreaInsets.top` calculation.
- Widget always showing placeholder quote — Firebase REST query was missing required `orderBy=%22%24key%22` parameter when using `limitToFirst`, causing Firebase to return an error response that parsed as empty.
- Widget update frequency (set in Settings) now correctly controls the timeline refresh interval — `reloadAllTimelines()` is only called when the user changes the frequency, not on every app launch or quote swipe.

### Removed
- Se quitaron dos controles de ejemplo que habían quedado de la plantilla de Xcode y llegaban al usuario: un control "Start Timer" en el Centro de Control y una Live Activity de prueba, ninguno de los dos hacía nada.
- El botón "Quitar premium (solo pruebas)" ya no se incluye en las versiones publicadas; queda únicamente en compilaciones de desarrollo.

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
