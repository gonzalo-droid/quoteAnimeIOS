# Paridad Android ↔ iOS

Libro mayor de paridad entre `gonzalo-droid/quoteAnime` (Android, fuente de verdad del
comportamiento) y `gonzalo-droid/quoteAnimeIOS` (este repo).

Una fila por función portada, con el commit de Android del que salió, más una fila por cada
divergencia que se decidió a propósito. Este archivo es el único registro que sobrevive fuera de
la sesión que hizo el trabajo: una nota que sólo existe en la memoria de un agente es invisible
para un clon nuevo, para otra máquina y para quien revise la rama.

**Se actualiza en el mismo pase que el código, nunca después.**

No existe tag `ios-synced` en el repo de Android. El alcance de cada tanda sale de este archivo.

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
| Aviso cuando el recordatorio no se puede activar | `e60ef6f` | portado | |
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
| Premium con StoreKit 2 — entitlement, paywall con planes reales, restaurar, gestionar/cancelar | `7822372`, `72048cb`, `7d4d5f8`, `fc16551`, `0529500` | portado | Tanda 7. Se portó el *comportamiento* del billing, no su implementación: ver divergencias. |

---

## Divergencias deliberadas

| Tema | Android | iOS | Por qué |
|---|---|---|---|
| **Verificación de la compra** | Confía en cualquier compra que Play reporte como `PURCHASED`; su propio comentario admite que no hay backend que verifique nada | Una transacción `.unverified` **nunca** da premium (`PremiumEntitlementDecision`) | StoreKit 2 verifica la firma criptográficamente. Reproducir la debilidad de Android sería portar el bug. |
| **Acknowledge y worker de reintento** | `acknowledgePurchase` con 3 intentos en línea + `AcknowledgePurchasesWorker` (hasta 15 reintentos). Play revoca y reembolsa la compra si no se confirma en 72 h | No existe | Es una exigencia de Play. El equivalente iOS es `Transaction.finish()`: local, sin red, sin plazo y sin nada que reintentar. |
| **Restaurar compras** | No existe ninguna acción de usuario; sólo una re-sincronización automática y silenciosa | Botón "Restaurar compras" en el paywall | App Store Review lo exige para suscripciones; Play no. |
| **Re-sincronización al volver a primer plano** | El KDoc de `BillingRepository.restorePurchases()` la pide, pero el único llamador es `QuoteAnimeApplication.onCreate()` | Se hace al arrancar **y** en cada `scenePhase == .active` | Se portó la intención, no el defecto. Ver "Deuda de Android". |
| **Planes del paywall** | Un producto con varios *base plans* de Play, cada uno una `SubscriptionOffer` | Un `Product` por plan: hoy sólo `premium_subscription` (mensual). El paywall ya lista N y oculta el selector cuando hay uno solo | Modelos de catálogo distintos. Un plan anual en iOS significa un **product id nuevo**, no una variante del mismo. |
| **Texto del período** | Muestra el ISO-8601 crudo de Play (`"P1M"`) | "cada mes" / "cada 3 meses", con variaciones de plural en los dos idiomas | El string de Android es un descuido, no una decisión de producto. |
| **Estado vacío del paywall** | Frase estática, sin salida | Misma frase + botón "Reintentar" | La causa más probable (el dispositivo estaba sin red al abrir) la puede arreglar el usuario. |
| **Botón de QA "Quitar premium"** | Escribe `is_premium = false`; la siguiente sincronización con Play lo vuelve a poner en `true` sin avisar | `DebugPremiumOverrideSource` fija un override explícito que sólo se limpia al comprar de verdad, y **sólo existe en builds DEBUG** | El de Android miente durante el QA. |
| **Anuncios** | Dos gates independientes: un flag `@Volatile` dentro de `ShareInterstitialManager` y un `if (!uiState.isPremium)` suelto en `CatalogScreen` | Un único `ShareAdPolicy`. En iOS el banner está comentado desde antes; el único anuncio vivo es el intersticial de compartir | Dos gates para "sin anuncios" es cómo una superficie nueva se olvida de preguntar. |
| **Plantillas en el onboarding** | Elige la primera con `!isPremiumOnly \|\| isPremium` | `OnboardingViewModel` filtra siempre las premium, sin mirar el entitlement | Pendiente, no decidido: hoy un usuario premium que reinstala no ve Pokémon ni Black Clover en el onboarding. Impacto mínimo; anotado para no perderlo. |
| **`selectedCategoryIds`** | Ids de Firestore (`amor`, `motivación`) | Nombres de anime | Espacios de ids distintos. Sincronizar el valor corrompe en silencio la selección del usuario. |
| **Nombre visible de la app** | `Frases Anime` / `Anime Quotes` | `QuoteAnime` | Decisión de marca. Renombrar le cambia el nombre instalado a los usuarios actuales. |
| **Registro del español** | `values-es/strings.xml` usa voseo ("Desbloqueá", "sos", "Probá", "Cancelá") | Tuteo en todas las pantallas | Convención del repo iOS. Cada string portado se convierte. |
| **Notificaciones de frases** | El worker elige la frase en cada disparo | Se pre-programan todas por adelantado (`RescheduleQuoteNotificationsUseCase`) | iOS no ejecuta código propio en el momento del disparo. |
| **Heatmap del detalle** | Tocar una celda marca o desmarca el día | Sólo lectura | A 10 pt cada celda es un cuarto de un target de toque fiable. El calendario mensual cubre el marcado retroactivo. |
| **Widgets tras la acción "Hecho" de la notificación** | No refresca | Refresca (`HabitReminderNotificationDelegate`) | Gap de Android, ya anotado en el propio archivo. |
| **Comparación de días** | `LocalDate`, sin hora | `Date` + guarda para que una marca de "hoy" no se rechace al cambiar la hora | Caso que Android nunca enfrenta. |

