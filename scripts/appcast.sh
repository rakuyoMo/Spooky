#!/bin/bash

# 把打包好的 build/Spooky.app 压缩成更新包，生成签名的更新清单，都输出到 build/updates/
# 清单里嵌入这一版每种语言的更新说明，并从上一份清单带上比这一版更稳定的各通道里最新的条目
# 用法：scripts/appcast.sh <stable|beta|development> [<上一份更新清单>]
#
# 私钥在 CI 里经环境变量 SPARKLE_PRIVATE_KEY 传入，再经标准输入交给 Sparkle 的工具，不写进参数或文件；
# 本机没有这个变量时，从钥匙串里 com.rakuyo.spooky 账户的项目读取

set -euo pipefail

# 从脚本位置定位仓库根目录，相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

readonly app_directory="build/Spooky.app"
readonly updates_directory="build/updates"
readonly sparkle_tools=".build/artifacts/sparkle/Sparkle/bin"
readonly releases_url="https://github.com/rakuyoMo/Spooky/releases"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "错误：用法：scripts/appcast.sh <stable|beta|development> [<上一份更新清单>]" >&2
    exit 1
fi

readonly channel="$1"
readonly previous_feed="${2:-}"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_directory/Contents/Info.plist")"
readonly version

# 稳定版的条目不带通道，所有用户都能收到；测试与开发版本的条目标上自己的通道
case "$channel" in
    stable) channel_option="" ;;
    beta | development) channel_option="--channel=$channel" ;;

    *)
        echo "错误：通道须为 stable、beta 或 development，实际为 “${channel}”" >&2
        exit 1
        ;;
esac

# 每份清单只包含这一次的安装包，先移除上次生成的产物
rm -rf "$updates_directory"
mkdir -p "$updates_directory"

# 不带扩展属性，避免解压后出现破坏 App 签名的 ._* 文件
ditto -c -k --norsrc --keepParent "$app_directory" "$updates_directory/Spooky-$version.zip"

# CI 经标准输入传入私钥，本机读钥匙串
signing_option="--account=com.rakuyo.spooky"

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    signing_option="--ed-key-file=-"
fi

# 下载地址与 “版本历史记录” 都指向 GitHub Release；不生成增量更新
printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | "$sparkle_tools/generate_appcast" \
    "$signing_option" \
    ${channel_option:+"$channel_option"} \
    --download-url-prefix "$releases_url/download/v$version/" \
    --full-release-notes-url "$releases_url" \
    --link "$releases_url" \
    --maximum-deltas 0 \
    "$updates_directory"

# 嵌入每种语言的更新说明，带上更稳定的通道里最新的条目
swift scripts/compose-appcast.swift \
    "$updates_directory/appcast.xml" \
    "docs/release-notes/$version" \
    ${previous_feed:+"$previous_feed"}

# 改写让 generate_appcast 签下的清单签名失效：sign_update 先去掉旧的签名块再重签，取私钥的方式与上面相同
printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | "$sparkle_tools/sign_update" \
    "$signing_option" \
    "$updates_directory/appcast.xml"
