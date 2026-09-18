# Paridad Android ↔ iOS

Libro mayor de paridad entre `gonzalo-droid/quoteAnime` (Android, fuente de verdad del
comportamiento) y `gonzalo-droid/quoteAnimeIOS` (este repo).

Una fila por función portada, con el commit de Android del que salió, más una fila por cada
divergencia que se decidió a propósito. Este archivo es el único registro que sobrevive fuera de
la sesión que hizo el trabajo: una nota que sólo existe en la memoria de un agente es invisible
para un clon nuevo, para otra máquina y para quien revise la rama.

**Se actualiza en el mismo pase que el código, nunca después.**

No existe tag `ios-synced` en el repo de Android. El alcance de cada tanda sale de este archivo.

**Regla del tag**: sólo puede apuntar al commit de Android más nuevo tal que él y todos los anteriores
estén portados, sean Android-only o sean una divergencia deliberada de la tabla de abajo. Una fila
"pendiente" lo bloquea. Tras la tanda 9 el primer bloqueo era `fcfcd28` (banners de AdMob,
2026-04-02). La tanda 10 portó o decidió las cinco filas que la tanda 9 dejó abiertas (buscador,
analytics, portadas, banners, TikTok); dónde está el tag ahora lo dice "Estado del tag" al final.

---

## Portado

Las tandas 1–6 se portaron antes de que existiera este archivo: sus filas están **reconstruidas**
desde el `CHANGELOG.md`, los comentarios `///` y el historial de ambos repos. Donde no se pudo
emparejar un commit de Android con confianza real, la columna dice `sin determinar` en vez de
inventar un SHA.

