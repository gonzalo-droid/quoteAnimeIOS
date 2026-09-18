import Foundation
@testable import quoteAnime

/// Records every event instead of sending it to Firebase. Because `RoutineAnalytics` has a single
/// `log(_:)` requirement, what lands here is the exact name and parameters production would send.
final class FakeRoutineAnalytics: RoutineAnalytics {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    var names: [String] { events.map(\.name) }

    func events(named name: String) -> [AnalyticsEvent] {
        events.filter { $0.name == name }
    }
}
