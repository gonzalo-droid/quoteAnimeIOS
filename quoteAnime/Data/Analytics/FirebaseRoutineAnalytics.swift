import Foundation
import FirebaseAnalytics

/// Sends "Mi Rutina" events to Firebase Analytics — Android's `RoutineAnalytics` class, which calls
/// `FirebaseAnalytics.logEvent` directly. To watch them arrive, launch with `-FIRDebugEnabled`
/// (DebugView in the console, and `Logging event:` lines in the device log).
struct FirebaseRoutineAnalytics: RoutineAnalytics {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(
            event.name,
            parameters: event.parameters.isEmpty ? nil : event.parameters.mapValues(\.firebaseValue)
        )
    }
}

private extension AnalyticsValue {
    var firebaseValue: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return NSNumber(value: value)
        case .bool(let value): return NSNumber(value: value)
        }
    }
}
