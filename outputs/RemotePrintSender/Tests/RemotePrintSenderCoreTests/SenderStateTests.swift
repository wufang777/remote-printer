import XCTest
@testable import RemotePrintSenderCore

@MainActor
final class SenderStateTests: XCTestCase {
    func testSenderStateDisablesSendWithoutFileAndPrinter() {
        let state = SenderState()
        XCTAssertFalse(state.canSend)
    }
}
