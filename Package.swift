// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchBay",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchBay",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
