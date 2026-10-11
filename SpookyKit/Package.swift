// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpookyKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SpookyKit",
            targets: ["SpookyKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            .upToNextMinor(from: "1.0.1")
        )
    ],
    targets: [
        .target(
            name: "SpookyKit",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess")
            ]
        ),
        .testTarget(
            name: "SpookyKitTests",
            dependencies: ["SpookyKit"]
        )
    ]
)
