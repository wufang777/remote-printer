import Foundation

public final class SimulatedTransport {
    public private(set) var acknowledgements: [PrintJob] = []

    public init() {}

    public func createJob(contentType: PrintContentType, printerName: String) -> PrintJob {
        PrintJob(contentType: contentType, printerName: printerName)
    }

    public func acknowledge(_ job: PrintJob) {
        acknowledgements.append(job)
    }
}
