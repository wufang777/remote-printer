import Foundation
import XCTest
@testable import RemotePrintCore

final class DeviceCredentialTests: XCTestCase {
    func testInMemoryStoreReturnsSavedCredentials() throws {
        let store = InMemoryCredentialStore()
        let credentials = DeviceCredentials(deviceID: "device_1", accessToken: "private-token", expiresAt: .distantFuture)

        try store.save(credentials)

        XCTAssertEqual(try store.load(), credentials)
    }

    func testDeleteRemovesCredentials() throws {
        let store = InMemoryCredentialStore()
        try store.save(DeviceCredentials(deviceID: "device_1", accessToken: "private-token", expiresAt: .distantFuture))

        try store.delete()

        XCTAssertNil(try store.load())
    }
}
