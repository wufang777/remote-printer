import CryptoKit
import Foundation
import XCTest
@testable import RemotePrintCore

final class RemotePrintFileValidatorTests: XCTestCase {
    func testMatchingPDFChecksumIsAccepted() throws {
        let data = Data("remote PDF".utf8)
        let file = try temporaryFile(named: "order.pdf", contents: data)

        XCTAssertNoThrow(try RemotePrintFileValidator.validate(
            downloadedFile: file,
            expectedSHA256: checksum(for: data),
            contentType: .pdf
        ))
    }

    func testChecksumMismatchIsRejected() throws {
        let file = try temporaryFile(named: "order.pdf", contents: Data("remote PDF".utf8))

        XCTAssertThrowsError(try RemotePrintFileValidator.validate(
            downloadedFile: file,
            expectedSHA256: String(repeating: "0", count: 64),
            contentType: .pdf
        )) { error in
            XCTAssertEqual(error as? RemotePrintValidationError, .checksumMismatch)
        }
    }

    func testImageTaskRejectsPDFFile() throws {
        let data = Data("remote PDF".utf8)
        let file = try temporaryFile(named: "order.pdf", contents: data)

        XCTAssertThrowsError(try RemotePrintFileValidator.validate(
            downloadedFile: file,
            expectedSHA256: checksum(for: data),
            contentType: .image
        )) { error in
            XCTAssertEqual(error as? RemotePrintValidationError, .unsupportedFile)
        }
    }

    func testOfficeTaskAcceptsDOCXFile() throws {
        let data = Data("remote office".utf8)
        let file = try temporaryFile(named: "quote.docx", contents: data)

        XCTAssertNoThrow(try RemotePrintFileValidator.validate(
            downloadedFile: file,
            expectedSHA256: checksum(for: data),
            contentType: .office
        ))
    }

    private func temporaryFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        try contents.write(to: file)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return file
    }

    private func checksum(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
