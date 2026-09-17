import Foundation

/// What the habit view models need in order to keep the home-screen widgets in sync. A protocol
/// so they can be tested without writing into the real App Group, the same reason
/// `HabitReminderScheduling` exists.
protocol RoutineWidgetRefreshing {
    func refresh() async
}

/// iOS counterpart of Android's `RoutineWidgetScheduler.triggerImmediateUpdate()`: called right
/// after anything that changes what a widget shows — a day marked, a habit created, edited,
/// archived, restored or deleted — so the home screen doesn't wait for WidgetKit's own schedule.
///
/// Android enqueues a `OneTimeWorkRequest` that re-reads the database; here the read is done
/// inline and the result written to the App Group, because on iOS the extension can't reach the
/// store at all and the snapshot *is* the widget's data. Both widget kinds are reloaded together,
/// as on Android, since one habit change can move both the summary and a per-habit instance.
///
/// The periodic half of Android's scheduler (a 24h `PeriodicWorkRequest` so the heatmap's "today"
/// column and the streak still roll over on a day the app is never opened) has no equivalent here:
/// each widget's `TimelineProvider` already asks to be woken a few hours out, which is iOS's own
/// answer to the same problem.
final class RoutineWidgetRefresher: RoutineWidgetRefreshing {
    private let getActiveHabits: GetActiveHabitsUseCase
    private let getArchivedHabits: GetArchivedHabitsUseCase
    private let getGlobalStreak: GetGlobalStreakUseCase
    private let now: () -> Date
    private let publish: (HabitWidgetSnapshot) -> Void

    /// `publish` is injectable so a test can watch the snapshot this builds without writing into
    /// the real App Group or poking `WidgetCenter`, which a unit test has no business doing.
    init(
        getActiveHabits: GetActiveHabitsUseCase,
        getArchivedHabits: GetArchivedHabitsUseCase,
        getGlobalStreak: GetGlobalStreakUseCase,
        now: @escaping () -> Date = Date.init,
        publish: @escaping (HabitWidgetSnapshot) -> Void = HabitWidgetDataWriter.write
    ) {
        self.getActiveHabits = getActiveHabits
        self.getArchivedHabits = getArchivedHabits
        self.getGlobalStreak = getGlobalStreak
        self.now = now
        self.publish = publish
    }

    /// Archived habits are read too: a widget bound to a habit that was later archived must keep
    /// showing its history rather than claim the habit no longer exists. Only a real delete makes
    /// it disappear from the snapshot, which is the same distinction Android draws.
    func refresh() async {
        let today = now()
        do {
            let active = try await getActiveHabits.execute(today: today)
            let archived = try await getArchivedHabits.execute(today: today)
            let streak = try await getGlobalStreak.execute(today: today)
            publish(
                HabitWidgetDataWriter.snapshot(
                    active: active,
                    archived: archived,
                    globalStreak: streak.current,
                    today: today
                )
            )
        } catch {
            // A failed refresh leaves the previous snapshot in place, which is strictly better
            // than blanking the widget — same choice Android's worker makes when the DB read fails.
            print("[RoutineWidgetRefresher] refresh error: \(error)")
        }
    }
}

/// Does nothing. For `#Preview`s and for the iOS 16 path, where there is no habit repository to
/// read from and therefore no snapshot to write.
struct NoopRoutineWidgetRefresher: RoutineWidgetRefreshing {
    func refresh() async {}
}
