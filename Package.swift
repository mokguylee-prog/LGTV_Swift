// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LGNetCastRemote",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "LGNetCastRemote",
            path: "Sources/LGNetCastRemote",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
