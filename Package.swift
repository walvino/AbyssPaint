// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AbyssPaint",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AbyssPaint", targets: ["AbyssPaint"])
    ],
    targets: [
        .executableTarget(
            name: "AbyssPaint",
            path: "Sources/AbyssPaint"
        )
    ]
)
