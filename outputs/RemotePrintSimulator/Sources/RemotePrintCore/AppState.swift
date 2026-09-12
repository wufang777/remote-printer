import Combine
import Foundation

public enum PrintBehavior: String, CaseIterable, Sendable {
    case confirm
    case silent
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var jobs: [PrintJob] = []
    @Published public var behavior: PrintBehavior = .confirm
    public var onJobUpdated: ((PrintJob) -> Void)?

    private let printerCatalog: any PrinterCatalog
    private let transport: SimulatedTransport

    public init(
        printerCatalog: any PrinterCatalog,
        transport: SimulatedTransport = SimulatedTransport()
    ) {
        self.printerCatalog = printerCatalog
        self.transport = transport
    }

    public var availablePrinters: [String] {
        printerCatalog.printerNames()
    }

    @discardableResult
    public func receive(_ job: PrintJob) -> PrintJob? {
        var updatedJob = job
        if let error = job.validationError(availablePrinters: availablePrinters) {
            updatedJob.status = .failed
            updatedJob.failureReason = error
        } else if behavior == .confirm {
            updatedJob.status = .awaitingConfirmation
        } else {
            updatedJob.status = .printing
            if updatedJob.fileURL == nil {
                updatedJob.status = .succeeded
            }
        }
        jobs.insert(updatedJob, at: 0)
        transport.acknowledge(updatedJob)
        onJobUpdated?(updatedJob)
        return updatedJob.fileURL != nil && updatedJob.status == .printing ? updatedJob : nil
    }

    @discardableResult
    public func approve(jobID: UUID) -> PrintJob? {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return nil }
        if job.fileURL != nil {
            update(jobID: jobID, status: .printing)
            return jobs.first(where: { $0.id == jobID })
        }
        update(jobID: jobID, status: .succeeded)
        return nil
    }

    public func cancel(jobID: UUID) {
        update(jobID: jobID, status: .cancelled)
    }

    public func complete(jobID: UUID) {
        update(jobID: jobID, status: .succeeded)
    }

    public func fail(jobID: UUID, reason: String) {
        update(jobID: jobID, status: .failed, reason: reason)
    }

    private func update(jobID: UUID, status: PrintJobStatus, reason: String? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].status = status
        jobs[index].failureReason = status == .failed ? reason : nil
        transport.acknowledge(jobs[index])
        onJobUpdated?(jobs[index])
    }
}
