import Foundation
import Security

public struct DeviceCredentials: Codable, Equatable, Sendable {
    public let deviceID: String
    public let accessToken: String
    public let expiresAt: Date

    public var isExpired: Bool { expiresAt <= .now }
}

public protocol DeviceCredentialStoring: Sendable {
    func load() throws -> DeviceCredentials?
    func save(_ credentials: DeviceCredentials) throws
    func delete() throws
}

public final class InMemoryCredentialStore: DeviceCredentialStoring, @unchecked Sendable {
    private var credentials: DeviceCredentials?
    public init() {}
    public func load() throws -> DeviceCredentials? { credentials }
    public func save(_ credentials: DeviceCredentials) throws { self.credentials = credentials }
    public func delete() throws { credentials = nil }
}

public enum DeviceCredentialStoreError: Error, Sendable { case keychain(OSStatus), encoding }

public final class KeychainCredentialStore: DeviceCredentialStoring, @unchecked Sendable {
    private let service = "com.remote-print-simulator.device-credentials"
    private let account = "active-device"
    public init() {}

    public func load() throws -> DeviceCredentials? {
        var query: [CFString: Any] = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw DeviceCredentialStoreError.keychain(status) }
        return try JSONDecoder().decode(DeviceCredentials.self, from: data)
    }

    public func save(_ credentials: DeviceCredentials) throws {
        guard let data = try? JSONEncoder().encode(credentials) else { throw DeviceCredentialStoreError.encoding }
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw DeviceCredentialStoreError.keychain(status) }
        var query: [CFString: Any] = baseQuery
        query[kSecValueData] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw DeviceCredentialStoreError.keychain(addStatus) }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DeviceCredentialStoreError.keychain(status) }
    }

    private var baseQuery: [CFString: Any] { [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] }
}
