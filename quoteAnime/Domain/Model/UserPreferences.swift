import Foundation

struct UserPreferences {
    var selectedCategoryIds: Set<String> = []
    var notificationsEnabled: Bool = false
    var notificationStartHour: Int = 8
    var notificationStartMinute: Int = 0
    var notificationEndHour: Int = 22
    var notificationEndMinute: Int = 0
    var notificationFrequency: Int = 1      // veces al día, 1–10
    var widgetUpdateTimesPerDay: Int = 2    // 1–8
}
