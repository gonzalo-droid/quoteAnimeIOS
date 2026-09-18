import Foundation

/// A parameter value, restricted to what both Firebase SDKs accept. Kept as an enum so tests can
/// compare events for equality.
enum AnalyticsValue: Equatable {
    case string(String)
    case int(Int)
    /// Android writes these with `Bundle.putBoolean`; iOS hands Firebase an `NSNumber` holding a
    /// `Bool`, which is the same shape.
    case bool(Bool)
}

/// One Firebase event: its name and parameters, exactly as they are sent.
struct AnalyticsEvent: Equatable {
    let name: String
    let parameters: [String: AnalyticsValue]
}

/// Where a completion came from — Android's `RoutineAnalytics.SOURCE_APP` / `SOURCE_NOTIFICATION`.
enum HabitCompletionSource: String {
    case app = "app"
    case notification = "notification"
}

/// "Mi Rutina" events (Android `9b82ee4`, `analytics/RoutineAnalytics.kt`).
///
/// **Names, parameter keys and values are copied verbatim from Android** — this is one of the few
/// values that must cross platforms, so both apps land in the same Firebase events and a report can
/// read them together. Never rename one here without renaming it there.
///
/// The protocol has a single requirement so a test fake can record the exact `AnalyticsEvent`
/// that production would send; the `track…` helpers below are the only place events are built.
protocol RoutineAnalytics {
    func log(_ event: AnalyticsEvent)
}

extension RoutineAnalytics {
    func trackTabOpened() { log(RoutineAnalyticsEvents.tabOpened()) }

    func trackHabitDetailOpened() { log(RoutineAnalyticsEvents.habitDetailOpened()) }

    func trackHabitCreated(templateId: String?, hasReminder: Bool, hasEndDate: Bool) {
        log(RoutineAnalyticsEvents.habitCreated(templateId: templateId, hasReminder: hasReminder, hasEndDate: hasEndDate))
    }

    func trackHabitCompleted(habitId: String, isRetroactive: Bool, source: HabitCompletionSource) {
        log(RoutineAnalyticsEvents.habitCompleted(habitId: habitId, isRetroactive: isRetroactive, source: source))
    }

    func trackHabitArchived(createdAt: Date, now: Date = Date()) {
        log(RoutineAnalyticsEvents.habitArchived(daysActive: RoutineAnalyticsEvents.daysActive(createdAt: createdAt, now: now)))
    }

    /// Fires `streak_milestone` or `streak_broken` when the change calls for one; nothing otherwise.
    func trackStreakChange(previous: Int, current: Int) {
        if let event = RoutineAnalyticsEvents.streakChange(previous: previous, current: current) {
            log(event)
        }
    }
}

/// The event factories, pure, mirroring each `track…` method of Android's `RoutineAnalytics`.
enum RoutineAnalyticsEvents {
    /// Android's `STREAK_MILESTONES` (`RoutineViewModel.kt`).
    static let streakMilestones: Set<Int> = [7, 21, 50, 100]

    static func tabOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: "routine_tab_opened", parameters: [:])
    }

    static func habitDetailOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: "habit_detail_opened", parameters: [:])
    }

    /// `template_id` is the template's id or `"custom"`; `is_custom` is `templateId == nil`.
    static func habitCreated(templateId: String?, hasReminder: Bool, hasEndDate: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "habit_created", parameters: [
            "template_id": .string(templateId ?? "custom"),
            "is_custom": .bool(templateId == nil),
            "has_reminder": .bool(hasReminder),
            "has_end_date": .bool(hasEndDate),
        ])
    }

    static func habitCompleted(habitId: String, isRetroactive: Bool, source: HabitCompletionSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "habit_completed", parameters: [
            "habit_id": .string(habitId),
            "is_retroactive": .bool(isRetroactive),
            "source": .string(source.rawValue),
        ])
    }

    static func habitArchived(daysActive: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "habit_archived", parameters: ["days_active": .int(daysActive)])
    }

    static func streakMilestone(days: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "streak_milestone", parameters: ["days": .int(days)])
    }

    static func streakBroken(previousStreak: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "streak_broken", parameters: ["previous_streak": .int(previousStreak)])
    }

    /// Android's `trackStreakChange`: a milestone only when the streak *rose* onto one of the
    /// thresholds (unmarking 8 → 7 is not a milestone), a break only when a live streak fell to 0.
    static func streakChange(previous: Int, current: Int) -> AnalyticsEvent? {
        if streakMilestones.contains(current), current > previous {
            return streakMilestone(days: current)
        }
        if previous > 0, current == 0 {
            return streakBroken(previousStreak: previous)
        }
        return nil
    }

    /// Android: `(clock.millis() - habit.createdAt) / MILLIS_PER_DAY` — whole 24-hour periods since
    /// the habit was created, truncated, not calendar days.
    static func daysActive(createdAt: Date, now: Date) -> Int {
        Int(now.timeIntervalSince(createdAt) / 86_400)
    }
}

/// For previews and for the places where "Mi Rutina" cannot run.
struct NoopRoutineAnalytics: RoutineAnalytics {
    func log(_ event: AnalyticsEvent) {}
}