| Función | SHA Android | Estado | Notas |
|---|---|---|---|
| Núcleo de Mi Rutina (modelo, casos de uso, SwiftData, UI) | sin determinar | portado | ~15 commits de base en Android; no hay uno equivalente. |
| Validación de hábitos y orden de guardas al marcar un día | `d817f28` | portado | Las guardas viven en los casos de uso, igual que en Android. |
| Archivar y restaurar hábitos | `5583b91` | portado | |
| Archivar, restaurar y borrar desde el detalle, con confirmación | `3fa6d61` | portado | |
| Recordatorios por hábito con acción "Hecho" | `5e3afcb` | portado | |
| Aviso cuando el recordatorio no se puede activar | `e60ef6f`, `ef7cc81` | portado | `e60ef6f` sólo pide el permiso; el aviso con botón a Ajustes llegó en `ef7cc81` (corregido en la tanda 9: antes se citaba sólo el primero). |
| Pantalla de detalle del hábito (heatmap + calendario mensual) | `6a8d177` | portado | El heatmap de iOS es de sólo lectura — ver divergencias. |
| Etiquetas de día de la semana según locale | `6251574` | portado | |
| Fecha de fin y estado archivado en el modelo de hábito | sin determinar | portado | |
| Íconos temáticos de las plantillas | `e09b43d` | portado | |
| Color de la plantilla Black Clover | sin determinar | portado | El índice sale de `HabitPalette`. |
| Elegir el primer hábito en el onboarding | sin determinar | portado | |
| Elegir de qué animes quieres frases (Ajustes) | sin determinar | portado | Los ids **no** se sincronizan — ver divergencias. |
| El widget de frases respeta los animes elegidos | sin determinar | portado | |
| Widget resumen de Mi Rutina | sin determinar | portado | |
| Widget de un solo hábito, con su selector de configuración | `132e96b` | portado | `AppIntentConfiguration` en vez de una Activity; requiere iOS 17. |
| Snapshot de hábitos y refresco instantáneo de los widgets | sin determinar | portado | Equivale a `RoutineWidgetScheduler.triggerImmediateUpdate()`. |
| Localización inglés/español, tuteo y respaldo en inglés | `ad4a871` | portado | |
| URLs de privacidad y términos → animequote.app | `0b76ed0` | portado | Citado en `AppLinks.swift`. |
| Etiquetas de VoiceOver: selector de íconos, colores y mapa de actividad | `4f8e6d2` | portado | Tanda 9. Los 126 íconos con los textos `icon_*` de Android (`HabitIcons.label(for:)`), el elegido con `.isSelected`, las 13 categorías como encabezados, "Color N" con su estado, "Elegir ícono" con el ícono actual como valor. El heatmap se anuncia distinto — ver divergencias. El "Más opciones" de la tarjeta ya existía como "Acciones de <hábito>". |
| Premium con StoreKit 2 — entitlement, paywall con planes reales, restaurar, gestionar/cancelar | `7822372`, `72048cb`, `7d4d5f8`, `fc16551`, `0529500` | portado, **apagado** | Tanda 7. Se portó el *comportamiento* del billing, no su implementación: ver divergencias. Desde la tanda 8 está dormido detrás de `PremiumConfig.usesRealBilling = false` — ver "Premium en mock". Revisión commit por commit (tanda 9): `0529500` cubierto (`PremiumErrorReason` → `PaywallMessage` `.network` / `.storeUnavailable`, el texto de la tienda nunca llega a la pantalla, fijado en `PaywallViewModelTests`); `fc16551` **en parte**: su ventana de throttle no aplica (iOS no tiene throttle y `currentEntitlements` es local), pero faltan la serialización y el reporte de fallos — ver Pendiente. |
| Buscador del selector de íconos | `1d9e231` | portado | Tanda 10. `.searchable` sobre `HabitIconPickerView`; la regla vive en `HabitIconSearch` (pura). Misma semántica que Android: busca en el **nombre del ícono en el idioma del usuario** (`HabitIcons.label(for:)`), subcadena, sin mirar la clave ni el título de la categoría; las categorías conservan su encabezado con sólo los íconos que coinciden y desaparecen si quedan vacías; en blanco muestra todo. Estado vacío con `ContentUnavailableView` (iOS 17) y su equivalente a mano en 16. Ignora tildes y espacios — ver divergencias. |
| Eventos de Mi Rutina en Firebase Analytics | `9b82ee4`, `620c255`, `ed42446`, `26b7dcb` | portado | Tanda 10. Los siete eventos con **los mismos nombres, claves y valores** que `RoutineAnalytics.kt` (`routine_tab_opened`, `habit_detail_opened`, `habit_created`, `habit_completed`, `habit_archived`, `streak_milestone`, `streak_broken`), detrás del protocolo `RoutineAnalytics` que inyecta `AppDependencies` (`FirebaseRoutineAnalytics`). Umbrales `{7, 21, 50, 100}`, hito sólo al **subir** sobre uno (`620c255`), racha rota sólo de >0 a 0; como en Android, las rachas sólo se miden desde la lista. `habit_completed` sólo al marcar, nunca al desmarcar; `is_retroactive` = día ≠ hoy; `source` `app`/`notification`. `days_active` = períodos de 24 h truncados. Verificado en el simulador con `-FIRDebugEnabled`. El "Hecho" de la notificación pasa a ser idempotente (`26b7dcb`): antes desmarcaba un día ya marcado. El editor guarda ahora el `templateId` de la sugerencia. |
| Portadas de las plantillas temáticas | `923e552`, `3153211`, `64f9b8b` | portado | Tanda 10. Las cinco portadas de `res/drawable` (1080×1350) en `Assets.xcassets` como JPEG al 80 % (4,2 MB → 0,8 MB, sin diferencia visible a 3x). `HabitThemeImages` resuelve `themeKey` → asset y descripción temática; `ThemedSuggestionPreview` (108 pt, degradado, insignia) en el editor y en la 4ª página del onboarding; la tarjeta de Mi Rutina lleva la portada de fondo bajo un velo del 82 %. `Habit.coverAnimeSlug` guarda el `themeKey`. Elegir una sugerencia la aplica entera (título, descripción, ícono, color, portada) y un hábito nuevo arranca desde la primera que el usuario puede usar (`64f9b8b`); el chip elegido se marca. |
| Banner de AdMob | `fcfcd28`, `438e1b4`, `727f872` | portado (estado actual) | Tanda 10. Se replicó lo que Android muestra **hoy**, no su historia: un banner 320×50 (`AdSize.BANNER`) bajo las acciones de la frase abierta desde Explorar, oculto con premium; Home sin banner (en Android está comentado). `BannerAdPolicy` decide dónde y para quién. En DEBUG, banner **e intersticial** piden las unidades de prueba de Google (el intersticial pedía la real); release, las reales — ver Pendiente sobre la del banner. `SKAdNetworkItems` con `cstr6suwn9.skadnetwork` en `Info.plist`. Sin ATT, como el intersticial. |

