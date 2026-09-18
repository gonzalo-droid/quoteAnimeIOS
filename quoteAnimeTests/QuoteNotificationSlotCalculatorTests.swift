import Foundation
import Testing
@testable import quoteAnime

/// Android `4b5d21f`: `QuoteNotificationSlotCalculatorTest` ported case by case (the `slotsFor`
/// and `nextSlot` tables), plus what only iOS has to get right because it books up to 64
/// notifications at once instead of one: the night a crossing window changes day, the 64-request
/// budget spread over several days, and a DST change.
///
/// Android's `isWithinWindow` cases are not ported: that check exists for WorkManager's late
/// runs, and iOS has no code running at fire time to apply it (see the calculator's `///`).
@Suite("Notificaciones de frases: horarios")
struct QuoteNotificationSlotCalculatorTests {

    private static let eight = t("08:00")
    private static let twentyTwo = t("22:00")
    private static let two = t("02:00")

    private static let calendar = TestCalendar.fixed

    /// "HH:mm" → minutes of day.
    private static func t(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    /// "yyyy-MM-ddTHH:mm" → a wall-clock instant in the fixed test time zone.
    private static func dt(_ value: String, calendar: Calendar = calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)!
    }

    private static func hhmm(_ date: Date, calendar: Calendar = calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    private static func upcoming(_ from: String, _ start: Int, _ end: Int, _ times: Int, limit: Int) -> [Date] {
        QuoteNotificationSlotCalculator.upcomingSlots(
            from: dt(from), startMinute: start, endMinute: end, timesPerDay: times,
            limit: limit, calendar: calendar
        )
    }

    // MARK: - slotsFor (Android's table)

    struct SlotCase: CustomTestStringConvertible, Sendable {
        let label: String
        let start: String
        let end: String
        let times: Int
        let expected: [String]
        var testDescription: String { label }
    }

    @Test("reparto de punta a punta", arguments: [
        SlotCase(label: "1 por día: al abrir la ventana", start: "08:00", end: "22:00", times: 1,
                 expected: ["08:00"]),
        SlotCase(label: "2 por día: en los dos extremos", start: "08:00", end: "22:00", times: 2,
                 expected: ["08:00", "22:00"]),
        SlotCase(label: "3 por día: 08, 15 y 22", start: "08:00", end: "22:00", times: 3,
                 expected: ["08:00", "15:00", "22:00"]),
        SlotCase(label: "5 por día: cada 3 h 30", start: "08:00", end: "22:00", times: 5,
                 expected: ["08:00", "11:30", "15:00", "18:30", "22:00"]),
        SlotCase(label: "ventana que cruza la medianoche", start: "22:00", end: "02:00", times: 3,
                 expected: ["22:00", "00:00", "02:00"]),
        SlotCase(label: "inicio == fin: el día entero sin repetir el inicio", start: "08:00", end: "08:00", times: 4,
                 expected: ["08:00", "14:00", "20:00", "02:00"]),
        SlotCase(label: "frecuencia menor que 1 cuenta como 1", start: "08:00", end: "22:00", times: 0,
                 expected: ["08:00"]),
    ])
    func slots(_ c: SlotCase) {
        let slots = QuoteNotificationSlotCalculator.slotsFor(
            startMinute: Self.t(c.start), endMinute: Self.t(c.end), timesPerDay: c.times
        )
        #expect(slots == c.expected.map(Self.t))
    }

    @Test("10 por día: diez, y la última es justo el fin de la ventana")
    func tenPerDay() {
        let slots = QuoteNotificationSlotCalculator.slotsFor(startMinute: Self.eight, endMinute: Self.twentyTwo, timesPerDay: 10)
        #expect(slots.count == 10)
        #expect(slots.first == Self.eight)
        #expect(slots.last == Self.twentyTwo)
        #expect(slots == slots.sorted())
    }

    @Test("una frecuencia mayor que 10 se limita a 10")
    func cappedAtTen() {
        #expect(QuoteNotificationSlotCalculator.slotsFor(startMinute: Self.eight, endMinute: Self.twentyTwo, timesPerDay: 15).count == 10)
    }

    @Test("inicio == fin con 1 por día dispara una sola vez, al inicio")
    func fullDayOnePerDay() {
        #expect(QuoteNotificationSlotCalculator.slotsFor(startMinute: Self.eight, endMinute: Self.eight, timesPerDay: 1) == [Self.eight])
    }

    @Test("los minutos de inicio y fin cuentan (08:15–21:45, 3 por día)")
    func minutesCount() {
        #expect(QuoteNotificationSlotCalculator.slotsFor(startMinute: Self.t("08:15"), endMinute: Self.t("21:45"), timesPerDay: 3)
                == ["08:15", "15:00", "21:45"].map(Self.t))
    }

