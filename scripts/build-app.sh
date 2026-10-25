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

# 默认图标由 Info.plist 的 `CFBundleIconFile` 指定；其余几版由 App 在运行时按 “图标与小组件样式” 与连接状态换上。
cp Sources/Spooky/AppIcon/*.icns "$app_directory/Contents/Resources/"

ditto "$binary_directory/Spooky_Spooky.bundle" "$app_directory/Contents/Resources/Spooky_Spooky.bundle"

ditto "$binary_directory/Spooky_SpookyKit.bundle" "$app_directory/Contents/Resources/Spooky_SpookyKit.bundle"

# 可执行文件从 Contents/Frameworks 加载更新框架；先删掉旧的一份，框架内的符号链接与文件不残留上次的版本。
rm -rf "$app_directory/Contents/Frameworks/Sparkle.framework"
mkdir -p "$app_directory/Contents/Frameworks"
ditto "$binary_directory/Sparkle.framework" "$app_directory/Contents/Frameworks/Sparkle.framework"

# 这一版的更新说明供 Help › What's New 显示；先删掉旧的一份，换了版本后不残留上一版的说明。
rm -rf "$app_directory/Contents/Resources/ReleaseNotes"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/Spooky/Info.plist)"

if [[ -d "docs/release-notes/$version" ]]; then
    ditto "docs/release-notes/$version" "$app_directory/Contents/Resources/ReleaseNotes"
fi

# 系统权限弹窗从 App 自身的资源目录读取用途说明。
for locale in en zh-Hans zh-Hant ja ko de fr es; do
    mkdir -p "$app_directory/Contents/Resources/$locale.lproj"
    cp "Sources/Spooky/Resources/$locale.lproj/InfoPlist.strings" \
        "$app_directory/Contents/Resources/$locale.lproj/InfoPlist.strings"
done

printf '%s\n' "$app_directory"
