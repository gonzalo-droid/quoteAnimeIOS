# Changelog

All notable changes to QuoteAnime are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versions follow `MAJOR.MINOR.PATCH` — bumped in Xcode under `MARKETING_VERSION`.

---

## [Unreleased]

### Added
- **El texto sigue el tamaño de letra de tu iPhone.** Si agrandas la letra en Ajustes → Pantalla y brillo → Tamaño del texto (o en Accesibilidad), la app la agranda también: Inicio, Mi Rutina, el detalle y el editor de hábitos, el paywall, la bienvenida y los widgets de Mi Rutina. Con el tamaño normal todo se ve exactamente igual que antes. En los tamaños más grandes las rachas del detalle se apilan, los nombres largos de hábitos pasan a dos líneas y la página de elegir hábito de la bienvenida se puede desplazar; la frase a pantalla completa, el mapa de actividad y las barras superiores crecen hasta un límite para no romperse, y los widgets de frases mantienen su tamaño.
- Tests del escalado de la tipografía (5 casos nuevos, 437 en total).
- **Las frases por notificación ya no se acaban si no abres la app.** La app pide a iOS repasar las notificaciones en segundo plano más o menos una vez al día y vuelve a llenar la tanda con tus animes y horarios, sin tocar los recordatorios de hábitos. iOS decide cuándo lo hace, así que la última notificación de cada tanda es un aviso para abrir la app: solo llega si nada la repuso a tiempo.
- Tests de la reposición en segundo plano y del aviso final (11 casos nuevos, 432 en total).
- Tests del recordatorio sin días en el editor y en los casos de uso (8 casos nuevos, 421 en total).
- **Tocar el widget de frases abre esa frase.** La app se abre en Inicio justo en la frase que mostraba el widget, como en Android, esté cerrada o abierta en otra pantalla. Si la frase ya no está o no es de los animes que elegiste, se abre Inicio como siempre.
- Tests de los horarios de las notificaciones (las tablas de horarios de Android, ventanas que cruzan la medianoche, el día entero y el tope de 64 en varios días) y del widget de frases (30 casos nuevos, 413 en total).
- **Tocar un recordatorio abre Mi Rutina.** Al tocar la notificación de un hábito la app se abre directo en Mi Rutina, como en Android, esté cerrada o en segundo plano. Si todavía no terminaste la bienvenida, primero la completas y después llegas a Mi Rutina. "Hecho" sigue marcando el día sin abrir la app.
- **Los widgets de Mi Rutina abren Mi Rutina.** Tocar el widget de resumen o el de un hábito lleva a la lista de Mi Rutina, como en Android.
- **Sugerencias de hábito que se actualizan solas.** Las sugerencias del editor y de la bienvenida pueden llegar desde el servidor sin publicar una versión nueva; mientras tanto, o sin conexión, ves las de siempre al instante.
- Tests del deep link a Mi Rutina y de las sugerencias remotas (44 casos nuevos, 383 en total).
- **Busca íconos por su nombre.** El selector de íconos de los hábitos tiene un buscador: escribe "agua", "leer" o "música" (con o sin tilde) y ves solo los íconos que coinciden, agrupados por categoría, en el idioma de tu iPhone, como en Android. Si nada coincide te lo dice.
- **Las sugerencias temáticas traen su portada.** Camino ninja, Buscar el One Piece, Sé un saiyan, Sé un maestro Pokémon y Sé el Rey Mago muestran su ilustración y una frase del tema al elegirlas en el onboarding y en el editor, y el hábito creado la lleva de fondo en su tarjeta de Mi Rutina, como en Android.
- **Anuncio en el detalle de frase de Explorar.** Al abrir una frase desde Explorar aparece un banner debajo de los botones, como en Android; con premium no aparece. El inicio sigue sin banner.
- Mi Rutina envía a Firebase Analytics los mismos eventos que Android (abrir Mi Rutina y el detalle, crear, completar y archivar hábitos, rachas de 7, 21, 50 y 100 días y rachas perdidas), para ver las dos apps juntas.
- Tests del buscador de íconos, de los eventos de Mi Rutina, de las portadas y de la política del banner (56 casos nuevos, 339 en total).
- **El selector de íconos se puede usar con VoiceOver.** Cada uno de los 126 íconos se lee con su nombre ("Entrenar", "Beber agua", "Tender la cama"…), en español o en inglés según el iPhone, igual que en Android; el que tiene el hábito se anuncia como seleccionado y los títulos de categoría se leen como encabezados.
- Con VoiceOver, "Elegir ícono" dice qué ícono tiene el hábito, cada color dice si es el elegido y el mapa de actividad del detalle dice cuántos días completaste en esas semanas.
- Tests de las etiquetas de VoiceOver: los 126 íconos en los dos idiomas, los 14 colores y el conteo de días del mapa de actividad (15 casos nuevos, 283 en total).
- **Premium llega próximamente.** El paywall ya muestra lo que incluye premium (hábitos ilimitados, sin anuncios y los temas de Pokémon y Black Clover), con el botón "Próximamente" mientras preparamos las suscripciones. El plan gratuito sigue igual: 3 hábitos activos y las plantillas premium con candado.
- Premium de prueba solo en las versiones de desarrollo y TestFlight, para revisar las pantallas premium; la versión de la App Store no lo ofrece ni lo acepta.
- La compra con la App Store (planes, restaurar compras, gestionar o cancelar la suscripción) ya está hecha pero apagada hasta la versión productiva: la app no se conecta a la tienda mientras tanto.
- Tests del premium apagado: "Próximamente" en la App Store, premium de prueba en desarrollo y TestFlight, y que la tienda no se toca (17 casos nuevos, 268 en total).
- Tests del entitlement (suscripción activa, vencida, en período de gracia, reembolsada y sin verificar), de los tres límites del plan gratuito y del paywall (43 casos nuevos, 251 en total).
- **Widget de un solo hábito.** Un widget nuevo que sigue el hábito que elijas: muestra su nombre, su racha y el mapa de actividad de las últimas 9 semanas con su color. Puedes poner varios, uno por hábito. Para elegirlo, mantén pulsado el widget y toca "Editar widget". Necesita iOS 17; los demás widgets siguen funcionando desde iOS 16.6.
- Tests del snapshot que alimenta los widgets, del selector de hábito y de la selección de animes compartida con la extensión (40 casos nuevos, 208 en total).
- **Aviso cuando el recordatorio no se puede activar.** Si las notificaciones están desactivadas, el editor de hábitos te lo explica y te ofrece un botón para ir a Ajustes, como en Android.
- Tests de los íconos de las plantillas, del aviso de permiso y del idioma de respaldo (40 casos nuevos, 307 en total).
- **La app ahora está en inglés y en español.** Usa el idioma del iPhone, como en Android; también puedes elegirlo solo para QuoteAnime en Ajustes del sistema → Apps → QuoteAnime → Idioma. Las frases y los nombres de los animes se muestran tal cual vienen.
- Los textos con números usan singular y plural según corresponda: "1 día seguido", "1 vez al día", "1 anime" (y "1 day streak" en inglés).
- Los botones que solo tienen ícono (favorito, compartir, explorar, volver, añadir hábito, marcar hoy, colores del hábito) ahora se leen con VoiceOver.
- Tests de plurales en los dos idiomas, un test que verifica que cada texto tenga su traducción al español y al inglés, y tests de la racha de cada hábito con el día de hoy fijo (40 casos nuevos, 267 en total).
- **Pantalla de detalle de cada hábito.** Toca una tarjeta de Mi Rutina y se abre su detalle: el mapa de actividad de los últimos 6 meses, la racha actual, la mejor racha y los días marcados, más un calendario mensual que puedes navegar mes a mes.
- **Marcar días pasados.** Desde el calendario del detalle puedes marcar o desmarcar cualquier día que te hayas olvidado, y la racha se recalcula sola. Los días futuros y los que quedan fuera del período del hábito se ven atenuados y no se pueden tocar.
- **Archivar, restaurar y borrar desde el detalle**, en el menú de la barra superior. Borrar pide confirmación y avisa que se pierde todo el historial.
- **Fecha de fin opcional en los hábitos.** Al crear o editar un hábito puedes ponerle una fecha de fin; después de esa fecha deja de aceptar marcas. No se puede elegir una fecha de fin anterior a la de inicio.
- Tests del detalle del hábito, del calendario mensual y de la fecha de fin (121 casos nuevos en `quoteAnimeTests`, 228 en total).
- **Elige de qué animes quieres frases.** Nueva sección en Ajustes → Contenido → Animes: una lista con los 19 animes disponibles donde marcas los que te interesan. La elección se aplica al feed del inicio y a las frases que te llegan por notificación; si no eliges ninguno, sigues viendo todos.
- Tests del filtro por animes, de su persistencia y del onboarding (49 casos nuevos en `quoteAnimeTests`, 107 en total).
- Suite de tests (`quoteAnimeTests`, con Swift Testing): cubre el cálculo de racha actual y mejor racha, la racha global entre hábitos, el límite de 3 hábitos del plan gratuito y el marcado por día. Es el primer target de tests del proyecto.
- SwiftUI `#Preview` blocks added to all presentation views: `QuoteCard`, `QuoteDetailView`, `SplashView`, `WidgetTutorialView`, `OnboardingView`, `SettingsView`, `CatalogView`. Views with ViewModels use inline mock repositories.
- **Settings — Apóyanos section**: "Déjanos una reseña" abre directamente la App Store (`?action=write-review`), y "Compartir la app" via `ShareLink` con mensaje de invitación personalizado.
- **Settings — Síguenos section**: Instagram and Facebook links with deep-link-first strategy (opens native app if installed, browser otherwise). Custom SVG brand icons added to `Assets.xcassets` (`icon_instagram`, `icon_facebook`, `icon_tiktok`).
- **Settings — Información section**: "Política de privacidad" and "Términos y condiciones" items that open their respective pages in-app via `SFSafariViewController` (new `SafariView` component in `Presentation/Components/`).

