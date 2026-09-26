import Foundation
import XCTest
@testable import LifeOSKit

final class FetchPlanTests: XCTestCase {
    actor Log {
        private(set) var events: [String] = []
        func add(_ event: String) { events.append(event) }
    }

    func testAPushFetchesAtOnceAndAgainAfterThreeSeconds() async {
        let log = Log()
        await FetchPlan.run(.push, sleep: { seconds in await log.add("sleep \(seconds)") }) {
            await log.add("fetch")
        }
        let events = await log.events
        XCTAssertEqual(events, ["fetch", "sleep 3.0", "fetch"])
    }

    func testForegroundFetchesOnceWithoutWaiting() async {
        let log = Log()
        await FetchPlan.run(.foreground, sleep: { seconds in await log.add("sleep \(seconds)") }) {
            await log.add("fetch")
        }
        let events = await log.events
        XCTAssertEqual(events, ["fetch"])
    }

    func testACancelledWaitSkipsTheSecondFetch() async {
        let log = Log()
        await FetchPlan.run(.push, sleep: { _ in throw CancellationError() }) {
            await log.add("fetch")
        }
        let events = await log.events
        XCTAssertEqual(events, ["fetch"])
    }

    func testTheRealSleepIsCancelledWithItsTask() async {
        let log = Log()
        let task = Task {
            await FetchPlan.run(.push) {
                await log.add("fetch")
            }
        }
        // Wait for the first fetch, then cancel during the three-second wait.
        while await log.events.isEmpty { await Task.yield() }
        task.cancel()
        await task.value
        let events = await log.events
        XCTAssertEqual(events, ["fetch"])
    }

    func testTheGaps() {
        XCTAssertEqual(FetchPlan.gaps(for: .push), [0, 3])
        XCTAssertEqual(FetchPlan.gaps(for: .foreground), [0])
        XCTAssertEqual(FetchPlan.pushRecheck, 3)
    }
}
