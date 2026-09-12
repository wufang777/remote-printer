import XCTest
@testable import RemotePrintCore

final class DocumentPrintStrategyTests: XCTestCase {
    func testDefaultDocumentStrategyIsAutomatic() {
        XCTAssertEqual(DocumentPrintStrategy.defaultValue, .automatic)
    }
}
