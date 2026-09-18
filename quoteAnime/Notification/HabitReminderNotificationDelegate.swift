import Foundation
import UserNotifications

/// Handles the "Hecho" action tapped directly from a habit reminder notification, without
/// opening the app. Registered as `UNUserNotificationCenter.current().delegate` once
/// `AppDependencies` exists (needs `ToggleHabitCompletionUseCase`, nil below iOS 17).
final class HabitReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let markDone: HabitReminderDoneAction
    private let routineWidgetRefresher: RoutineWidgetRefreshing

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
        guard
            response.actionIdentifier == HabitReminderScheduler.markDoneActionIdentifier,
            let habitId = response.notification.request.content.userInfo["habitId"] as? String
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
