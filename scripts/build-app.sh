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

# 关于窗口的 License 与 Acknowledgements 从 App 的资源目录读取 Spooky、Sparkle 与 swift-subprocess 的许可证。
# swift-subprocess 的检出是只读的，拷出来的文件也只读；`-f` 让重新生成时能覆盖上一次的一份。
cp -f LICENSE "$app_directory/Contents/Resources/LICENSE.txt"
cp -f .build/artifacts/sparkle/Sparkle/LICENSE "$app_directory/Contents/Resources/Sparkle-LICENSE.txt"
cp -f .build/checkouts/swift-subprocess/LICENSE "$app_directory/Contents/Resources/Subprocess-LICENSE.txt"

# 各版本的更新说明供 Help › What's New 按版本列出；先删掉旧的一份，不残留已经删掉的说明。
rm -rf "$app_directory/Contents/Resources/ReleaseNotes"

if [[ -d docs/release-notes ]]; then
    ditto docs/release-notes "$app_directory/Contents/Resources/ReleaseNotes"
fi

# 系统权限弹窗与 Finder 从 App 自身的资源目录读取用途说明与文稿类型的名称。
for locale in en zh-Hans zh-Hant ja ko de fr es; do
    mkdir -p "$app_directory/Contents/Resources/$locale.lproj"
    cp "Sources/Spooky/Resources/$locale.lproj/InfoPlist.strings" \
        "$app_directory/Contents/Resources/$locale.lproj/InfoPlist.strings"
done

# Dock 按包目录的修改时间缓存图标；只替换包里的文件不会改这个时间，换了图标后 Dock 仍显示旧的一版。
touch "$app_directory"

printf '%s\n' "$app_directory"
