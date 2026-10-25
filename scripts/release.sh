#!/bin/bash

# 为新版本开 release PR：检查通过后切出 release/X.Y.Z 分支，写入版本号与构建号，提交、推送并向 main 开 PR
# 用法：mise run release X.Y.Z [stable|beta|development]，通道默认为 stable

set -euo pipefail

# 从脚本位置定位仓库根目录，相对路径都以它为基准。
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# 版本号与构建号所在的 Info.plist
readonly info_plist="Sources/Spooky/Info.plist"

# 输出中文报错并退出
fail() {
    echo "错误：$*" >&2
    exit 1
}

# 查询远端是否已有某个分支；查询本身失败时无法下结论，直接报错退出
remote_has_branch() {
    local status=0
    git ls-remote --exit-code --heads origin "refs/heads/$1" > /dev/null \
        || status=$?

    if [[ "$status" -ne 0 && "$status" -ne 2 ]]; then
        fail "查询远端分支 $1 失败，退出码 ${status}"
    fi

    [[ "$status" -eq 0 ]]
}

# 推送或开 PR 失败时撤回发布分支：本机与远端都删掉，重试时不会被 “分支已存在” 拦住
# 发布提交里的更新说明退回工作区，修好后重试时不必重写；版本号与构建号的改动丢弃
discard_release_branch() {
    git reset --quiet main
    git restore "$info_plist"
    git switch --quiet main
    git branch --delete --quiet "$branch"

    # 推送本身没成功时远端本来就没有这个分支，删除失败可以忽略
    git push --quiet origin --delete "$branch" 2> /dev/null \
        || true
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    fail "用法：mise run release X.Y.Z [stable|beta|development]"
fi

# 新版本号、通道，以及对应的发布分支与更新说明目录
readonly version="$1"
readonly channel="${2:-stable}"
readonly branch="release/$version"
readonly notes_directory="docs/release-notes/$version"

# 1. 共用检查：版本号与通道的格式、当前构建号、更新说明与远端标签
scripts/check-release.sh "$version" "$channel"

# 2. 发布分支从 main 切出
current_branch="$(git branch --show-current)"

if [[ "$current_branch" != "main" ]]; then
    fail "须在 main 分支上运行，当前分支：${current_branch:-无（游离的 HEAD）}"
fi

# 3. 更新说明以外的未提交改动会混进发布提交；逐个列出未跟踪的文件，整个 docs/release-notes/ 未跟踪时也能排除这一版的目录
worktree_changes="$(
    git status --porcelain --untracked-files=all \
        -- . ":(exclude)$notes_directory"
)"

if [[ -n "$worktree_changes" ]]; then
    fail "除 ${notes_directory}/ 外，工作区有未提交的改动或未跟踪的文件，请先处理"
fi

# 4. 本地 main 须与远端一致：落后会漏掉已合并的改动，超前会把没审过的提交带进发布
git fetch --quiet origin \
    || fail "git fetch origin 失败"

if [[ "$(git rev-parse main)" != "$(git rev-parse origin/main)" ]]; then
    fail "本地 main 与 origin/main 不一致，请先同步"
fi

# 5. 后面要用 gh 开 PR；origin 须是本仓库，fork 的 PR 合并后拿不到发布所需的写权限
gh auth status > /dev/null \
    || fail "gh 未通过登录检查，请按上面的提示处理后重试"

origin_url="$(git remote get-url origin)"

origin_is_fork="$(gh repo view "$origin_url" --json isFork --jq .isFork)" \
    || fail "查询 origin 对应的 GitHub 仓库失败：${origin_url}"

if [[ "$origin_is_fork" != "false" ]]; then
    fail "origin 须是本仓库，不能是 fork：${origin_url}"
fi

# 6. 本机或远端已有同名分支时不覆盖，交给用户确认后清理
if git show-ref --quiet --verify "refs/heads/$branch"; then
    fail "本机已有分支 ${branch}"
fi

if remote_has_branch "$branch"; then
    fail "远端已有分支 ${branch}"
fi

# 7. 切出发布分支，写入版本号，构建号增加 1；工作区里这一版的更新说明随切换带到发布分支
next_build="$(($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist") + 1))"

git switch --quiet --create "$branch"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build" "$info_plist"

# 标题即发布提交与 PR 的标题；发布工作流按它取出版本号与通道
title="release: $version"

if [[ "$channel" != "stable" ]]; then
    title+=" ($channel)"
fi

# 更新说明已在 main 上且没有改动时，发布提交只改 Info.plist
git add "$info_plist" "$notes_directory"
git commit --quiet --message "$title"

# 8. 推送发布分支并开 PR；任一步失败都撤回发布分支
git push --quiet --set-upstream origin "$branch" || {
    discard_release_branch
    fail "推送 ${branch} 失败"
}

pr_url="$(
    gh pr create \
        --base main \
        --head "$branch" \
        --title "$title" \
        --body "发布 ${version}（${channel} 通道）：合并后由 GitHub Actions 打包并创建 Release。这一版的更新说明在 \`${notes_directory}/\`。"
)" || {
    discard_release_branch
    fail "创建 PR 失败"
}

echo "已创建 PR：$pr_url"

# 发布分支已推送到远端，本机副本没有用处；留着会让重发同一版本时被 “本机已有分支” 拦住
git switch --quiet main
git branch --delete --force --quiet "$branch"
