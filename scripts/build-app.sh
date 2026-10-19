#!/bin/bash

set -euo pipefail

# 从脚本位置定位仓库，所有 Swift 命令仍使用根目录下的 --package-path。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

swift build --package-path SpookyKit --product Spooky
binary_directory="$(swift build --package-path SpookyKit --show-bin-path)"
app_directory="$project_root/SpookyKit/.build/Spooky.app"

# 开发 Bundle 使用与 swift run 相同的程序与资源，供 Finder 启动和单独语言设置使用。
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp SpookyKit/Sources/Spooky/Info.plist "$app_directory/Contents/Info.plist"
cp "$binary_directory/Spooky" "$app_directory/Contents/MacOS/Spooky.new"
mv "$app_directory/Contents/MacOS/Spooky.new" "$app_directory/Contents/MacOS/Spooky"
ditto "$binary_directory/SpookyKit_Spooky.bundle" "$app_directory/Contents/Resources/SpookyKit_Spooky.bundle"

ditto "$binary_directory/SpookyKit_SpookyKit.bundle" "$app_directory/Contents/Resources/SpookyKit_SpookyKit.bundle"

# 系统权限弹窗从 App 自身的资源目录读取用途说明。
for locale in en zh-Hans zh-Hant ja ko; do
    mkdir -p "$app_directory/Contents/Resources/$locale.lproj"
    cp "SpookyKit/Sources/Spooky/Resources/$locale.lproj/InfoPlist.strings" \
        "$app_directory/Contents/Resources/$locale.lproj/InfoPlist.strings"
done

printf '%s\n' "$app_directory"