### Changed
- **Las notificaciones de frases se reparten de punta a punta de tu horario**, como en Android: 3 al día entre las 8:00 y las 22:00 llegan a las 8:00, 15:00 y 22:00 (antes 8:00, 12:40 y 17:20). Ahora también puedes elegir un horario que cruce la medianoche (22:00 a 2:00) o el día entero (misma hora de inicio y fin); antes no llegaba ninguna. Las que ya tenías programadas se reacomodan solas la próxima vez que abras la app.
- **Un hábito nuevo empieza desde una sugerencia.** El editor abre con la primera sugerencia que puedes usar ya aplicada (nombre, descripción, ícono, color y portada), y elegir otra la reemplaza entera; puedes cambiar todo antes de guardar. La sugerencia elegida se marca en la fila.
- **Perder premium ya no te quita nada de lo que creaste.** Si la suscripción caduca, los hábitos que pasan del límite gratuito se quedan donde están y solo deja de poderse crear uno nuevo, igual que en Android.
- **El widget de frases respeta los animes que elegiste**, igual que en Android. Si ya los habías elegido, se conservan solos. El widget también deja de mostrar siempre frases del mismo bloque: ahora sale de todo el catálogo.
- **Los widgets se actualizan apenas cambias algo.** Marcar un día, crear, editar, archivar, restaurar o borrar un hábito refresca la pantalla de inicio al instante, sin esperar. También al marcar desde la notificación.
- El widget "Mi Rutina" deja de listar los hábitos archivados.
- **Si tu iPhone está en un idioma que la app no tiene (portugués, francés, alemán…), la app se muestra en inglés**, igual que en Android. Antes se mostraba en español. Español e inglés siguen igual.
- **Todos los textos en español tratan de "tú".** Antes la app mezclaba "vos" y "tú" ("Creá", "Ya sos premium" junto a "Puedes"); ahora habla igual en todas las pantallas, como la app de Android.
- Las fechas, los meses y los días de la semana del calendario, del mapa de actividad y del recordatorio siguen el idioma y la región del iPhone (por ejemplo, "L M X J V S D" en España y "M T W T F S S" en inglés).
- En Ajustes, la frecuencia del widget ahora dice "Nueva frase 2 veces al día", el mismo texto que en Android.
- **Tocar una tarjeta de Mi Rutina ahora abre el detalle**, no el editor. Para editar, usa el menú de la tarjeta o el del detalle — igual que en Android.
- Removed decorative opening quote mark (`\u{201C}`) from `QuoteDetailView`, `OnboardingView`, widget Small/Medium/Inline views, and `ShareImageRenderer`.
- Typography: `quoteSerif` changed from `Georgia` to `Didot`; `quoteSerifItalic` changed from `Georgia-Italic` to `Georgia`.