---

## Valores que nunca cruzan de plataforma

- `pref_is_premium` (iOS) — desde la tanda 7 significa **"override de QA"** y sólo existe en DEBUG.
  El entitlement real se cachea en `pref_premium_entitlement_cache`. No se reutilizó la clave vieja
  porque el mock pre-billing le daba premium local a cualquiera que tocara "Suscribirme", y
  reutilizarla les habría regalado un caché de premium a todos ellos.
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

---

## Pendiente

| Función | Estado | Notas |
|---|---|---|
| Etiquetas de VoiceOver de los íconos | pendiente | Último punto de paridad conocido antes de poder mover un tag de sincronización. |
| Plan anual | pendiente | Necesita un product id nuevo en App Store Connect; el paywall ya soporta varios planes. |
| Dynamic Type | pendiente (todo el repo) | Las 106 llamadas a `.font(.system(size:))` son tamaños fijos; no hay ni una fuente semántica. No es de esta tanda, pero nadie lo tenía anotado. |
| Plantillas de hábito remotas | pendiente | `GetHabitTemplatesUseCase` es sólo local; Android las puede sobrescribir desde Firestore. |
| Imágenes de portada de las plantillas | pendiente | Android trae `naruto.png`, `onepiece.png`…; iOS no tiene los assets. |
| Heatmap interactivo | divergencia deliberada, no pendiente | Ver la tabla de divergencias. |
| Banners de AdMob en el feed y en el detalle | pendiente / a decidir | Android los tiene (`727f872`, `438e1b4`, `fcfcd28`); en iOS `BannerAdView` existe pero su única llamada está comentada en `HomeView`. El paywall promete "sin anuncios" y hoy en iOS eso sólo cubre el intersticial de compartir. |
| Eventos de Mi Rutina en Firebase Analytics | pendiente | Android los registra (`9b82ee4`); no hay instrumentación equivalente en iOS. |
