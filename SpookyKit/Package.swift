// swift-tools-version: 6.2

import Foundation
import PackageDescription

/// 将 App 标识嵌入可执行文件，使 `swift run` 也能使用固定的应用身份。
let appInfoPlist = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "Sources/Spooky/Info.plist")
    .path

/// 核心库、桌面应用及各自的验证目标。
let package = Package(
    name: "SpookyKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SpookyKit",
            targets: ["SpookyKit"]
        ),
        .executable(
            name: "Spooky",
            targets: ["Spooky"]
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
            ],
            resources: [.copy("Resources/spooky-remote.pl")]
        ),
        .executableTarget(
            name: "Spooky",
            dependencies: ["SpookyKit"],
            exclude: ["Info.plist"],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", appInfoPlist,
                ])
            ]
        ),
        .testTarget(
            name: "SpookyKitTests",
            dependencies: ["SpookyKit"]
        ),
        .testTarget(
            name: "SpookyTests",
            dependencies: ["Spooky", "SpookyKit"]
        )
    ]
)
