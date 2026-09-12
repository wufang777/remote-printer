import Foundation

public enum DocumentPrintStrategy: String, CaseIterable, Codable, Sendable {
    case nativeApplication
    case convertToPDF
    case automatic

    public static let defaultValue: Self = .automatic
}
