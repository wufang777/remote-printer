import XCTest
@testable import RemotePrintCore

final class PreviewZoomTests: XCTestCase {
    func testZoomInAndOutStayWithinSupportedRange() {
        var zoom = PreviewZoom()

        zoom.zoomIn()
        XCTAssertEqual(zoom.scale, 1.25)

        for _ in 0..<20 { zoom.zoomOut() }
        XCTAssertEqual(zoom.scale, 0.25)
    }
}