---

## Divergencias deliberadas

Las filas de billing (verificación, acknowledge, restaurar, re-sincronización, planes, texto del
período, estado vacío, botón de QA) describen el código de StoreKit, que hoy está **apagado**:
vuelven a regir el día que `PremiumConfig.usesRealBilling` pase a `true`.

| Tema | Android | iOS | Por qué |
|---|---|---|---|
| **Premium en mock hasta la versión productiva** | Google Play Billing real (`billing-ktx`): el paywall vende `premium_subscription` | `PremiumConfig.usesRealBilling = false`. StoreKit sigue en el código pero no se construye: ni productos, ni `Transaction.updates`, ni re-sincronización. En la App Store el paywall muestra los beneficios con "Próximamente" deshabilitado, sin restaurar ni gestionar, y los límites gratuitos se aplican. En DEBUG y TestFlight hay un "Activar premium (solo pruebas)" que da premium local (`MockPremiumEntitlementSource`, clave `pref_is_premium`) | Decisión del usuario (tanda 8): el producto todavía no existe en App Store Connect ni están firmados los contratos de Paid Apps; en release el paywall habría mostrado "planes no disponibles". Pasar a producción es cambiar esa línea; qué hay que tener listo está en su `///`. Fijado por el test `DIVERGENCIA: premium es un mock hasta la versión productiva`. |
| **Cómo se detecta TestFlight** | No aplica | `AppTransaction.shared` verificado con `environment == .sandbox`, **preguntado sólo si `appStoreReceiptURL` ya termina en `sandboxReceipt`**. Un build de release se trata como App Store hasta demostrar lo contrario | Sin transacción local, `AppTransaction.shared` pide una a la tienda con autenticación interactiva: en un build Release del simulador la app arrancó con "Sign in to Apple Account". Un cliente con el recibo perdido (dispositivo restaurado de un backup) estaría en el mismo caso. El nombre del archivo del recibo no toca la red. **Punto ciego**: App Review también corre contra sandbox, así que un revisor vería el botón "(solo pruebas)". Ver "Antes de enviar a revisión". |
| **Verificación de la compra** | Confía en cualquier compra que Play reporte como `PURCHASED`; su propio comentario admite que no hay backend que verifique nada | Una transacción `.unverified` **nunca** da premium (`PremiumEntitlementDecision`) | StoreKit 2 verifica la firma criptográficamente. Reproducir la debilidad de Android sería portar el bug. |
| **Acknowledge y worker de reintento** | `acknowledgePurchase` con 3 intentos en línea + `AcknowledgePurchasesWorker` (hasta 15 reintentos). Play revoca y reembolsa la compra si no se confirma en 72 h | No existe | Es una exigencia de Play. El equivalente iOS es `Transaction.finish()`: local, sin red, sin plazo y sin nada que reintentar. |
| **Restaurar compras** | No existe ninguna acción de usuario; sólo una re-sincronización automática y silenciosa | Botón "Restaurar compras" en el paywall | App Store Review lo exige para suscripciones; Play no. |
| **Re-sincronización al volver a primer plano** | El KDoc de `BillingRepository.restorePurchases()` la pide, pero el único llamador es `QuoteAnimeApplication.onCreate()` | Se hace al arrancar **y** en cada `scenePhase == .active` | Se portó la intención, no el defecto. Ver "Deuda de Android". |
| **Planes del paywall** | Un producto con varios *base plans* de Play, cada uno una `SubscriptionOffer` | Un `Product` por plan: hoy sólo `premium_subscription` (mensual). El paywall ya lista N y oculta el selector cuando hay uno solo | Modelos de catálogo distintos. Un plan anual en iOS significa un **product id nuevo**, no una variante del mismo. |
| **Texto del período** | Muestra el ISO-8601 crudo de Play (`"P1M"`) | "cada mes" / "cada 3 meses", con variaciones de plural en los dos idiomas | El string de Android es un descuido, no una decisión de producto. |
| **Estado vacío del paywall** | Frase estática, sin salida | Misma frase + botón "Reintentar" | La causa más probable (el dispositivo estaba sin red al abrir) la puede arreglar el usuario. |
| **Botón de QA "Quitar premium"** | Escribe `is_premium = false`; la siguiente sincronización con Play lo vuelve a poner en `true` sin avisar | `DebugPremiumOverrideSource` fija un override explícito que sólo se limpia al comprar de verdad, y **sólo existe en builds DEBUG** | El de Android miente durante el QA. |
| **Anuncios** | Dos gates independientes: un flag `@Volatile` dentro de `ShareInterstitialManager` y un `if (!uiState.isPremium)` suelto en `CatalogScreen` | `ShareAdPolicy` (intersticial) y `BannerAdPolicy` (banner, con la lista de lugares), ambos puros y los únicos que preguntan por premium | Un `if` suelto en la vista es cómo una superficie nueva se olvida de preguntar. Tanda 10: el banner ya existe también en iOS. |
| **Banner que no carga** | `AdView` sin listener: si no hay anuncio queda el hueco en blanco | `BannerAdView` reserva los 50 pt mientras carga y se colapsa si la carga falla | Un recuadro vacío al pie de la pantalla se lee como un error de maquetación. |
| **Plantillas en el onboarding** | Elige la primera con `!isPremiumOnly \|\| isPremium` | `OnboardingViewModel` filtra siempre las premium, sin mirar el entitlement | Pendiente, no decidido: hoy un usuario premium que reinstala no ve Pokémon ni Black Clover en el onboarding. Impacto mínimo; anotado para no perderlo. |
| **`selectedCategoryIds`** | Ids de Firestore (`amor`, `motivación`) | Nombres de anime | Espacios de ids distintos. Sincronizar el valor corrompe en silencio la selección del usuario. |
| **Nombre visible de la app** | `Frases Anime` / `Anime Quotes` | `QuoteAnime` | Decisión de marca. Renombrar le cambia el nombre instalado a los usuarios actuales. |
| **Registro del español** | `values-es/strings.xml` usa voseo ("Desbloqueá", "sos", "Probá", "Cancelá") | Tuteo en todas las pantallas | Convención del repo iOS. Cada string portado se convierte. |
| **Notificaciones de frases** | El worker elige la frase en cada disparo | Se pre-programan todas por adelantado (`RescheduleQuoteNotificationsUseCase`) | iOS no ejecuta código propio en el momento del disparo. |
| **Heatmap (detalle y tarjeta)** | Tocar una celda marca o desmarca el día, en el detalle **y en la tarjeta de Mi Rutina** (`HabitCard.kt`, `onDayClick = onToggleDay`) | Sólo lectura en las dos superficies | A 10–12 pt cada celda es un cuarto de un target de toque fiable. El calendario mensual del detalle cubre el marcado retroactivo; en la tarjeta, el botón "Marcar hoy". (Tanda 9: la fila decía sólo "del detalle"; la divergencia siempre fue en las dos.) |
| **Heatmap con VoiceOver** | Cada día visible es un nodo de TalkBack ("12 mar 2026, completed"), accionable, más un resumen "Habit completion calendar" | Un solo elemento: "Mapa de actividad de las últimas 26 semanas", con valor "N días completados" (los que el mapa pinta). El anuncio día por día, accionable, vive en el calendario mensual (`"<fecha>, completado / sin completar / no se puede marcar"`). El heatmap compacto de la tarjeta no se anuncia: la tarjeta es un botón que ya lee título, racha y mejor racha | Consecuencia de la fila anterior: si el heatmap no es donde se marcan los días, 182 nodos que no hacen nada son sólo ruido para quien navega deslizando. |
| **Nombre en inglés del ícono `auto_awesome`** | "Treat yourself" — el mismo que `icecream` | "Pamper yourself" | **Confirmada por el usuario (tanda 10).** Dos íconos con el mismo nombre son dos botones indistinguibles para VoiceOver — y ahora también dos resultados iguales en el buscador. El español ya los distingue ("Darte un gusto" / "Darte un capricho"). Fijado por `dos íconos nunca se anuncian igual`. Queda como deuda de Android. |
| **TikTok en Ajustes → Síguenos** | Visible desde `38fd472`, con `@frasesanime` | Comentado en `SettingsView.swift`, junto con Instagram y Facebook (las tres cuentas ocultas), y apunta a `@quoteanimeapp` | Decisión del usuario (tanda 10): se queda como está. Si algún día se reactiva, hay que decidir antes cuál de los dos usuarios es el correcto — hoy cada plataforma apunta a una cuenta distinta. |
| **Buscador de íconos: tildes y espacios** | `contains(query, ignoreCase = true)`: distingue tildes y no recorta — "musica" no encuentra "Tocar música" | Ignora mayúsculas **y tildes** (`.diacriticInsensitive`) y recorta los espacios alrededor | Lo pidió el usuario; en un teclado de móvil la tilde se omite casi siempre y el autocorrector deja un espacio al final. Fijado por `HabitIconSearchTests`. |
| **Hábito creado en el onboarding** | Se guarda sin descripción, sin portada (`coverAnimeSlug` nulo) y con el color 0 | Guarda la descripción temática, la portada y el color del tema, igual que si se eligiera la misma sugerencia en el editor | La página muestra la portada y la frase del tema al elegir; guardar el hábito sin ellas lo hace distinto del que sale del editor con la misma sugerencia. Reversible si se prefiere la paridad estricta. Ver deuda de Android. |
| **Hitos de racha desde el detalle** | `streak_milestone` / `streak_broken` sólo se miden al marcar desde la lista; marcar el 7º día desde el calendario del detalle o desde la notificación no dispara nada | Igual que Android, a propósito | Las dos apps alimentan los mismos eventos: medir distinto en iOS haría incomparables los datos. Fijado por el test `DIVERGENCIA: completar el 7º día desde el calendario…`; si Android lo corrige, se corrige aquí a la vez. Ver deuda de Android. |
| **Estado seleccionado en los selectores** | TalkBack no dice cuál ícono ni cuál color está elegido (sólo el borde lo muestra) | `.isSelected` en íconos, colores y días del recordatorio | Lo pidió el usuario en la tanda 9; en Android es deuda. |
| **Widgets tras la acción "Hecho" de la notificación** | No refresca | Refresca (`HabitReminderNotificationDelegate`) | Gap de Android, ya anotado en el propio archivo. |
| **Comparación de días** | `LocalDate`, sin hora | `Date` + guarda para que una marca de "hoy" no se rechace al cambiar la hora | Caso que Android nunca enfrenta. |

