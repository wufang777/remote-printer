import Combine
import Foundation

public enum RemoteConnectionState: Equatable, Sendable { case disconnected, connecting, connected, retrying }

public enum RemotePollSchedule {
    public static func delay(afterFailureCount count: Int) -> Int {
        min(60, 10 * (1 << min(max(0, count - 1), 3)))
    }
}

@MainActor
public final class RemotePrintCoordinator: ObservableObject {
    @Published public private(set) var connectionState: RemoteConnectionState = .disconnected
    private let api: RemotePrintAPIClient
    private let credentials: any DeviceCredentialStoring
    private var loopTask: Task<Void, Never>?
    private var remoteJobs: [UUID: RemoteJobRoute] = [:]

    public init(api: RemotePrintAPIClient = RemotePrintAPIClient(), credentials: any DeviceCredentialStoring = KeychainCredentialStore()) {
        self.api = api
        self.credentials = credentials
    }

    public func start(configuration: ConnectionConfiguration, state: AppState) {
        stop()
        guard configuration.validationError == nil, let baseURL = URL(string: configuration.apiBaseURL) else { return }
        connectionState = .connecting
        state.onJobUpdated = { [weak self] job in self?.report(job) }
        loopTask = Task { [weak self, weak state] in
            guard let self, let state else { return }
            var failures = 0
            while !Task.isCancelled {
                do {
                    let credential = try await self.validCredentials(configuration: configuration)
                    try await self.api.syncPrinters(baseURL: baseURL, deviceID: credential.deviceID, token: credential.accessToken, printers: state.availablePrinters)
                    let jobs = try await self.api.claimJobs(baseURL: baseURL, deviceID: credential.deviceID, token: credential.accessToken, printers: state.availablePrinters)
                    for remote in jobs { await self.receive(remote, baseURL: baseURL, credential: credential, state: state) }
                    failures = 0
                    self.connectionState = .connected
                    let interval = min(60, max(1, UserDefaults.standard.integer(forKey: "remotePrint.pollIntervalSeconds") == 0 ? 1 : UserDefaults.standard.integer(forKey: "remotePrint.pollIntervalSeconds")))
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    failures += 1
                    self.connectionState = .retrying
                    try? await Task.sleep(for: .seconds(RemotePollSchedule.delay(afterFailureCount: failures)))
                }
            }
        }
    }

    public func stop() { loopTask?.cancel(); loopTask = nil; connectionState = .disconnected }

    private func validCredentials(configuration: ConnectionConfiguration) async throws -> DeviceCredentials {
        if let stored = try credentials.load(), !stored.isExpired { return stored }
        let registered = try await api.register(configuration: configuration, appVersion: "0.3.0", osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
        try credentials.save(registered.credentials)
        return registered.credentials
    }

    private func receive(_ remote: RemotePrintJob, baseURL: URL, credential: DeviceCredentials, state: AppState) async {
        do {
            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "RemotePrintJobs", directoryHint: .isDirectory)
            let file = try await api.download(url: remote.file.downloadURL, fileName: remote.file.fileName, cacheDirectory: cache)
            _ = try RemotePrintFileValidator.validate(downloadedFile: file, expectedSHA256: remote.file.sha256, contentType: remote.contentType)
            _ = state.receive(PrintJob(contentType: remote.contentType.printContentType, printerName: remote.printerName, fileURL: file))
            guard let job = state.jobs.first else { return }
            remoteJobs[job.id] = RemoteJobRoute(taskID: remote.taskID, baseURL: baseURL, credentials: credential)
            try? await api.postEvent(baseURL: baseURL, deviceID: credential.deviceID, token: credential.accessToken, taskID: remote.taskID, event: RemotePrintEvent(status: eventStatus(for: job.status)))
        } catch {
            try? await api.postEvent(baseURL: baseURL, deviceID: credential.deviceID, token: credential.accessToken, taskID: remote.taskID, event: RemotePrintEvent(status: .failed, error: RemotePrintEventError(code: .downloadFailed, message: "远程文件下载或校验失败。", retryable: true)))
        }
    }

    private func report(_ job: PrintJob) {
        guard let route = remoteJobs[job.id] else { return }
        Task { [weak self] in
            guard let self else { return }
            try? await self.api.postEvent(baseURL: route.baseURL, deviceID: route.credentials.deviceID, token: route.credentials.accessToken, taskID: route.taskID, event: RemotePrintEvent(status: self.eventStatus(for: job.status)))
            if job.status == .succeeded || job.status == .failed || job.status == .cancelled { self.remoteJobs[job.id] = nil }
        }
    }

    private func eventStatus(for status: PrintJobStatus) -> RemotePrintEventStatus {
        switch status { case .received: .received; case .awaitingConfirmation: .awaitingConfirmation; case .printing: .printing; case .succeeded: .succeeded; case .failed: .failed; case .cancelled: .cancelled }
    }
}

private struct RemoteJobRoute: Sendable { let taskID: String; let baseURL: URL; let credentials: DeviceCredentials }
