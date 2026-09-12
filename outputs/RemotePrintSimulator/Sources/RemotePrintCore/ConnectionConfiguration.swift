import Foundation

public struct ConnectionConfiguration: Equatable, Sendable {
    public var apiBaseURL: String
    public var deviceName: String
    public var activationCode: String

    public init(apiBaseURL: String, deviceName: String, activationCode: String) {
        self.apiBaseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.activationCode = activationCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var validationError: String? {
        guard let url = URL(string: apiBaseURL), (url.scheme == "https" || isLocalRelayURL(url)), url.host != nil else {
            return "API 地址必须使用 HTTPS。"
        }
        guard !deviceName.isEmpty else { return "请填写设备名称。" }
        guard !activationCode.isEmpty else { return "请填写注册码。" }
        return nil
    }
}

public func isLocalRelayURL(_ url: URL) -> Bool {
    url.scheme == "http" && url.host == "127.0.0.1" && url.port == 17880 && (url.path == "/v1" || url.path.hasPrefix("/v1/") || url.path.hasPrefix("/files/"))
}
