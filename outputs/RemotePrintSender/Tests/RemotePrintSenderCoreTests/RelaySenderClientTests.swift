import XCTest
@testable import RemotePrintSenderCore

final class RelaySenderClientTests: XCTestCase {
    func testRejectsNonLoopbackRelayURL() {
        XCTAssertThrowsError(try RelaySenderClient(baseURL: URL(string: "http://192.168.1.2:17880")!))
    }

    func testAcceptsExactLocalRelayURL() throws {
        XCTAssertNoThrow(try RelaySenderClient(baseURL: URL(string: "http://127.0.0.1:17880")!))
    }

    func testSupportsOfficeAndWPSFileExtensions() {
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "docx"))
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "xlsx"))
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "pptx"))
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "wps"))
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "et"))
        XCTAssertTrue(RelaySenderClient.supports(fileExtension: "dps"))
    }
}
