// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotebookApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotebookApp", targets: ["NotebookApp"])
    ],
    targets: [
        .target(
            name: "NotebookCore"
        ),
        .executableTarget(
            name: "NotebookApp",
            dependencies: ["NotebookCore"]
        ),
        .testTarget(
            name: "NotebookCoreTests",
            dependencies: ["NotebookCore"]
        )
    ]
)
