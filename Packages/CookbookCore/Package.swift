// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CookbookCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CookbookCore",
            targets: ["CookbookCore"]
        ),
    ],
    targets: [
        .target(
            name: "CookbookCore",
            path: "Sources/CookbookCore"
        ),
        .testTarget(
            name: "CookbookCoreTests",
            dependencies: ["CookbookCore"],
            path: "Tests/CookbookCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
