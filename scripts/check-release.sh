#!/bin/bash

# 发布前的共用检查：版本号与通道的格式、Info.plist 的构建号、这一版的更新说明，以及远端是否已有同名标签
# 本机的 `mise run release`、release PR 的检查与发布工作流都调用这一份
#
# 用法：
#   scripts/check-release.sh X.Y.Z [stable|beta|development]
#     开 release PR 之前：Info.plist 里当前的构建号须是正整数，通道默认为 stable
#   scripts/check-release.sh --title '<PR 标题>' --base <提交>
#     release PR 与发布工作流：从标题取出版本号与通道；Info.plist 的版本号须与标题一致，
#     构建号须比基准提交里的增加 1；通过后向标准输出写出 VERSION=… 与 CHANNEL=… 两行

set -euo pipefail

# 从脚本位置定位仓库根目录，相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# 版本号与构建号所在的 Info.plist
readonly info_plist="Sources/Spooky/Info.plist"

# 版本号：三段都是不带前导零的非负整数，不带 v
readonly version_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

# PR 标题：稳定版为 `release: X.Y.Z`，测试与开发版本在后面加 ` (beta)` 或 ` (development)`
readonly title_pattern='^release: ([0-9.]+)( \((beta|development)\))?$'

# 输出中文报错并退出
fail() {
    echo "错误：$*" >&2
    exit 1
}

# 读出 Info.plist 的一个键；第二个参数给出提交时读那个提交里的版本
plist_value() {
    local key="$1"
    local commit="${2:-}"

    if [[ -z "$commit" ]]; then
        /usr/libexec/PlistBuddy -c "Print :$key" "$info_plist"
        return
    fi

    git show "$commit:$info_plist" | plutil -extract "$key" raw -o - -
}

# 1. 解析参数：本机直接给出版本号与通道，PR 与发布工作流给出标题与基准提交
title=""
base=""

if [[ "${1:-}" == "--title" ]]; then
    if [[ $# -ne 4 || "$3" != "--base" ]]; then
        fail "用法：scripts/check-release.sh --title '<PR 标题>' --base <提交>"
    fi

    title="$2"
    base="$4"

    if [[ ! "$title" =~ $title_pattern ]]; then
        fail "PR 标题须为 “release: X.Y.Z”，测试与开发版本在后面加 “ (beta)” 或 “ (development)”，实际为 “${title}”"
    fi

    version="${BASH_REMATCH[1]}"
    channel="${BASH_REMATCH[3]:-stable}"
else
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        fail "用法：scripts/check-release.sh X.Y.Z [stable|beta|development]"
    fi

    version="$1"
    channel="${2:-stable}"
fi

readonly version channel

# 2. 版本号与通道的格式
if [[ ! "$version" =~ $version_pattern ]]; then
    fail "版本号须为 X.Y.Z，三段都是不带前导零的整数，实际为 “${version}”"
fi

case "$channel" in
    stable | beta | development) ;;
    *) fail "通道须为 stable、beta 或 development，实际为 “${channel}”" ;;
esac

# 3. 构建号：从不回退，每次发布增加 1，更新按它比较新旧
build="$(plist_value CFBundleVersion)"

if [[ ! "$build" =~ ^[1-9][0-9]*$ ]]; then
    fail "构建号须为正整数，实际为 “${build}”"
fi

if [[ -n "$base" ]]; then
    short_version="$(plist_value CFBundleShortVersionString)"

    if [[ "$short_version" != "$version" ]]; then
        fail "Info.plist 的版本号须为 ${version}，实际为 ${short_version}"
    fi

    if ! previous_build="$(plist_value CFBundleVersion "$base")"; then
        fail "读取基准提交 ${base} 里的构建号失败"
    fi

    if [[ ! "$previous_build" =~ ^[1-9][0-9]*$ ]]; then
        fail "基准提交里的构建号须为正整数，实际为 “${previous_build}”"
    fi

    if [[ "$build" -ne "$((previous_build + 1))" ]]; then
        fail "构建号须从 ${previous_build} 增加到 $((previous_build + 1))，实际为 ${build}"
    fi
fi

# 4. 更新说明：与 App 支持的语言一一对应，每份都存在且有内容；把问题一次列全
notes_directory="docs/release-notes/$version"
problems=()

for locale in en zh-Hans zh-Hant ja ko de fr es; do
    file="$notes_directory/$locale.md"

    if [[ ! -f "$file" ]]; then
        problems+=("缺少 $file")
        continue
    fi

    # 只有空白字符的说明与空文件一样，更新窗口不会显示说明
    if ! grep -q '[^[:space:]]' "$file"; then
        problems+=("$file 没有内容")
    fi
done

if [[ ${#problems[@]} -gt 0 ]]; then
    echo "错误：${version} 的更新说明不全：" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    exit 1
fi

# 5. 远端标签：已有同名标签说明这个版本发布过
# `--exit-code` 下退出码 0 表示存在，2 表示不存在，其它表示查询本身失败，此时无法确认
status=0
git ls-remote --exit-code --tags origin "refs/tags/v$version" > /dev/null \
    || status=$?

if [[ "$status" -eq 0 ]]; then
    fail "标签 v${version} 在远端已存在，这个版本发布过"
fi

if [[ "$status" -ne 2 ]]; then
    fail "查询远端标签失败，退出码 ${status}"
fi

# 6. 给 PR 与发布工作流记下版本号与通道
if [[ -n "$title" ]]; then
    echo "VERSION=$version"
    echo "CHANNEL=$channel"
fi
