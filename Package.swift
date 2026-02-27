// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppShots",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppShots", targets: ["AppShots"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "AppShots",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "AppShots"
        )
    ]
)