    // MARK: - nextSlot (Android's table)

    struct NextCase: CustomTestStringConvertible, Sendable {
        let label: String
        let from: String
        let start: String
        let end: String
        let expected: String
        var testDescription: String { label }
    }

    @Test("próximo horario", arguments: [
        NextCase(label: "antes de la ventana: el primero de hoy",
                 from: "2026-07-25T07:00", start: "08:00", end: "22:00", expected: "2026-07-25T08:00"),
        NextCase(label: "entre horarios: el siguiente de hoy",
                 from: "2026-07-25T09:00", start: "08:00", end: "22:00", expected: "2026-07-25T15:00"),
        NextCase(label: "justo en un horario: se lo salta",
                 from: "2026-07-25T15:00", start: "08:00", end: "22:00", expected: "2026-07-25T22:00"),
        NextCase(label: "pasado el último: el primero de mañana",
                 from: "2026-07-25T23:00", start: "08:00", end: "22:00", expected: "2026-07-26T08:00"),
        NextCase(label: "ventana nocturna antes de las 00: la medianoche",
                 from: "2026-07-25T23:00", start: "22:00", end: "02:00", expected: "2026-07-26T00:00"),
        NextCase(label: "ventana nocturna abierta ayer: las 02 de hoy",
                 from: "2026-07-26T01:00", start: "22:00", end: "02:00", expected: "2026-07-26T02:00"),
        NextCase(label: "ventana nocturna ya cerrada: la apertura de esta noche",
                 from: "2026-07-26T03:00", start: "22:00", end: "02:00", expected: "2026-07-26T22:00"),
    ])
    func next(_ c: NextCase) {
        let next = QuoteNotificationSlotCalculator.nextSlot(
            from: Self.dt(c.from), startMinute: Self.t(c.start), endMinute: Self.t(c.end),
            timesPerDay: 3, calendar: Self.calendar
        )
        #expect(next == Self.dt(c.expected))
    }

    // MARK: - Booking ahead (iOS only)

