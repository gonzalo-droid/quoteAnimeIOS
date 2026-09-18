import Foundation
import Testing
import UserNotifications
@testable import quoteAnime

/// Android `e4fbf2f` / `4b691bf` (tapping a habit reminder opens Mi Rutina) and the routine
/// widgets' open intent (`132e96b`). One door for all of them — `AppRouter.open(_:)` — so these
/// tests pin both what each entry point resolves to and what the router does with it.
@MainActor
@Suite("Deep link a Mi Rutina")
struct AppDeepLinkTests {

    // MARK: - Resolving the entry points

    @Test("la URL del widget abre Mi Rutina")
    func widgetURLResolvesToRoutine() {
        #expect(AppDeepLink(url: URL(string: "quoteanime://routine")!) == .routine)
        #expect(AppDeepLink(url: AppDeepLink.routine.url) == .routine)
    }

    @Test("esquema y host no distinguen mayúsculas")
    func caseInsensitive() {
        #expect(AppDeepLink(url: URL(string: "QuoteAnime://Routine")!) == .routine)
    }

    @Test("una URL que la app no conoce no abre nada", arguments: [
        "quoteanime://habit/123",
        "quoteanime://",
        "https://routine",
        "otherapp://routine",
    ])
    func unknownURL(raw: String) {
        #expect(AppDeepLink(url: URL(string: raw)!) == nil)
    }

