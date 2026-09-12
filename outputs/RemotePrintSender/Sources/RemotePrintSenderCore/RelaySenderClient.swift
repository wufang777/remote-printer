import Foundation

public enum RelaySenderError: LocalizedError, Equatable {
    case invalidRelayURL
    case invalidResponse
    case server(String)
    case unsupportedFile
    case fileTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRelayURL: return "发送端只能连接本机中转站 127.0.0.1:17880。"
        case .invalidResponse: return "中转站返回的数据无效。"
        case .server(let message): return message
        case .unsupportedFile: return "仅支持 PDF、图片、Office 或 WPS 文档。"
        case .fileTooLarge: return "单个文件不能超过 25 MB。"
        }
    }
}

public struct RelayDevice: Codable, Identifiable, Equatable, Sendable {
    public let deviceId: String
    public let deviceName: String
    public var id: String { deviceId }
}

public struct RelayPrinter: Codable, Identifiable, Equatable, Sendable {
    public let name: String
    public let isOnline: Bool
    public let isDefault: Bool
    public var id: String { name }
}

public struct SenderJob: Codable, Equatable, Sendable {
    public let taskId: String
    public let status: String
}

public final class RelaySenderClient: Sendable {
    public static let supportedFileExtensions: Set<String> = ["pdf", "jpg", "jpeg", "png", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "wps", "et", "dps"]
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:17880")!, session: URLSession = .shared) throws {
        guard baseURL.scheme == "http", baseURL.host == "127.0.0.1", baseURL.port == 17880 else {
            throw RelaySenderError.invalidRelayURL
        }
        self.baseURL = baseURL
        self.session = session
    }

    public func loadDevices() async throws -> [RelayDevice] {
        try await get(path: "/sender/devices", key: "devices")
    }

    public func loadPrinters(deviceID: String) async throws -> [RelayPrinter] {
        try await get(path: "/sender/devices/\(deviceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? deviceID)/printers", key: "printers")
    }

    public func send(fileURL: URL, deviceID: String, printerName: String) async throws -> SenderJob {
        let extensionName = fileURL.pathExtension.lowercased()
        guard Self.supports(fileExtension: extensionName) else { throw RelaySenderError.unsupportedFile }
        let fileData = try Data(contentsOf: fileURL)
        guard fileData.count <= 25 * 1024 * 1024 else { throw RelaySenderError.fileTooLarge }

        let boundary = "RemotePrintSender-\(UUID().uuidString)"
        var body = Data()
        appendField("deviceId", value: deviceID, boundary: boundary, to: &body)
        appendField("printerName", value: printerName, boundary: boundary, to: &body)
        appendField("copies", value: "1", boundary: boundary, to: &body)
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: \(mimeType(for: extensionName))\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: baseURL.appending(path: "/sender/jobs"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SenderJob.self, from: data)
    }

    public static func supports(fileExtension: String) -> Bool {
        supportedFileExtensions.contains(fileExtension.lowercased())
    }

    public func job(taskID: String) async throws -> SenderJob {
        let encoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        let request = URLRequest(url: baseURL.appending(path: "/sender/jobs/\(encoded)"))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SenderJob.self, from: data)
    }

    private func get<T: Decodable>(path: String, key: String) async throws -> [T] {
        let request = URLRequest(url: baseURL.appending(path: path))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ResponseList<T>.self, from: data).items(for: key)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else { throw RelaySenderError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(RelayErrorResponse.self, from: data))?.error.message ?? "中转站请求失败（\(response.statusCode)）。"
            throw RelaySenderError.server(message)
        }
    }
}

private struct ResponseList<T: Decodable>: Decodable {
    let devices: [T]?
    let printers: [T]?
    func items(for key: String) -> [T] { key == "devices" ? devices ?? [] : printers ?? [] }
}

private struct RelayErrorResponse: Decodable { let error: RelayError }
private struct RelayError: Decodable { let message: String }

private func appendField(_ name: String, value: String, boundary: String, to data: inout Data) {
    data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
}

private func mimeType(for fileExtension: String) -> String {
    switch fileExtension {
    case "pdf": return "application/pdf"
    case "png": return "image/png"
    case "doc": return "application/msword"
    case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "xls": return "application/vnd.ms-excel"
    case "csv": return "text/csv"
    case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    case "ppt": return "application/vnd.ms-powerpoint"
    case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    default: return "application/octet-stream"
    }
}
