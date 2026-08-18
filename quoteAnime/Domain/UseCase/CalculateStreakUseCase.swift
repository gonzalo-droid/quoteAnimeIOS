import Foundation

/// Pure function: given the dates a habit was completed, returns the streak state. A
/// streak stays alive while the most recent completion is today or yesterday. Mirrors the
/// Android use case of the same name exactly (descending sort, alive check, run lengths).
struct CalculateStreakUseCase {
    private let calendar = Calendar.current

    func execute(dates: [Date], today: Date) -> StreakState {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        guard let last = days.first else { return StreakState() }

        let todayStart = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let isAlive = last == todayStart || last == yesterday
        let current = isAlive ? runLength(days, from: 0) : 0
        let best = longestRun(days)

        return StreakState(
            current: current,
            best: best,
            lastCompletedDate: last,
            completedToday: last == todayStart
        )
    }

    /// Length of the consecutive run starting at `startIndex` in a descending-sorted list.
    private func runLength(_ sortedDesc: [Date], from startIndex: Int) -> Int {
        var length = 1
        var index = startIndex
        while index + 1 < sortedDesc.count,
              let previousDay = calendar.date(byAdding: .day, value: -1, to: sortedDesc[index]),
              calendar.isDate(sortedDesc[index + 1], inSameDayAs: previousDay) {
            length += 1
            index += 1
        }
        return length
    }

    private func longestRun(_ sortedDesc: [Date]) -> Int {
        guard !sortedDesc.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for index in 1..<sortedDesc.count {
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: sortedDesc[index - 1]),
               calendar.isDate(sortedDesc[index], inSameDayAs: previousDay) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }
}
