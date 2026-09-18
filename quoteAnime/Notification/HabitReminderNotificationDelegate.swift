import Foundation
import UserNotifications

/// Handles a habit reminder: its "Hecho" action, which marks the day without opening the app, and
/// a tap on its body, which opens Mi Rutina (`AppDeepLink.forNotification`). Registered as
/// `UNUserNotificationCenter.current().delegate` by `AppDependencies`, which `QuoteAnimeApp`
/// builds in its `init` — before launch finishes, as the delegate must be for the tap that
/// cold-launched the app to reach it. Needs `ToggleHabitCompletionUseCase`, so nil below iOS 17,
/// where there are no habits and so no reminders to tap.
final class HabitReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let markDone: HabitReminderDoneAction
    private let routineWidgetRefresher: RoutineWidgetRefreshing
    /// `AppRouter.open(_:)`, wired by `QuoteAnimeApp` once the router exists. Until then a tap is
    /// dropped — it can't be, in practice: both are built in the same `init`.
    var openDeepLink: ((AppDeepLink) -> Void)?

    init(
        markDone: HabitReminderDoneAction,
        routineWidgetRefresher: RoutineWidgetRefreshing = NoopRoutineWidgetRefresher()
    ) {
        self.markDone = markDone
        self.routineWidgetRefresher = routineWidgetRefresher
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        if let link = AppDeepLink.forNotification(
            actionIdentifier: response.actionIdentifier,
            categoryIdentifier: content.categoryIdentifier
        ) {
            openDeepLink?(link)
            completionHandler()
            return
        }

        guard
            response.actionIdentifier == HabitReminderScheduler.markDoneActionIdentifier,
            let habitId = content.userInfo["habitId"] as? String
        else {
            completionHandler()
            return
        }

        Task {
            // A rejection here (habit deleted, reminder fired past its end date, day already
            // marked) is silent on purpose: there is no UI to report it to from a notification.
            await markDone.execute(habitId: habitId)
            // The app is usually not on screen when this runs, so nothing else would refresh the
            // widgets. Android doesn't do this from its own "Done" action — reported as a gap
            // there rather than mirrored here, since the widget would otherwise show yesterday's
            // state until the app is opened.
            await routineWidgetRefresher.refresh()
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
