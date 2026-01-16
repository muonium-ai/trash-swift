// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "trash-swift",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "trash", targets: ["TrashCLI"])
    ],
    targets: [
        .target(
            name: "TrashCore"
        ),
        .executableTarget(
            name: "TrashCLI",
            dependencies: ["TrashCore"]
        ),
        .testTarget(
            name: "TrashCoreTests",
            dependencies: ["TrashCore"]
        )
    ]
)