---

## Valores que nunca cruzan de plataforma

- `pref_is_premium` (iOS) — desde la tanda 8, con el interruptor en `false`, es **el flag del
  premium de prueba**: sólo cuenta en DEBUG y TestFlight; en una instalación de la App Store se
  ignora aunque valga `true` (el mock pre-billing de antes de la tanda 7 se lo dejó en `true` a
  cualquiera que tocó "Suscribirme"). Con el interruptor en `true` vuelve a ser el override de QA
  de DEBUG. El entitlement real se cachea en `pref_premium_entitlement_cache`, que nunca se
  reutilizó por el mismo motivo.
- El orden de `HabitPalette.colors` y las claves de `HabitIcons` — se persisten por índice y por
  clave.
- Bundle id, App Group (`group.com.gonzadev.quoteAnime`), product ids, firma y keystore.

---

## Deuda de Android encontrada

Se reporta, no se arregla: el repo de Android es de sólo lectura para el agente de paridad.

| Dónde | Qué |
|---|---|
| `BillingRepository.restorePurchases()` | El KDoc pide re-sincronizar "on every return to the foreground" y no hay ningún `onResume`/`ProcessLifecycleOwner` que lo haga. Una suscripción cancelada en Play mientras el proceso sigue vivo no se nota hasta el siguiente arranque en frío. |
| `BillingRepositoryImpl` | Verificación 100 % en el cliente, sin backend ni Play Developer API. El propio comentario de clase lo admite. Es falsificable. |
| `PaywallScreen.kt` | El botón de QA "Quitar premium" no toca el estado de Play: la siguiente `restorePurchases()` revierte el flag. Durante el QA el botón miente. |
| `syncPurchases()` | Sólo consulta `ProductType.SUBS`, pero `BillingClientFactory` habilita productos de una sola compra (`enableOneTimeProducts()`). Si algún día se vende uno, la restauración no lo va a ver. |
| `handlePurchasesUpdated` | La rama `OK` con lista de compras vacía emite un error genérico y no tiene ningún test; no hay evidencia de que Play pueda producirla. |
| `ITEM_ALREADY_OWNED` | Si la re-sincronización falla, el usuario ve "Algo salió mal con la compra" — justo el caso (ya suscrito en otro dispositivo) que merecería su propio mensaje. |
| `values-es/strings.xml` | ~16 strings en voseo mezclados con el resto de la app. |
| `values/strings.xml` | `icon_icecream` e `icon_auto_awesome` dicen los dos "Treat yourself": en inglés, TalkBack anuncia igual dos íconos distintos del selector. |
| `HabitIconPicker.kt`, `HabitEditorSheet.kt` | Ni la celda del ícono ni el color elegido exponen el estado seleccionado (`selected`/`Role`): TalkBack no dice cuál está elegido. |
| `values-es/strings.xml` (`0529500`) | Los dos mensajes de error nuevos del paywall vienen en voseo ("Intentá", "Revisá"). iOS ya los tenía en tuteo. |
| `HabitIconPicker.kt` (`1d9e231`) | `matchesQuery` usa `contains(ignoreCase = true)` sin normalizar tildes: "musica" no encuentra "Tocar música". Tampoco recorta el texto. |
| `OnboardingViewModel.onCreateHabit` | Crea el hábito con `colorIndex = 0` y sin `coverAnimeSlug` ni descripción, mientras el editor, con la misma sugerencia, guarda el color del tema, la portada y la descripción. |
| `RoutineViewModel.trackStreakChange` | Es el único lugar que mide rachas: completar un hito desde el calendario del detalle (`HabitDetailViewModel.onDayClick`) o desde el "Hecho" de la notificación nunca dispara `streak_milestone`. |
| `RoutineAnalytics.kt` | Los booleanos van con `Bundle.putBoolean`, un tipo que Firebase no documenta como admitido (String, long, double). En iOS llegan como 0/1 (visto en el log de depuración). **No verificado** qué recibe Firebase desde Android: conviene mirarlo en DebugView antes de armar un informe que cruce las dos plataformas. |
| `app/build.gradle.kts` / iOS `AdConstants` | El id del banner de release de Android (`…/4873365993`) es exactamente el que tenía iOS en `AdConstants`. Uno de los dos lados copió el del otro; como una unidad pertenece a una sola app de AdMob, en la otra plataforma no puede servir. |

