#!/bin/bash

set -euo pipefail

# 从脚本位置定位仓库根目录，Swift 命令与相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# 发布构建与开发构建使用各自的产物目录，互不覆盖。
swift build --product Spooky --configuration release
binary_directory="$(swift build --configuration release --show-bin-path)"
app_directory="$project_root/build/Spooky.app"

# 每次从空目录组装，上一次打包残留的文件不会进入新的 Bundle。
rm -rf "$app_directory"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp Sources/Spooky/Info.plist "$app_directory/Contents/Info.plist"
cp "$binary_directory/Spooky" "$app_directory/Contents/MacOS/Spooky"

# 默认图标由 Info.plist 的 `CFBundleIconFile` 指定；其余几版由 App 在运行时按 “图标与小组件样式” 与连接状态换上。
cp Sources/Spooky/AppIcon/*.icns "$app_directory/Contents/Resources/"

# 界面文案、命名色、主题与远端包装器都在 SwiftPM 资源包内，运行时从 Contents/Resources 读取。
ditto "$binary_directory/Spooky_Spooky.bundle" "$app_directory/Contents/Resources/Spooky_Spooky.bundle"
ditto "$binary_directory/Spooky_SpookyKit.bundle" "$app_directory/Contents/Resources/Spooky_SpookyKit.bundle"

# 系统权限弹窗从 App 自身的资源目录读取用途说明。
for locale in en zh-Hans zh-Hant ja ko de fr es; do
    mkdir -p "$app_directory/Contents/Resources/$locale.lproj"
    cp "Sources/Spooky/Resources/$locale.lproj/InfoPlist.strings" \
        "$app_directory/Contents/Resources/$locale.lproj/InfoPlist.strings"
done

# 更新框架连同符号链接、辅助程序与 XPC 服务原样放进 Contents/Frameworks，下载与安装更新时都要用到。
sparkle_framework="$app_directory/Contents/Frameworks/Sparkle.framework"
mkdir -p "$app_directory/Contents/Frameworks"
ditto "$binary_directory/Sparkle.framework" "$sparkle_framework"

# Sparkle 以 MIT 许可证发布，随 App 附上它的版权与许可声明。
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app_directory/Contents/Resources/Sparkle-LICENSE.txt"

# 嵌套代码由内向外签名：先是 XPC 服务与辅助程序，再是框架；XPC 服务保留各自的 entitlements。
for service in Downloader Installer; do
    codesign --force --sign - --timestamp=none --preserve-metadata=entitlements \
        "$sparkle_framework/Versions/B/XPCServices/$service.xpc"
done

codesign --force --sign - --timestamp=none "$sparkle_framework/Versions/B/Autoupdate"
codesign --force --sign - --timestamp=none "$sparkle_framework/Versions/B/Updater.app"
codesign --force --sign - --timestamp=none "$sparkle_framework"

# ad-hoc 签名只保证 Bundle 内容完整、不代表开发者身份；最后签整个 App，签名后立即校验。
codesign --force --sign - --timestamp=none "$app_directory"
codesign --verify --strict --deep "$app_directory"

printf '%s\n' "$app_directory"
