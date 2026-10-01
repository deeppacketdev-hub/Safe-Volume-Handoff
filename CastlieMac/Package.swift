// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CastlieMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CastlieMac",
            targets: ["CastlieMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CastlieMac",
            path: ".",
            exclude: ["Info.plist"]
        )
    ]
)