---

## Antes de enviar a revisión con el premium en mock

- **App Review corre contra sandbox**, igual que TestFlight: `AppTransaction.environment` le dice
  `.sandbox`, así que el revisor vería "Activar premium (solo pruebas)" y podría activarlo. Pendiente
  de decisión: aceptarlo (y avisarlo en las notas de revisión), o subir a TestFlight un binario
  distinto del de la App Store (una configuración de build con su propio flag de compilación — es
  un cambio de `project.pbxproj`).
- **Ficha de privacidad (App Privacy) en App Store Connect** — la tiene que actualizar el usuario;
  el código no la toca. La app **no pide ATT** (no hay `NSUserTrackingUsageDescription`), así que
  Google Mobile Ads nunca lee el IDFA; aun así el SDK recoge datos que la ficha debe declarar, y eso
  ya valía para el intersticial antes de esta tanda: identificador del dispositivo (IDFV),
  ubicación aproximada (por IP), datos de interacción con los anuncios, y diagnóstico. El banner no
  añade categorías nuevas. Los eventos de Mi Rutina sí suman **"Interacción con el producto" →
  Analítica** de Firebase (el id de hábito es un UUID local, sin datos personales). Si algún día se
  activa ATT o anuncios personalizados, hay que marcar "usado para rastrearte" y añadir
  `NSUserTrackingUsageDescription`. Contrastar con la guía de divulgación de datos de Google Mobile
  Ads y de Firebase antes de enviar.
