import Foundation
import WidgetKit

final class UserPreferencesStore {
    private enum Keys {
        static let notificationsEnabled    = "pref_notifications_enabled"
        static let notificationStartHour   = "pref_notification_start_hour"
        static let notificationStartMinute = "pref_notification_start_minute"
        static let notificationEndHour     = "pref_notification_end_hour"
        static let notificationEndMinute   = "pref_notification_end_minute"
        static let notificationFrequency   = "pref_notification_frequency"
        static let widgetUpdateTimesPerDay = "pref_widget_update_times"
        static let selectedCategoryIds     = "pref_selected_category_ids"
        static let onboardingCompleted     = "pref_onboarding_completed"
    }

    private let defaults = UserDefaults.standard

    func load() -> UserPreferences {
        var prefs = UserPreferences()
        prefs.notificationsEnabled    = defaults.bool(forKey: Keys.notificationsEnabled)
        prefs.notificationStartHour   = defaults.object(forKey: Keys.notificationStartHour)   as? Int ?? 8
        prefs.notificationStartMinute = defaults.object(forKey: Keys.notificationStartMinute) as? Int ?? 0
        prefs.notificationEndHour     = defaults.object(forKey: Keys.notificationEndHour)     as? Int ?? 22
        prefs.notificationEndMinute   = defaults.object(forKey: Keys.notificationEndMinute)   as? Int ?? 0
        prefs.notificationFrequency   = defaults.object(forKey: Keys.notificationFrequency)   as? Int ?? 1
        prefs.widgetUpdateTimesPerDay = defaults.object(forKey: Keys.widgetUpdateTimesPerDay) as? Int ?? 2
        prefs.selectedCategoryIds     = Set(defaults.stringArray(forKey: Keys.selectedCategoryIds) ?? [])
        return prefs
    }

    func save(_ preferences: UserPreferences) {
        defaults.set(preferences.notificationsEnabled,    forKey: Keys.notificationsEnabled)
        defaults.set(preferences.notificationStartHour,   forKey: Keys.notificationStartHour)
        defaults.set(preferences.notificationStartMinute, forKey: Keys.notificationStartMinute)
        defaults.set(preferences.notificationEndHour,     forKey: Keys.notificationEndHour)
        defaults.set(preferences.notificationEndMinute,   forKey: Keys.notificationEndMinute)
        defaults.set(preferences.notificationFrequency,   forKey: Keys.notificationFrequency)
        defaults.set(preferences.widgetUpdateTimesPerDay, forKey: Keys.widgetUpdateTimesPerDay)
        defaults.set(Array(preferences.selectedCategoryIds), forKey: Keys.selectedCategoryIds)

        // Share widget frequency with the widget extension via App Group
        UserDefaults(suiteName: "group.com.gonzadev.quoteAnime")?
            .set(preferences.widgetUpdateTimesPerDay, forKey: "widget_update_times_per_day")

        WidgetCenter.shared.reloadAllTimelines()
    }

    var isOnboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
}
