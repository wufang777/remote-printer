import Foundation

public enum RemoteContentType: String, Codable, Sendable {
    case pdf
    case image
    case office
    case wps

    public var printContentType: PrintContentType {
        switch self {
        case .pdf: return .pdf
        case .image: return .image
        case .office, .wps: return .document
        }
    }
}

public enum RemotePrintFailureCode: String, Codable, Sendable {
    case downloadFailed = "DOWNLOAD_FAILED"
    case checksumMismatch = "CHECKSUM_MISMATCH"
    case unsupportedFile = "UNSUPPORTED_FILE"
    case printerNotFound = "PRINTER_NOT_FOUND"
    case printFailed = "PRINT_FAILED"
    case userCancelled = "USER_CANCELLED"
}

public struct RemotePrintFile: Codable, Equatable, Sendable {
    public let downloadURL: URL
    public let sha256: String
    public let fileName: String
    public let expiresAt: Date

    enum CodingKeys: String, CodingKey { case downloadURL = "downloadUrl", sha256, fileName, expiresAt }
}

public struct RemotePrintJob: Codable, Equatable, Sendable {
    public let taskID: String
    public let printerName: String
    public let contentType: RemoteContentType
    public let file: RemotePrintFile

    enum CodingKeys: String, CodingKey { case taskID = "taskId", printerName, contentType, file }
}

public enum RemotePrintEventStatus: String, Codable, Sendable {
    case received
    case awaitingConfirmation = "awaiting_confirmation"
    case printing
    case succeeded
    case failed
    case cancelled
}

public struct RemotePrintEvent: Codable, Equatable, Sendable {
    public let status: RemotePrintEventStatus
    public let occurredAt: Date
    public let error: RemotePrintEventError?

    public init(status: RemotePrintEventStatus, occurredAt: Date = .now, error: RemotePrintEventError? = nil) {
        self.status = status
        self.occurredAt = occurredAt
        self.error = error
    }
}

public struct RemotePrintEventError: Codable, Equatable, Sendable {
    public let code: RemotePrintFailureCode
    public let message: String
    public let retryable: Bool
}
