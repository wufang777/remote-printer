import Foundation

public struct DeviceRegistrationResponse: Equatable, Sendable {
    public let credentials: DeviceCredentials
    public let pollIntervalSeconds: Int
}

public enum RemotePrintAPIError: Error, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case insecureURL
}

public final class RemotePrintAPIClient: @unchecked Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func register(configuration: ConnectionConfiguration, appVersion: String, osVersion: String) async throws -> DeviceRegistrationResponse {
        guard let baseURL = URL(string: configuration.apiBaseURL), baseURL.scheme == "https" || isLocalRelayURL(baseURL) else { throw RemotePrintAPIError.insecureURL }
        let body = RegisterRequest(activationCode: configuration.activationCode, deviceName: configuration.deviceName, platform: "macOS", appVersion: appVersion, osVersion: osVersion)
        let response: RegisterResponse = try await send(url: baseURL.appending(path: "devices/register"), method: "POST", body: body, token: nil)
        return DeviceRegistrationResponse(credentials: DeviceCredentials(deviceID: response.deviceID, accessToken: response.accessToken, expiresAt: response.expiresAt), pollIntervalSeconds: max(10, response.pollIntervalSeconds))
    }

    public func claimJobs(baseURL: URL, deviceID: String, token: String, printers: [String]) async throws -> [RemotePrintJob] {
        guard baseURL.scheme == "https" || isLocalRelayURL(baseURL) else { throw RemotePrintAPIError.insecureURL }
        let response: ClaimResponse = try await send(url: baseURL.appending(path: "devices/\(deviceID)/print-jobs:claim"), method: "POST", body: ClaimRequest(maxJobs: 5, supportedFormats: ["pdf", "image", "office", "wps"], availablePrinters: printers), token: token)
        return response.jobs
    }

    public func syncPrinters(baseURL: URL, deviceID: String, token: String, printers: [String]) async throws {
        guard baseURL.scheme == "https" || isLocalRelayURL(baseURL) else { throw RemotePrintAPIError.insecureURL }
        let entries = printers.map { PrinterEntry(name: $0, isDefault: $0 == printers.first, isOnline: true) }
        try await sendNoContent(url: baseURL.appending(path: "devices/\(deviceID)/printers"), method: "PUT", body: PrinterList(printers: entries), token: token)
    }

    public func postEvent(baseURL: URL, deviceID: String, token: String, taskID: String, event: RemotePrintEvent) async throws {
        guard baseURL.scheme == "https" || isLocalRelayURL(baseURL) else { throw RemotePrintAPIError.insecureURL }
        try await sendNoContent(url: baseURL.appending(path: "devices/\(deviceID)/print-jobs/\(taskID)/events"), method: "POST", body: event, token: token)
    }

    public func download(url: URL, fileName: String, cacheDirectory: URL) async throws -> URL {
        guard (url.scheme == "https" || isLocalRelayURL(url)), !fileName.isEmpty, !fileName.contains("/") else { throw RemotePrintAPIError.insecureURL }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { throw RemotePrintAPIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode), data.count <= 25 * 1024 * 1024 else { throw RemotePrintAPIError.httpStatus(httpResponse.statusCode) }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let destination = cacheDirectory.appending(path: "\(UUID().uuidString)-\(fileName)")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func send<Request: Encodable, Response: Decodable>(url: URL, method: String, body: Request, token: String?) async throws -> Response {
        let request = try makeRequest(url: url, method: method, body: body, token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw RemotePrintAPIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw RemotePrintAPIError.httpStatus(httpResponse.statusCode) }
        return try decoder.decode(Response.self, from: data)
    }

    private func sendNoContent<Request: Encodable>(url: URL, method: String, body: Request, token: String?) async throws {
        let request = try makeRequest(url: url, method: method, body: body, token: token)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw RemotePrintAPIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw RemotePrintAPIError.httpStatus(httpResponse.statusCode) }
    }

    private func makeRequest<Request: Encodable>(url: URL, method: String, body: Request, token: String?) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try encoder.encode(body)
        return request
    }
}

private struct RegisterRequest: Encodable { let activationCode: String; let deviceName: String; let platform: String; let appVersion: String; let osVersion: String }
private struct RegisterResponse: Decodable { let deviceID: String; let accessToken: String; let expiresAt: Date; let pollIntervalSeconds: Int; enum CodingKeys: String, CodingKey { case deviceID = "deviceId", accessToken, expiresAt, pollIntervalSeconds } }
private struct ClaimRequest: Encodable { let maxJobs: Int; let supportedFormats: [String]; let availablePrinters: [String] }
private struct ClaimResponse: Decodable { let jobs: [RemotePrintJob] }
private struct PrinterList: Encodable { let printers: [PrinterEntry] }
private struct PrinterEntry: Encodable { let name: String; let isDefault: Bool; let isOnline: Bool }
