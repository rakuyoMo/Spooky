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

# ad-hoc 签名只保证 Bundle 内容完整、不代表开发者身份；签名后立即校验。
codesign --force --sign - --timestamp=none "$app_directory"
codesign --verify --strict --deep "$app_directory"

printf '%s\n' "$app_directory"
