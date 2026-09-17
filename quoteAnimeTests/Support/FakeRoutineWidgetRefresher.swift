import Foundation
@testable import quoteAnime

/// Counts refreshes instead of writing into the real App Group. The production refresher reads
/// the habit store and calls `WidgetCenter`, neither of which a unit test should touch — and the
/// thing worth pinning is *that* a change asks the widgets to reload, which is what Android's
/// `RoutineWidgetScheduler.triggerImmediateUpdate()` guarantees on the other side.
final class FakeRoutineWidgetRefresher: RoutineWidgetRefreshing {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}