- **Un paywall "Próximamente"** puede chocar con la guía 2.1 (funciones incompletas). Alternativa si
  lo rechazan: ocultar las entradas al paywall en builds de la App Store y dejar sólo el aviso
  del límite.

## Pendiente

| Función | Estado | Notas |
|---|---|---|
| Activar la compra real (`PremiumConfig.usesRealBilling = true`) | pendiente, bloqueado fuera del código | Requiere el producto `premium_subscription` en App Store Connect, el contrato de Paid Apps activo y una prueba en sandbox en un dispositivo real. La lista completa está en el `///` de `PremiumConfig`. |
| Unidad de banner de iOS en AdMob | **a decidir / acción del usuario** (tanda 10) | `AdConstants.bannerID` de release es el id del banner de **Android** (`ca-app-pub-1427341798923689/4873365993`); la app de iOS en AdMob es `~5172948580`. Crear una unidad de banner en la app de iOS y reemplazar el valor. Mientras tanto, en release el banner probablemente no cargue y se colapse (no queda hueco). El intersticial (`…/7805407829`) sí es distinto del de Android. |
| Ficha de privacidad de la App Store | **acción del usuario** (tanda 10) | Ver "Antes de enviar a revisión". |
| Serializar la re-sincronización del entitlement (`fc16551`) | pendiente, **antes** de activar la compra real | `StoreKitEntitlementSource.refresh()` no está serializado: se llama desde el `.task` de arranque, cada `scenePhase == .active`, el listener de `Transaction.updates`, después de comprar y al restaurar. Una lectura que empezó antes de que la compra quedara registrada puede aplicar su `false` después del `true` de otra — el defecto exacto que arregla `fc16551`. Hoy el código está dormido; encontrado por lectura, no reproducido. |
| Registrar los fallos de compra como non-fatal (`fc16551`) | pendiente, **antes** de activar la compra real | Android los manda a Crashlytics con etapa y código. En iOS `FirebaseCrashlytics` está enlazado al target pero nadie lo importa: los fallos de `loadOffers`, `purchase`, `restore` y las transacciones sin verificar sólo hacen `print`. El reporte del acknowledge agotado es Android-only (`finish()` es local). |
| Plan anual | pendiente, después de activar la compra real | Necesita un product id nuevo en App Store Connect; el paywall ya soporta varios planes. |
| Dynamic Type | pendiente (todo el repo) | Las 106 llamadas a `.font(.system(size:))` son tamaños fijos; no hay ni una fuente semántica. No es de ninguna tanda de paridad, pero nadie lo tenía anotado. |
| Plantillas de hábito remotas | pendiente — **primer bloqueo del tag** | `492f80f`. `GetHabitTemplatesUseCase` es sólo local; Android las puede sobrescribir desde Firestore. |
| Tocar el recordatorio de un hábito abre Mi Rutina | pendiente (encontrado en la tanda 10) | `e4fbf2f`, `4b691bf`. En Android tocar el cuerpo de la notificación lleva a Mi Rutina (deep link con reutilización de la tarea). En iOS `HabitReminderNotificationDelegate` sólo atiende la acción "Hecho" (`markDoneActionIdentifier`); `UNNotificationDefaultActionIdentifier` no se maneja, así que tocar la notificación abre la app donde estaba. Se resuelve en el delegate empujando `.routine` en `AppRouter`. |
| Tipografía de las frases | **a decidir** (encontrado en la tanda 10) | `8e366af`, `fe415ac`. Android empaqueta Fraunces, Lora y Playfair Display (`res/font/*.ttf`) y usa Fraunces para las frases; iOS usa las del sistema: Didot (`quoteSerif`) y Georgia (`quoteSerifItalic`), sin `.ttf` ni `UIAppFonts`. Cosmético. Recomendación: pasarla a divergencia deliberada (las serif del sistema se ven nativas y no suman peso); si se prefiere igualar, es añadir los `.ttf` y la clave `UIAppFonts` — un cambio de `Info.plist` que hay que pedir. |
| Heatmap interactivo | divergencia deliberada, no pendiente | Ver la tabla de divergencias. |

---

## Estado del tag (tanda 10)

Auditoría de los 125 commits de Android desde `fcfcd28` hasta `51c5dfd` (HEAD) contra este archivo
y el código Swift: ~80 portados, ~35 exclusivos de Android, el resto divergencias o pendientes.
El primer bloqueo en orden es **`492f80f`** (plantillas remotas); los siguientes son `e4fbf2f` /
`4b691bf` (tocar el recordatorio abre Mi Rutina), `8e366af` / `fe415ac` (tipografías, a decidir) y
`fc16551` (en parte, del StoreKit apagado). Por la regla de arriba, `ios-synced` hoy sólo podría ir a
**`5583b91`**, el commit anterior al primer bloqueo. **HEAD `51c5dfd` no califica.** El tag no se ha
creado.
