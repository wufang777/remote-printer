import Foundation
import XCTest
@testable import RemotePrintCore

@MainActor
final class AppStateTests: XCTestCase {
    @MainActor
    func testStateChangeCallbackReceivesApprovedJob() {
        let state = AppState(printerCatalog: StubPrinterCatalog(names: ["办公室"])); state.behavior = .confirm
        var statuses: [PrintJobStatus] = []
        state.onJobUpdated = { statuses.append($0.status) }
        state.receive(PrintJob(contentType: .pdf, printerName: "办公室"))

        _ = state.approve(jobID: try! XCTUnwrap(state.jobs.first?.id))

        XCTAssertEqual(statuses, [.awaitingConfirmation, .succeeded])
    }
    func testSilentJobCompletesImmediately() {
        let state = AppState(printerCatalog: StubPrinterCatalog(names: ["Office"]))
        state.behavior = .silent

        state.receive(PrintJob(contentType: .label, printerName: "Office"))

        XCTAssertEqual(state.jobs.first?.status, .succeeded)
    }

    func testConfirmationModeWaitsForApproval() {
        let state = AppState(printerCatalog: StubPrinterCatalog(names: ["Office"]))

        state.receive(PrintJob(contentType: .pdf, printerName: "Office"))

        XCTAssertEqual(state.jobs.first?.status, .awaitingConfirmation)
    }

    func testUnavailablePrinterFailsTheJob() {
        let state = AppState(printerCatalog: StubPrinterCatalog(names: ["Office"]))

        state.receive(PrintJob(contentType: .image, printerName: "Warehouse"))

        XCTAssertEqual(state.jobs.first?.status, .failed)
        XCTAssertEqual(state.jobs.first?.failureReason, "所选打印机不可用。")
    }

    func testLocalFileThatDoesNotExistFailsBeforePrinting() {
        let state = AppState(printerCatalog: StubPrinterCatalog(names: ["Office"]))
        state.behavior = .silent
        let missingFile = URL(fileURLWithPath: "/private/tmp/no-such-print-file.pdf")

        state.receive(PrintJob(contentType: .pdf, printerName: "Office", fileURL: missingFile))

        XCTAssertEqual(state.jobs.first?.status, .failed)
        XCTAssertEqual(state.jobs.first?.failureReason, "找不到本地打印文件。")
    }
}

private struct StubPrinterCatalog: PrinterCatalog {
    let names: [String]

    func printerNames() -> [String] { names }
}
