import Foundation

public enum PrintContentType: String, CaseIterable, Codable, Sendable {
    case pdf
    case image
    case document
    case label
    case receipt
}

public enum PrintJobStatus: String, Codable, Sendable {
    case received
    case awaitingConfirmation
    case printing
    case succeeded
    case failed
    case cancelled
}

public struct PrintJob: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let contentType: PrintContentType
    public let printerName: String
    public let fileURL: URL?
    public var status: PrintJobStatus
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        contentType: PrintContentType,
        printerName: String,
        fileURL: URL? = nil,
        status: PrintJobStatus = .received,
        failureReason: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.printerName = printerName
        self.fileURL = fileURL
        self.status = status
        self.failureReason = failureReason
    }

    public func validationError(availablePrinters: [String]) -> String? {
        guard availablePrinters.contains(printerName) else {
            return "所选打印机不可用。"
        }
        if let fileURL, !FileManager.default.fileExists(atPath: fileURL.path) {
            return "找不到本地打印文件。"
        }
        return nil
    }

    public var canPreview: Bool {
        fileURL != nil
    }
}
