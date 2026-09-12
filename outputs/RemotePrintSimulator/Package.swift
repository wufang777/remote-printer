// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemotePrintSimulator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RemotePrintCore", targets: ["RemotePrintCore"]),
        .executable(name: "RemotePrintSimulator", targets: ["RemotePrintSimulator"])
    ],
    targets: [
        .target(name: "RemotePrintCore"),
        .executableTarget(name: "RemotePrintSimulator", dependencies: ["RemotePrintCore"]),
        .testTarget(name: "RemotePrintCoreTests", dependencies: ["RemotePrintCore"])
    ]
)
