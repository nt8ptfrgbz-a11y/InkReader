// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InkReaderCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "InkReaderCore", targets: ["InkReaderCore"])],
    targets: [
        .target(name: "InkReaderCore", path: "InkReader/Core"),
        .testTarget(name: "InkReaderCoreTests", dependencies: ["InkReaderCore"], path: "Tests/InkReaderCoreTests")
    ]
)
