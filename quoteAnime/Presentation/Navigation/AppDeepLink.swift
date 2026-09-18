import Foundation
import UserNotifications

/// A place the app can be opened at from outside itself: a habit reminder or a widget.
///
/// `.quote` is Android's `widget_quote_id` extra (the quote widget's open intent), which starts
/// the graph at `home?quoteId=…`: the feed, positioned on the quote the widget was showing.
///
/// Android's `EXTRA_OPEN_ROUTINE` intent extra — set by the reminder's content intent
/// (`e4fbf2f`, `4b691bf`) and by the open intent of both routine widgets (`132e96b`). iOS has no
/// intent extras, so the widgets carry it as a URL (`quoteanime://routine`, registered under
/// `CFBundleURLTypes` in `Info.plist`) and the reminder tap builds the same value from the
/// notification's category. Both end in `AppRouter.open(_:)`: one door for every entry point.
enum AppDeepLink: Equatable {
    /// Mi Rutina's list. Never a habit's detail — Android opens the list from the reminder and
    /// from both widgets alike — which is also why a habit deleted after its reminder was
    /// scheduled cannot break the tap: nothing here looks the habit up.
    case routine

    /// Home, scrolled to this quote. The id is the app's `Quote.id` (the RTDB node key, see
    /// `QuoteDTO`). Nothing is guaranteed to still hold it: a quote removed remotely, or one
    /// outside the current anime selection, just opens Home — `HomeViewModel.focus(onQuoteId:)`.
    case quote(id: String)

    static let scheme = "quoteanime"
    /// `quoteanime://home?quoteId=<id>` — Android's route is `home?quoteId={quoteId}`.
    static let quoteHost = "home"
    static let quoteIdParameter = "quoteId"

    /// The URL the widgets hand to `widgetURL`. **Mirrored by hand** in the widget extension
    /// (`WidgetDeepLink` in `QuoteAnimeWidget/WidgetSharedModel.swift`), which cannot import this
    /// type; `AppDeepLinkTests` fails if the two drift apart.
    var url: URL {
        switch self {
        case .routine:
            return URL(string: "\(Self.scheme)://routine")!
        case .quote(let id):
            var components = URLComponents()
            components.scheme = Self.scheme
            components.host = Self.quoteHost
            components.queryItems = [URLQueryItem(name: Self.quoteIdParameter, value: id)]
            return components.url!
        }
    }

    /// Nil for anything this build doesn't recognise: the app then just opens where it was.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        switch url.host?.lowercased() {
        case "routine":
            self = .routine
        case Self.quoteHost:
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == Self.quoteIdParameter }?.value
            guard let id, !id.isEmpty else { return nil }
            self = .quote(id: id)
        default:
            return nil
        }
    }

    /// What tapping a delivered notification opens, from the two values its response carries.
    /// Only the body of a habit reminder routes anywhere: its "Hecho" button marks the day
    /// without opening the app, and a quote notification opens the app where it was, as on
    /// Android. Pure because `UNNotificationResponse` cannot be built in a test.
    static func forNotification(actionIdentifier: String, categoryIdentifier: String) -> AppDeepLink? {
        guard actionIdentifier == UNNotificationDefaultActionIdentifier,
              categoryIdentifier == HabitReminderScheduler.categoryIdentifier
        else { return nil }
        return .routine
    }
}