### Fixed
- **Un recordatorio ya no queda encendido sin días.** Al activar el recordatorio de un hábito se eligen los siete días, y si quitas todos el editor te avisa de que así no va a sonar; si guardas igual, se guarda apagado en vez de parecer activo sin programar nada.
- **Los recordatorios de hábitos ya no desaparecen.** Con las notificaciones de frases activadas, cada vez que abrías la app se borraban los recordatorios de tus hábitos (y también al apagar las de frases); ahora conviven.
- Inicio cargaba las frases dos veces al abrir la app.
- **"Hecho" en el recordatorio de un hábito ya no desmarca el día.** Si ya lo habías marcado desde la app, tocar "Hecho" en la notificación lo dejaba sin marcar; ahora lo deja marcado, como en Android.
- **El widget de frases volvía a quedarse en gris.** Descargaba la ilustración del anime a tamaño completo y iOS se negaba a guardar el widget con una imagen tan grande, así que descartaba la frase que acababa de traer. Ahora la reduce antes de mostrarla.
- **Las sugerencias de hábito muestran su ícono.** Camino ninja, Buscar el One Piece, Sé un saiyan y las demás sugerencias mostraban un check genérico en el onboarding, el editor y la tarjeta; ahora tienen su ícono, el mismo que en Android. Los hábitos que ya habías creado desde una sugerencia también lo recuperan.
- **"1 días seguidos" ahora dice "1 día seguido".**
- La sugerencia "Sé el Rey Mago" usaba un color distinto al de Android; ahora los hábitos creados desde ella nacen del mismo color en las dos apps.
- **Las filas de beneficios del paywall quedan alineadas.** Cada fila se centraba según el largo de su texto y los íconos no coincidían.
- El recordatorio de un hábito se muestra en el idioma que tenga el iPhone cuando llega, aunque lo hayas creado con otro idioma.
- La descripción del mapa de actividad para VoiceOver decía "los últimos 26 semanas".
- **Ya no se pierden los hábitos ni los favoritos al cerrar la app.** Las dos bases de datos internas compartían el mismo archivo sin querer, así que cada una borraba lo que había guardado la otra: al abrir la app de nuevo, todo lo del día anterior había desaparecido. Ahora cada una tiene el suyo y el historial se conserva.
- **El mapa de actividad se dibuja completo.** Los días anteriores al comienzo del hábito quedaban en blanco y la grilla se veía cortada, sobre todo en el detalle.
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

---

## [1.0.6] — 2026-04

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