    @Test("3 por día en 08–22: los horarios de los próximos días, en orden")
    func threePerDayAhead() {
        let dates = Self.upcoming("2026-07-25T09:00", Self.eight, Self.twentyTwo, 3, limit: 5)
        #expect(dates == [
            "2026-07-25T15:00", "2026-07-25T22:00",
            "2026-07-26T08:00", "2026-07-26T15:00", "2026-07-26T22:00",
        ].map { Self.dt($0) })
    }

    @Test("ventana 22–02: la noche del cambio de día no se pierde ni se duplica")
    func crossingWindowAhead() {
        let dates = Self.upcoming("2026-07-25T12:00", Self.twentyTwo, Self.two, 3, limit: 7)
        #expect(dates == [
            "2026-07-25T22:00", "2026-07-26T00:00", "2026-07-26T02:00",
            "2026-07-26T22:00", "2026-07-27T00:00", "2026-07-27T02:00",
            "2026-07-27T22:00",
        ].map { Self.dt($0) })
        #expect(Set(dates).count == dates.count)
    }

    @Test("ventana 22–02 abierta ayer: primero lo que queda de anoche")
    func crossingWindowOpenedYesterday() {
        let dates = Self.upcoming("2026-07-26T00:30", Self.twentyTwo, Self.two, 3, limit: 4)
        #expect(dates == [
            "2026-07-26T02:00", "2026-07-26T22:00", "2026-07-27T00:00", "2026-07-27T02:00",
        ].map { Self.dt($0) })
    }

    @Test("inicio == fin: 24 h cubiertas, ningún horario repetido entre días")
    func fullDayAhead() {
        let dates = Self.upcoming("2026-07-25T07:00", Self.eight, Self.eight, 4, limit: 8)
        #expect(dates.map { Self.hhmm($0) } == ["08:00", "14:00", "20:00", "02:00", "08:00", "14:00", "20:00", "02:00"])
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == 8)
    }

    @Test("N = 1: uno por día, 64 días seguidos")
    func onePerDayFillsSixtyFourDays() {
        let dates = Self.upcoming("2026-07-25T09:00", Self.eight, Self.twentyTwo, 1, limit: 64)
        #expect(dates.count == 64)
        #expect(dates.first == Self.dt("2026-07-26T08:00"))
        let days = dates.map { Self.calendar.startOfDay(for: $0) }
        #expect(Set(days).count == 64)
        for (a, b) in zip(days, days.dropFirst()) {
            #expect(Self.calendar.dateComponents([.day], from: a, to: b).day == 1)
        }
    }

    @Test("N = 10: el tope de 64 cubre días completos en orden y termina con un día parcial")
    func tenPerDayBudgetAcrossDays() {
        // 12:00 → today keeps the 7 slots from 12:40 on; then 5 full days (50) and 7 more.
        let dates = Self.upcoming("2026-07-25T12:00", Self.eight, Self.twentyTwo, 10, limit: 64)
        #expect(dates.count == 64)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == 64)
        #expect(Self.hhmm(dates[0]) == "12:40")

        let perDay = Dictionary(grouping: dates) { Self.calendar.startOfDay(for: $0) }
            .sorted { $0.key < $1.key }
            .map(\.value.count)
        #expect(perDay == [7, 10, 10, 10, 10, 10, 7])

        // Every booked time is one of the day's ten slots, inside the window.
        let slots = Set(QuoteNotificationSlotCalculator.slotsFor(startMinute: Self.eight, endMinute: Self.twentyTwo, timesPerDay: 10))
        for date in dates {
            let c = Self.calendar.dateComponents([.hour, .minute], from: date)
            #expect(slots.contains(c.hour! * 60 + c.minute!))
        }
    }

    @Test("el tope se respeta con cualquier límite, y 0 no programa nada", arguments: [0, 1, 13, 50, 64])
    func limitIsHonoured(limit: Int) {
        let dates = Self.upcoming("2026-07-25T12:00", Self.eight, Self.twentyTwo, 10, limit: limit)
        #expect(dates.count == limit)
    }

    @Test("cambio de horario: 22–02 la noche que se adelanta el reloj no rompe el orden")
    func daylightSavingNight() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 2026-03-08 02:00 does not exist in New York: clocks jump to 03:00.
        let dates = QuoteNotificationSlotCalculator.upcomingSlots(
            from: Self.dt("2026-03-07T21:00", calendar: newYork),
            startMinute: Self.twentyTwo, endMinute: Self.two, timesPerDay: 3,
            limit: 6, calendar: newYork
        )
        #expect(dates.count == 6)
        #expect(dates == dates.sorted())
        #expect(dates.map { Self.hhmm($0, calendar: newYork) } == ["22:00", "00:00", "03:00", "22:00", "00:00", "02:00"])
    }

    // MARK: - Budget shared with habit reminders

    @Test("las frases usan lo que dejan libre los recordatorios de hábitos", arguments: [
        (0, 64), (7, 57), (21, 43), (64, 0), (80, 0),
    ])
    func budget(otherPending: Int, expected: Int) {
        #expect(NotificationScheduler.quoteBudget(otherPendingCount: otherPending) == expected)
    }

    @Test("sólo se reconocen como frases los ids de frases, también los del formato viejo", arguments: [
        ("quote_20260725_2200", true),
        ("quote_0_8h0m", true),
        ("habit_ABC_wd2", false),
        ("test_notification_0", false),
    ])
    func quoteIdentifiers(identifier: String, isQuote: Bool) {
        #expect(NotificationScheduler.isQuoteRequest(identifier: identifier) == isQuote)
    }

    @Test("el id de una frase es único por minuto de reloj")
    func identifierFormat() {
        let comps = DateComponents(year: 2026, month: 7, day: 5, hour: 0, minute: 7)
        #expect(NotificationScheduler.identifier(for: comps) == "quote_20260705_0007")
    }
}
