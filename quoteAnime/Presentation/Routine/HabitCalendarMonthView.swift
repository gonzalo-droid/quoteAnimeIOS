import SwiftUI

/// The month calendar on the habit detail screen, and the only surface where days get marked.
///
/// Why this is hand-built and not `MultiDatePicker`: that control models "pick a set of dates"
/// with a `Set<DateComponents>` binding, which fights a toggle whose every tap has to be
/// validated (future days, days outside the habit window) and can be refused. It also offers no
/// way to render a day as present-but-unmarkable, and no hook for the month the user is
/// looking at. The grid itself is `CalendarMonthGrid`, a pure mirror of Android's; only the
/// drawing lives here.
///
/// Days that cannot be marked — future days, days before the habit started or after it ended —
/// are dimmed and non-interactive, so the rule is visible instead of only being enforced when
/// tapped.
struct HabitCalendarMonthView: View {
    let month: Date
    let completions: Set<Date>
    let today: Date
    let habit: Habit
    let accentColor: Color
    let calendar: Calendar
    let onDayTap: (Date) -> Void

    private var days: [Date] { CalendarMonthGrid.days(for: month, calendar: calendar) }

    private var weekdaySymbols: [String] {
        // `shortWeekdaySymbols` is Sunday-first; the grid is Monday-first.
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { symbols[($0 + 1) % 7].prefix(1).uppercased() }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: CalendarMonthGrid.columns),
                spacing: 2
            ) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isInMonth = CalendarMonthGrid.isSameMonth(day, as: month, calendar: calendar)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isCompleted = completions.contains(calendar.startOfDay(for: day))
        let isMarkable = calendar.startOfDay(for: day) <= calendar.startOfDay(for: today)
            && habit.isActiveOn(day, calendar: calendar)

        Button {
            onDayTap(day)
        } label: {
            ZStack {
                if isToday {
                    Circle()
                        .fill(accentColor.opacity(0.22))
                        .padding(4)
                }
                VStack(spacing: 3) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                        .foregroundColor(dayNumberColor(isInMonth: isInMonth, isMarkable: isMarkable, isToday: isToday))
                    Circle()
                        .fill(isCompleted ? accentColor : Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isMarkable)
        .accessibilityLabel(accessibilityLabel(for: day, isCompleted: isCompleted, isMarkable: isMarkable))
        .accessibilityAddTraits(isCompleted ? [.isSelected] : [])
    }

    private func dayNumberColor(isInMonth: Bool, isMarkable: Bool, isToday: Bool) -> Color {
        if !isMarkable { return .textSecondary.opacity(0.3) }
        if !isInMonth { return .textSecondary.opacity(0.55) }
        return isToday ? .textPrimary : .textSecondary
    }

    private func accessibilityLabel(for day: Date, isCompleted: Bool, isMarkable: Bool) -> String {
        let formatted = day.formatted(.dateTime.day().month(.wide).year())
        guard isMarkable else { return "\(formatted), no se puede marcar" }
        return isCompleted ? "\(formatted), completado" : "\(formatted), sin completar"
    }
}

#Preview("Calendario del mes") {
    let calendar = Calendar.current
    let today = Date()
    let habit = Habit(
        id: "preview",
        title: "Entrenar",
        description: nil,
        iconKey: "dumbbell",
        colorIndex: 4,
        startDate: calendar.date(byAdding: .day, value: -20, to: today)!,
        endDate: nil,
        templateId: nil,
        coverAnimeSlug: nil,
        createdAt: today
    )
    let completions = Set(
        [0, 1, 3, 4, 7, 8, 9].compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: today))
        }
    )

    return HabitCalendarMonthView(
        month: today,
        completions: completions,
        today: today,
        habit: habit,
        accentColor: HabitPalette.color(at: 4),
        calendar: calendar,
        onDayTap: { _ in }
    )
    .padding()
    .background(Color.bgDark)
}
