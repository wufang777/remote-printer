// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemotePrintSender",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RemotePrintSenderCore", targets: ["RemotePrintSenderCore"]),
        .executable(name: "RemotePrintSender", targets: ["RemotePrintSender"])
    ],
    targets: [
        .target(name: "RemotePrintSenderCore"),
        .executableTarget(name: "RemotePrintSender", dependencies: ["RemotePrintSenderCore"]),
        .testTarget(name: "RemotePrintSenderCoreTests", dependencies: ["RemotePrintSenderCore"])
    ]
)
