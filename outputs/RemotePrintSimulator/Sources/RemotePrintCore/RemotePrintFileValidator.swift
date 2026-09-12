import CryptoKit
import Foundation

public enum RemotePrintValidationError: Error, Equatable, Sendable {
    case unsupportedFile
    case checksumMismatch
}

public enum RemotePrintFileValidator {
    public static func validate(downloadedFile: URL, expectedSHA256: String, contentType: RemoteContentType) throws -> URL {
        guard expectedSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw RemotePrintValidationError.checksumMismatch
        }
        let extensionName = downloadedFile.pathExtension.lowercased()
        let isSupported = switch contentType {
        case .pdf: extensionName == "pdf"
        case .image: ["jpg", "jpeg", "png"].contains(extensionName)
        case .office: ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv"].contains(extensionName)
        case .wps: ["wps", "et", "dps"].contains(extensionName)
        }
        guard isSupported else { throw RemotePrintValidationError.unsupportedFile }

        let data = try Data(contentsOf: downloadedFile)
        let actualChecksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actualChecksum == expectedSHA256 else { throw RemotePrintValidationError.checksumMismatch }
        return downloadedFile
    }
}
