import Foundation
import Testing
@testable import quoteAnime

/// Behaviour is pinned against Android's `CalculateStreakUseCase.kt`: dedupe, sort
/// descending, a streak stays alive while the newest completion is today or yesterday,
/// `best` is the longest consecutive run anywhere in the history.
@Suite("CalculateStreakUseCase")
struct CalculateStreakUseCaseTests {

    private let useCase = CalculateStreakUseCase(calendar: TestCalendar.fixed)

    // MARK: - The date table

    static let scenarios: [StreakScenario] = [
        StreakScenario(
            label: "sin completions",
            dayOffsets: [],
            expectedCurrent: 0, expectedBest: 0, expectedCompletedToday: false
        ),
        StreakScenario(
            label: "solo hoy",
            dayOffsets: [0],
            expectedCurrent: 1, expectedBest: 1, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "solo ayer — la racha sigue viva",
            dayOffsets: [-1],
            expectedCurrent: 1, expectedBest: 1, expectedCompletedToday: false
        ),
        StreakScenario(
            label: "solo anteayer — la racha ya murió",
            dayOffsets: [-2],
            expectedCurrent: 0, expectedBest: 1, expectedCompletedToday: false
        ),
        StreakScenario(
            label: "tres consecutivos terminando hoy",
            dayOffsets: [0, -1, -2],
            expectedCurrent: 3, expectedBest: 3, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "tres consecutivos terminando ayer",
            dayOffsets: [-1, -2, -3],
            expectedCurrent: 3, expectedBest: 3, expectedCompletedToday: false
        ),
        StreakScenario(
            label: "hueco: la mejor racha es histórica, no la actual",
            dayOffsets: [0, -1, -4, -5, -6, -7],
            expectedCurrent: 2, expectedBest: 4, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "racha muerta pero con mejor histórica",
            dayOffsets: [-3, -4, -5],
            expectedCurrent: 0, expectedBest: 3, expectedCompletedToday: false
        ),
        StreakScenario(
            label: "hueco de un solo día corta la racha actual",
            dayOffsets: [0, -2],
            expectedCurrent: 1, expectedBest: 1, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "completions desordenadas",
            dayOffsets: [-2, 0, -1],
            expectedCurrent: 3, expectedBest: 3, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "completions duplicadas se deduplican",
            dayOffsets: [0, 0, -1, -1, -1],
            expectedCurrent: 2, expectedBest: 2, expectedCompletedToday: true
        ),
        StreakScenario(
            label: "racha larga de dos semanas",
            dayOffsets: Array(0...13).map { -$0 },
            expectedCurrent: 14, expectedBest: 14, expectedCompletedToday: true
        ),
    ]

    @Test("racha actual y mejor racha", arguments: scenarios)
    func streak(_ scenario: StreakScenario) {
        let state = useCase.execute(dates: scenario.dates, today: TestCalendar.today)

        #expect(state.current == scenario.expectedCurrent)
        #expect(state.best == scenario.expectedBest)
        #expect(state.completedToday == scenario.expectedCompletedToday)
    }

    @Test("lastCompletedDate es el día más reciente, normalizado a startOfDay")
    func lastCompletedDate() {
        let state = useCase.execute(
            dates: [TestCalendar.day(-5), TestCalendar.day(-1), TestCalendar.day(-3)],
            today: TestCalendar.today
        )

        #expect(state.lastCompletedDate == TestCalendar.fixed.startOfDay(for: TestCalendar.day(-1)))
    }

    @Test("sin completions no hay lastCompletedDate")
    func emptyHasNoLastDate() {
        let state = useCase.execute(dates: [], today: TestCalendar.today)

        #expect(state.lastCompletedDate == nil)
        #expect(state.current == 0)
        #expect(state.best == 0)
        #expect(state.completedToday == false)
    }

    // MARK: - Day boundaries
    //
    // Android receives `LocalDate`, so the timezone question is already settled before the
    // use case runs. iOS receives instants, so these cases only exist on this platform.

    @Test(
        "varias horas del mismo día cuentan como un solo día",
        arguments: [
            (0, 23, 59),   // just before midnight
            (0, 0, 0),     // exactly midnight
            (0, 12, 30),   // midday
        ]
    )
    func sameDayDifferentTimes(offset: Int, hour: Int, minute: Int) {
        let state = useCase.execute(
            dates: [TestCalendar.day(offset, hour: hour, minute: minute)],
            today: TestCalendar.today
        )

        #expect(state.current == 1)
        #expect(state.best == 1)
        #expect(state.completedToday == true)
    }

    @Test("tres marcas el mismo día colapsan a una racha de 1")
    func multipleTimesOneDayCollapse() {
        let state = useCase.execute(
            dates: [
                TestCalendar.day(0, hour: 0, minute: 1),
                TestCalendar.day(0, hour: 9),
                TestCalendar.day(0, hour: 23, minute: 59),
            ],
            today: TestCalendar.today
        )

        #expect(state.current == 1)
        #expect(state.best == 1)
    }

    @Test("23:59 de ayer y 00:01 de hoy son dos días consecutivos")
    func acrossMidnightIsTwoDays() {
        let state = useCase.execute(
            dates: [
                TestCalendar.day(-1, hour: 23, minute: 59),
                TestCalendar.day(0, hour: 0, minute: 1),
            ],
            today: TestCalendar.today
        )

        #expect(state.current == 2)
        #expect(state.best == 2)
        #expect(state.completedToday == true)
    }

    @Test("un `today` a cualquier hora del día da el mismo resultado")
    func todayTimeOfDayDoesNotMatter() {
        let dates = [TestCalendar.day(0), TestCalendar.day(-1)]

        let earlyMorning = useCase.execute(dates: dates, today: TestCalendar.day(0, hour: 0, minute: 5))
        let lateNight = useCase.execute(dates: dates, today: TestCalendar.day(0, hour: 23, minute: 55))

        #expect(earlyMorning == lateNight)
        #expect(earlyMorning.current == 2)
    }
}
