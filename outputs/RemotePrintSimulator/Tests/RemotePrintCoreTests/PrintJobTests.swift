import XCTest
import Foundation
@testable import RemotePrintCore

final class PrintJobTests: XCTestCase {
    func testValidationRejectsAnUnavailablePrinter() {
        let job = PrintJob(contentType: .pdf, printerName: "Warehouse")

        XCTAssertEqual(
            job.validationError(availablePrinters: ["Office"]),
            "所选打印机不可用。"
        )
    }

    func testValidationAcceptsAnAvailablePrinter() {
        let job = PrintJob(contentType: .receipt, printerName: "Office")

        XCTAssertNil(job.validationError(availablePrinters: ["Office"]))
    }

    func testNewJobStartsReceived() {
        let job = PrintJob(contentType: .label, printerName: "Office")

        XCTAssertEqual(job.status, .received)
        XCTAssertNil(job.failureReason)
    }

    func testDownloadedFileJobCanBePreviewed() {
        let job = PrintJob(
            contentType: .pdf,
            printerName: "Office",
            fileURL: URL(fileURLWithPath: "/private/tmp/order.pdf")
        )

        XCTAssertTrue(job.canPreview)
    }

    func testTransportCreatesAReceivedJob() {
        let transport = SimulatedTransport()

        let job = transport.createJob(contentType: .image, printerName: "Office")

        XCTAssertEqual(job.contentType, .image)
        XCTAssertEqual(job.printerName, "Office")
        XCTAssertEqual(job.status, .received)
    }

    func testTransportRetainsAcknowledgedJob() {
        let transport = SimulatedTransport()
        var job = transport.createJob(contentType: .receipt, printerName: "Office")
        job.status = .succeeded

        transport.acknowledge(job)

        XCTAssertEqual(transport.acknowledgements, [job])
    }
}
