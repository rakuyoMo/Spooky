#!/bin/bash

# 在 App 包里写出每个非默认图标组的壳 App：只装该组的默认图标，App 取它的系统图标作为该组运行时图标与自定义图标的底
# `scripts/build-app.sh` 与 `scripts/bundle.sh` 拷完 icns 之后调用
#
# 壳 App 放在 Contents/Resources/ 下：聚焦不收录这个位置的 App，壳 App 也作为资源封进外层签名，不必单独签名；
# 它不声明文稿类型，不出现在 “打开方式” 里
#
# 用法：
#   scripts/make-icon-shells.sh <App 包>

set -euo pipefail

# 从脚本位置定位仓库根目录，相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

app_directory="$1"

# 非默认组的默认图标名，与 `AppIconGroup` 的资源名一致；壳 App 与它同名
icon_names=(AppIconMidnight)

for icon_name in "${icon_names[@]}"; do
    shell="$app_directory/Contents/Resources/$icon_name.app"

    # 先删掉旧的一份，壳 App 里不残留上次的文件
    rm -rf "$shell"
    mkdir -p "$shell/Contents/MacOS" "$shell/Contents/Resources"

    cp "Sources/Spooky/AppIcon/$icon_name.icns" "$shell/Contents/Resources/$icon_name.icns"

    cat > "$shell/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$icon_name</string>
    <key>CFBundleIconFile</key>
    <string>$icon_name</string>
    <key>CFBundleIdentifier</key>
    <string>com.rakuyo.spooky.$icon_name</string>
    <key>CFBundleName</key>
    <string>$icon_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

    # 没有可执行文件时系统在图标上盖一个禁止符号；这个脚本什么都不做，系统给出的图标与放编译出的程序时相同
    printf '#!/bin/sh\nexit 0\n' > "$shell/Contents/MacOS/$icon_name"
    chmod 755 "$shell/Contents/MacOS/$icon_name"
done