    /// The widget extension cannot import `AppDeepLink`, so it keeps its own copy of the URL.
    /// Reading the source is the only way to catch the two drifting apart before a user does.
    @Test("la copia del widget lleva al mismo destino que la app")
    func widgetMirrorMatchesApp() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("QuoteAnimeWidget/WidgetSharedModel.swift"),
            encoding: .utf8
        )
        let pattern = #/static let routine = URL\(string: "([^"]+)"\)!/#
        let match = try #require(source.firstMatch(of: pattern))
        let widgetURL = try #require(URL(string: String(match.1)))

        #expect(AppDeepLink(url: widgetURL) == .routine)
        #expect(widgetURL == AppDeepLink.routine.url)
    }

    @Test("el Info.plist compilado registra el esquema")
    func schemeIsRegistered() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(AppDeepLink.scheme))
    }

    @Test("tocar el cuerpo de un recordatorio abre Mi Rutina")
    func reminderBodyTap() {
        let link = AppDeepLink.forNotification(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: HabitReminderScheduler.categoryIdentifier
        )
        #expect(link == .routine)
    }

    @Test("'Hecho', descartar o una notificación de frase no navegan", arguments: [
        (HabitReminderScheduler.markDoneActionIdentifier, HabitReminderScheduler.categoryIdentifier),
        (UNNotificationDismissActionIdentifier, HabitReminderScheduler.categoryIdentifier),
        (UNNotificationDefaultActionIdentifier, ""),
    ])
    func otherResponsesDoNotNavigate(action: String, category: String) {
        #expect(AppDeepLink.forNotification(actionIdentifier: action, categoryIdentifier: category) == nil)
    }

    // MARK: - Router

    @Test("arranque en frío: la ruta queda pendiente y se aplica al terminar el splash")
    func coldStartWaitsForSplash() {
        let router = AppRouter(isRoutineAvailable: true)

        router.open(.routine)
        #expect(router.currentScreen == .splash)
        #expect(router.navigationPath.isEmpty)
        #expect(router.pendingDeepLink == .routine)

        router.navigateToMain()
        #expect(router.navigationPath == [.routine])
        #expect(router.pendingDeepLink == nil)
    }

    @Test("onboarding incompleto: no se salta, y Mi Rutina se abre al terminarlo")
    func onboardingIsNotSkipped() {
        let router = AppRouter(isRoutineAvailable: true)
        router.open(.routine)

        router.navigateToOnboarding()
        #expect(router.currentScreen == .onboarding)
        #expect(router.navigationPath.isEmpty)
        #expect(router.pendingDeepLink == .routine)

        router.navigateToMain()
        #expect(router.navigationPath == [.routine])
    }

    @Test("un toque durante el onboarding también espera a que termine")
    func tapDuringOnboarding() {
        let router = AppRouter(isRoutineAvailable: true)
        router.navigateToOnboarding()

        router.open(.routine)
        #expect(router.currentScreen == .onboarding)
        #expect(router.pendingDeepLink == .routine)
    }

    @Test("en iOS 16 (sin Mi Rutina) sólo se abre la app")
    func iOS16OnlyOpensTheApp() {
        let coldStart = AppRouter(isRoutineAvailable: false)
        coldStart.open(.routine)
        #expect(coldStart.pendingDeepLink == nil)
        coldStart.navigateToMain()
        #expect(coldStart.navigationPath.isEmpty)

        let warm = AppRouter(isRoutineAvailable: false)
        warm.navigateToMain()
        warm.push(.settings)
        warm.open(.routine)
        #expect(warm.navigationPath == [.settings])
    }

    @Test("con la app abierta navega directo, sin duplicar Mi Rutina", arguments: [
        [AppRoute](),
        [.routine],
        [.routine, .habitDetail(habitId: "h1")],
        [.settings, .categorySelection],
        [.routine, .habitEditor(habitId: nil), .paywall],
    ])
    func warmOpenReplacesTheStack(initial: [AppRoute]) {
        let router = AppRouter(isRoutineAvailable: true)
        router.navigateToMain()
        router.navigationPath = initial

        router.open(.routine)
        #expect(router.navigationPath == [.routine])

        router.open(.routine)
        #expect(router.navigationPath == [.routine])
        #expect(router.pendingDeepLink == nil)
    }

    /// The destination is the list, which never looks the habit up: a reminder for a habit that
    /// was deleted after it was scheduled still lands on Mi Rutina, and a stale detail on the
    /// stack is dropped rather than shown.
    @Test("hábito borrado: el recordatorio igual abre Mi Rutina")
    func deletedHabitStillOpensRoutine() throws {
        let router = AppRouter(isRoutineAvailable: true)
        router.navigateToMain()
        router.navigationPath = [.routine, .habitDetail(habitId: "borrado")]

        let link = AppDeepLink.forNotification(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            categoryIdentifier: HabitReminderScheduler.categoryIdentifier
        )
        router.open(try #require(link))

        #expect(router.navigationPath == [.routine])
    }

    // MARK: - Quote widget (Android `home?quoteId=`)

    @Test("la URL del widget de frases abre Inicio en esa frase", arguments: [
        "45", "-OrkSrA9-Sglsk83jpeu", "id con espacios&símbolos",
    ])
    func quoteURLRoundTrip(id: String) {
        let url = AppDeepLink.quote(id: id).url
        #expect(url.scheme == "quoteanime")
        #expect(url.host == "home")
        #expect(AppDeepLink(url: url) == .quote(id: id))
    }

    @Test("una URL de frase sin id no abre nada", arguments: [
        "quoteanime://home",
        "quoteanime://home?quoteId=",
        "quoteanime://home?otro=45",
    ])
    func quoteURLWithoutId(raw: String) {
        #expect(AppDeepLink(url: URL(string: raw)!) == nil)
    }

    /// The widget builds its URL with its own copy of the host and parameter names.
    @Test("la copia del widget de frases arma la misma URL que la app")
    func quoteWidgetMirrorMatchesApp() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("QuoteAnimeWidget/WidgetSharedModel.swift"),
            encoding: .utf8
        )
        let host = try #require(source.firstMatch(of: #/static let quoteHost = "([^"]+)"/#))
        let parameter = try #require(source.firstMatch(of: #/static let quoteIdParameter = "([^"]+)"/#))
        #expect(String(host.1) == AppDeepLink.quoteHost)
        #expect(String(parameter.1) == AppDeepLink.quoteIdParameter)

        var components = URLComponents()
        components.scheme = "quoteanime"
        components.host = String(host.1)
        components.queryItems = [URLQueryItem(name: String(parameter.1), value: "45")]
        #expect(AppDeepLink(url: try #require(components.url)) == .quote(id: "45"))
    }

    /// The widget's id rule mirrors `QuoteDTO`: the live `/quotes` node stores `id` as a number,
    /// so the app's id is the node key — and the widget sends that key.
    @Test("el id de una frase es la clave del nodo cuando el campo id es numérico")
    func quoteIdIsTheNodeKey() throws {
        let fields: [String: Any] = ["id": 1, "quote": "q", "author": "a", "anime": "Naruto"]
        #expect(try #require(QuoteDTO(dict: fields, key: "45")).id == "45")
        #expect(try #require(QuoteDTO(dict: fields.merging(["id": "abc"]) { $1 }, key: "45")).id == "abc")
    }

    @Test("arranque en frío desde el widget de frases: espera al splash y pide la frase a Inicio")
    func quoteColdStart() {
        let router = AppRouter(isRoutineAvailable: true)
        router.open(.quote(id: "45"))
        #expect(router.pendingDeepLink == .quote(id: "45"))
        #expect(router.quoteFocusRequest == nil)

        router.navigateToMain()
        #expect(router.navigationPath.isEmpty)
        #expect(router.quoteFocusRequest == "45")

        router.consumeQuoteFocusRequest()
        #expect(router.quoteFocusRequest == nil)
    }

    @Test("con la app abierta vuelve a Inicio, desde cualquier pantalla", arguments: [
        [AppRoute](),
        [.settings, .categorySelection],
        [.routine, .habitEditor(habitId: nil)],
    ])
    func quoteWarmOpenPopsToHome(initial: [AppRoute]) {
        let router = AppRouter(isRoutineAvailable: true)
        router.navigateToMain()
        router.navigationPath = initial

        router.open(.quote(id: "45"))
        #expect(router.navigationPath.isEmpty)
        #expect(router.quoteFocusRequest == "45")
    }

    @Test("en iOS 16 el widget de frases sí posiciona Inicio")
    func quoteWorksWithoutRoutine() {
        let router = AppRouter(isRoutineAvailable: false)
        router.navigateToMain()
        router.open(.quote(id: "45"))
        #expect(router.quoteFocusRequest == "45")
    }

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // quoteAnimeTests
        .deletingLastPathComponent()   // repo root
}
