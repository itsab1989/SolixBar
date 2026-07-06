// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SolixBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SolixBar", targets: ["SolixBar"])
    ],
    targets: [
        .executableTarget(
            name: "SolixBar",
            path: "Sources/SolixBar"
        )
    ]
)
