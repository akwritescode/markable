// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Markable",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Markable",
            resources: [.copy("Resources")]
        )
    ]
)
