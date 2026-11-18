// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sumi",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Sumi",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            path: "Sources/Sumi"
        )
    ],
    swiftLanguageModes: [.v5]
)
