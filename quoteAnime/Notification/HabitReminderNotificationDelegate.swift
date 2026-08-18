import Foundation
import UserNotifications

/// Handles the "Hecho" action tapped directly from a habit reminder notification, without
/// opening the app. Registered as `UNUserNotificationCenter.current().delegate` once
/// `AppDependencies` exists (needs `ToggleHabitCompletionUseCase`, nil below iOS 17).
final class HabitReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let toggleHabitCompletion: ToggleHabitCompletionUseCase

    init(toggleHabitCompletion: ToggleHabitCompletionUseCase) {
        self.toggleHabitCompletion = toggleHabitCompletion
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
            try? await toggleHabitCompletion.execute(habitId: habitId, date: Date())
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
