import XCTest
@testable import RemotePrintCore

final class RemotePollScheduleTests: XCTestCase {
    func testRetryDelayDoublesAndCapsAtSixtySeconds() {
        XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 1), 10)
        XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 2), 20)
        XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 3), 40)
        XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 4), 60)
        XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 12), 60)
    }
}
