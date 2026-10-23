#!/bin/bash

set -euo pipefail

# 从脚本位置定位仓库根目录，Swift 命令与相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

swift build --product Spooky
binary_directory="$(swift build --show-bin-path)"
app_directory="$project_root/.build/Spooky.app"

# 开发 Bundle 使用与 swift run 相同的程序与资源，供 Finder 启动和单独语言设置使用。
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp Sources/Spooky/Info.plist "$app_directory/Contents/Info.plist"
cp "$binary_directory/Spooky" "$app_directory/Contents/MacOS/Spooky.new"
mv "$app_directory/Contents/MacOS/Spooky.new" "$app_directory/Contents/MacOS/Spooky"
cp Sources/Spooky/AppIcon.icns "$app_directory/Contents/Resources/AppIcon.icns"
ditto "$binary_directory/Spooky_Spooky.bundle" "$app_directory/Contents/Resources/Spooky_Spooky.bundle"

ditto "$binary_directory/Spooky_SpookyKit.bundle" "$app_directory/Contents/Resources/Spooky_SpookyKit.bundle"

# 系统权限弹窗从 App 自身的资源目录读取用途说明。
for locale in en zh-Hans zh-Hant ja ko de fr es; do
    mkdir -p "$app_directory/Contents/Resources/$locale.lproj"
    cp "Sources/Spooky/Resources/$locale.lproj/InfoPlist.strings" \
        "$app_directory/Contents/Resources/$locale.lproj/InfoPlist.strings"
done

printf '%s\n' "$app_directory"
