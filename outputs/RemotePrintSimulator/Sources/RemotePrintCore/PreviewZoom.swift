import Foundation

public struct PreviewZoom: Equatable, Sendable {
    public private(set) var scale: Double = 1

    public init() {}

    public mutating func zoomIn() {
        scale = min(scale + 0.25, 4)
    }

    public mutating func zoomOut() {
        scale = max(scale - 0.25, 0.25)
    }

    public mutating func reset() {
        scale = 1
    }
}
