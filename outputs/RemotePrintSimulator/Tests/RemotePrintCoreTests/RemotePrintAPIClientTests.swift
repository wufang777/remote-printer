import Foundation
import XCTest
@testable import RemotePrintCore

final class RemotePrintAPIClientTests: XCTestCase {
    func testRegisterPostsActivationCodeAndDecodesCredentials() async throws {
        let recorder = RequestRecorder(responseBody: """
        {"deviceId":"dev_123","accessToken":"token_123","expiresAt":"2030-01-01T00:00:00Z","pollIntervalSeconds":10}
        """)
        let client = RemotePrintAPIClient(session: recorder.session)
        let configuration = ConnectionConfiguration(apiBaseURL: "https://print.example.com/v1", deviceName: "测试 Mac", activationCode: "RP-001")

        let response = try await client.register(configuration: configuration, appVersion: "0.3.0", osVersion: "14.0")

        XCTAssertEqual(response.credentials.deviceID, "dev_123")
        XCTAssertEqual(response.pollIntervalSeconds, 10)
        let request = try XCTUnwrap(recorder.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/devices/register")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), nil)
    }

    func testClaimUsesBearerTokenAndDecodesJob() async throws {
        let recorder = RequestRecorder(responseBody: """
        {"jobs":[{"taskId":"print_1","printerName":"办公室","contentType":"pdf","file":{"downloadUrl":"https://files.example.com/a.pdf","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","fileName":"a.pdf","expiresAt":"2030-01-01T00:00:00Z"}}]}
        """)
        let client = RemotePrintAPIClient(session: recorder.session)

        let jobs = try await client.claimJobs(baseURL: URL(string: "https://print.example.com/v1")!, deviceID: "dev_123", token: "token_123", printers: ["办公室"])

        XCTAssertEqual(jobs.first?.taskID, "print_1")
        let request = try XCTUnwrap(recorder.request)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token_123")
        XCTAssertEqual(request.url?.path, "/v1/devices/dev_123/print-jobs:claim")
    }

    func testSyncAndEventUseAuthenticatedEndpoints() async throws {
        let recorder = RequestRecorder(responseBody: "{}", statusCode: 204)
        let client = RemotePrintAPIClient(session: recorder.session)
        let baseURL = URL(string: "https://print.example.com/v1")!

        try await client.syncPrinters(baseURL: baseURL, deviceID: "dev_123", token: "token_123", printers: ["办公室"])
        XCTAssertEqual(recorder.request?.httpMethod, "PUT")
        XCTAssertEqual(recorder.request?.url?.path, "/v1/devices/dev_123/printers")

        try await client.postEvent(baseURL: baseURL, deviceID: "dev_123", token: "token_123", taskID: "print_1", event: RemotePrintEvent(status: .printing))
        XCTAssertEqual(recorder.request?.httpMethod, "POST")
        XCTAssertEqual(recorder.request?.url?.path, "/v1/devices/dev_123/print-jobs/print_1/events")
        XCTAssertEqual(recorder.request?.value(forHTTPHeaderField: "Authorization"), "Bearer token_123")
    }

    func testDownloadWritesSignedHTTPSContentIntoCache() async throws {
        let recorder = RequestRecorder(responseBody: "remote file")
        let client = RemotePrintAPIClient(session: recorder.session)
        let cache = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: cache) }

        let file = try await client.download(url: URL(string: "https://files.example.com/order.pdf")!, fileName: "order.pdf", cacheDirectory: cache)

        XCTAssertEqual(try Data(contentsOf: file), Data("remote file".utf8))
        XCTAssertEqual(recorder.request?.value(forHTTPHeaderField: "Authorization"), nil)
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let responseBody: String
    private let statusCode: Int
    private let lock = NSLock()
    private var capturedRequest: URLRequest?
    var request: URLRequest? { lock.lock(); defer { lock.unlock() }; return capturedRequest }
    init(responseBody: String, statusCode: Int = 200) { self.responseBody = responseBody; self.statusCode = statusCode }
    var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { [weak self] request in
            self?.lock.lock(); self?.capturedRequest = request; self?.lock.unlock()
            let body = self?.responseBody ?? "{}"
            return (HTTPURLResponse(url: request.url!, statusCode: self?.statusCode ?? 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data(body.utf8))
        }
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { guard let handler = Self.handler else { return }; let (response, data) = handler(request); client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self) }
    override func stopLoading() {}
}
