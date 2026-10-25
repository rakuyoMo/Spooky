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
    name: "Spooky",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "SpookyKit",
            targets: ["SpookyKit"]
        ),
        .executable(
            name: "Spooky",
            targets: ["Spooky"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            .upToNextMinor(from: "1.0.1")
        ),

        // 代码规范：提供 `swift package format` 命令插件
        .package(
            url: "https://github.com/RakuyoKit/swift.git",
            exact: "1.4.0"
        ),

        // 更新的检查、签名校验与安装
        .package(
            url: "https://github.com/sparkle-project/Sparkle.git",
            exact: "2.10.0"
        ),
    ],
    targets: [
        .target(
            name: "SpookyKit",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            resources: [.copy("Resources/spooky-remote.pl")]
        ),
        .executableTarget(
            name: "Spooky",
            dependencies: [
                "SpookyKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            exclude: [
                "Info.plist",
                "AppIcon/AppIcon.icns",
                "AppIcon/AppIconConnected.icns",
                "AppIcon/AppIconDark.icns",
                "AppIcon/AppIconDarkConnected.icns",
            ],
            resources: [
                .process("Resources"),

                // highlight.js 的脚本与许可证保持原有目录结构，`.process` 会把子目录摊平到资源包根目录
                .copy("HighlightJS"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", appInfoPlist,

                    // App Bundle 从自身的 Frameworks 目录加载更新框架
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .testTarget(
            name: "SpookyKitTests",
            dependencies: ["SpookyKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "SpookyTests",
            dependencies: ["Spooky", "SpookyKit"]
        ),

        // 发布脚本的检查与更新清单的合成，在临时仓库与临时目录里运行 scripts/ 下的脚本
        .testTarget(
            name: "ReleaseTests",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            exclude: ["Fixtures"]
        ),
    ]
)
