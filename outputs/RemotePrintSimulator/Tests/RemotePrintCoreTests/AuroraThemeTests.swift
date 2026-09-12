import XCTest
@testable import RemotePrintCore

final class AuroraThemeTests: XCTestCase {
    func testPrintingStatusUsesBlueAccent() {
        XCTAssertEqual(AuroraStatusColor.printing.rawValue, "#2675FF")
    }
}
