import Foundation

/// When quote notifications fire. Mirrors Android's `QuoteNotificationSlotCalculator`
/// (`4b5d21f`) exactly for the window arithmetic, so both apps deliver the same times:
///
/// - The N slots are spread **end to end** across the window: 3 per day in 08:00–22:00 fire at
///   08:00, 15:00 and 22:00. One per day fires at the window start.
/// - A window may cross midnight (22:00–02:00 → 22:00, 00:00, 02:00).
/// - A window whose start equals its end covers the whole day, split without firing twice at
///   the start (4 per day from 08:00 → 08:00, 14:00, 20:00, 02:00).
/// - The frequency is clamped to 1…10, the range the Settings slider offers.
///
/// Where the platforms differ is what happens with the slots. Android chains one WorkManager job
/// to the next slot at a time; iOS runs no code when a notification fires, so it books the next
/// `limit` slots up front (`upcomingSlots`). Android's `isWithinWindow` + 30 min grace is **not**
/// ported: it exists because WorkManager fires late, and a `UNCalendarNotificationTrigger` fires
/// on the minute it names — every booked date is a slot, so there is nothing left to re-check.
///
/// Pure — no `UNUserNotificationCenter` — so the arithmetic is unit tested.
enum QuoteNotificationSlotCalculator {

    static let minutesPerDay = 24 * 60
    static let frequencyRange = 1...10

    /// Minutes-of-day (0..<1440) of each slot, in firing order from the window start. For a
    /// window that crosses midnight the later slots wrap past 0 (`[1320, 0, 120]` for 22–02).
    static func slotsFor(startMinute: Int, endMinute: Int, timesPerDay: Int) -> [Int] {
        slotOffsets(startMinute: startMinute, endMinute: endMinute, timesPerDay: timesPerDay)
            .map { (startMinute + $0) % minutesPerDay }
    }

    /// The first `limit` slots strictly after `now`, oldest first, as wall-clock dates in
    /// `calendar`'s time zone.
    ///
    /// Each day's window is laid out from its own start, starting with **yesterday's**: a window
    /// that crosses midnight opened the previous evening, and its 00:00 and 02:00 slots belong to
    /// it. Windows never overlap (the last slot of one is always before the next one opens), so
    /// the night of the change is neither lost nor booked twice.
    ///
    /// Slots are built from wall-clock components rather than by adding minutes to an instant,
    /// as Android adds to a `LocalDateTime`: across a DST change 22:00–02:00 still means 02:00.
    static func upcomingSlots(
        from now: Date,
        startMinute: Int,
        endMinute: Int,
        timesPerDay: Int,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0 else { return [] }
        let offsets = slotOffsets(startMinute: startMinute, endMinute: endMinute, timesPerDay: timesPerDay)
        let today = calendar.startOfDay(for: now)

        var result: [Date] = []
        // Every window holds at least one slot, so `limit + 2` windows (yesterday's included)
        // always reach `limit` — the bound only stops a pathological calendar from spinning.
        var windowDay = -1
        while result.count < limit, windowDay <= limit + 1 {
            for offset in offsets {
                let total = startMinute + offset
                guard
                    let day = calendar.date(byAdding: .day, value: windowDay + total / minutesPerDay, to: today)
                else { continue }
                var parts = calendar.dateComponents([.year, .month, .day], from: day)
                parts.hour = (total % minutesPerDay) / 60
                parts.minute = total % 60
                guard let date = calendar.date(from: parts), date > now else { continue }
                // A DST gap moves a missing 02:30 to 03:30; never book the same instant twice.
                if let last = result.last, date <= last { continue }
                result.append(date)
                if result.count == limit { break }
            }
            windowDay += 1
        }
        return result
    }

    /// The next slot strictly after `from` — Android's `nextSlot`.
    static func nextSlot(from now: Date, startMinute: Int, endMinute: Int, timesPerDay: Int,
                         calendar: Calendar = .current) -> Date? {
        upcomingSlots(from: now, startMinute: startMinute, endMinute: endMinute,
                      timesPerDay: timesPerDay, limit: 1, calendar: calendar).first
    }

    // MARK: - Private

    private static func slotOffsets(startMinute: Int, endMinute: Int, timesPerDay: Int) -> [Int] {
        let count = min(max(timesPerDay, frequencyRange.lowerBound), frequencyRange.upperBound)
        if count == 1 { return [0] }
        let length = windowLength(startMinute: startMinute, endMinute: endMinute)
        // A full-day window has no separate end: spreading to both ends would fire twice at start.
        let gaps = length == minutesPerDay ? count : count - 1
        return (0..<count).map { $0 * length / gaps }
    }

    private static func windowLength(startMinute: Int, endMinute: Int) -> Int {
        let length = ((endMinute - startMinute) % minutesPerDay + minutesPerDay) % minutesPerDay
        return length == 0 ? minutesPerDay : length
    }
}

extension UserPreferences {
    var notificationStartMinuteOfDay: Int { notificationStartHour * 60 + notificationStartMinute }
    var notificationEndMinuteOfDay: Int { notificationEndHour * 60 + notificationEndMinute }
}
