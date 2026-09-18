import Foundation
@testable import quoteAnime

/// Records what the app asked `BGTaskScheduler` for. The real scheduler does nothing useful in a
/// test host, so `QuoteNotificationBackgroundRefresh` is tested through `AppRefreshScheduling`.
final class FakeAppRefreshScheduler: AppRefreshScheduling {
    struct Submission: Equatable {
        let identifier: String
        let earliestBeginDate: Date
    }

    struct Refused: Error {}

    private(set) var submissions: [Submission] = []
    private(set) var cancelledIdentifiers: [String] = []
    /// When true, `submit` throws like `BGTaskScheduler` does with Background App Refresh off.
    var refuses = false

    func submit(identifier: String, earliestBeginDate: Date) throws {
        if refuses { throw Refused() }
        submissions.append(Submission(identifier: identifier, earliestBeginDate: earliestBeginDate))
    }

    func cancel(identifier: String) {
        cancelledIdentifiers.append(identifier)
    }
}
