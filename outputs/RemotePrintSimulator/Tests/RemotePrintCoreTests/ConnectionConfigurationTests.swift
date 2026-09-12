import XCTest
@testable import RemotePrintCore

final class ConnectionConfigurationTests: XCTestCase {
    func testAcceptsAValidHTTPSConfiguration() {
        let configuration = ConnectionConfiguration(
            apiBaseURL: "https://api.example.com/v1",
            deviceName: "上海门店 Mac mini",
            activationCode: "RP-8F2K-91MZ"
        )

        XCTAssertNil(configuration.validationError)
    }

    func testRejectsANonHTTPSAPIAddress() {
        let configuration = ConnectionConfiguration(
            apiBaseURL: "http://api.example.com/v1",
            deviceName: "上海门店 Mac mini",
            activationCode: "RP-8F2K-91MZ"
        )

        XCTAssertEqual(configuration.validationError, "API 地址必须使用 HTTPS。")
    }

    func testAcceptsOnlyTheConfiguredLoopbackTestEndpoint() {
        let loopback = ConnectionConfiguration(apiBaseURL: "http://127.0.0.1:17880/v1", deviceName: "测试 Mac", activationCode: "RP-LOCAL-TEST")
        let network = ConnectionConfiguration(apiBaseURL: "http://192.168.1.2:17880/v1", deviceName: "测试 Mac", activationCode: "RP-LOCAL-TEST")

        XCTAssertNil(loopback.validationError)
        XCTAssertEqual(network.validationError, "API 地址必须使用 HTTPS。")
    }
}
