---
name: release
description: 发布 Spooky 的新版本：准备这一版的更新说明，用 `mise run release` 开 release PR，等检查通过后合并，再等 GitHub Actions 创建 GitHub Release。
when_to_use: 用户要发布新版本时，例如 “发布 1.2.0” “发个 1.2.0 测试版” “release 1.2.0”。
argument-hint: "[X.Y.Z] [stable|beta|development]"
allowed-tools:
  - Bash(./scripts/check-release.sh *)
  - Bash(git fetch origin)
  - Bash(git describe *)
  - Bash(git log *)
  - Bash(mise run release *)
  - Bash(gh pr checks *)
  - Bash(gh pr merge *)
  - Bash(gh pr view *)
  - Bash(gh run list *)
  - Bash(gh run watch *)
  - Bash(gh release view *)
  - Bash(sleep *)
---

# 发布新版本

调用时带的参数：$ARGUMENTS

## 总则

- 全程用中文
- 每一步的结果都如实报告：失败就说失败，不略过，不说成成功
- 等 CI、等发布都要一段时间，可能超过单条命令的超时上限
  - 等待类命令放到后台运行
  - 不因为命令超时就判定失败

## 1. 确定版本号与通道

- 从用户的话或上面的参数里取版本号，格式为 `X.Y.Z`
- 没有给出版本号时，问用户要；不自行推断 “下一个版本”
- 通道是 `stable`、`beta` 或 `development`：用户说 “测试版” 取 `beta`，“开发版” 取 `development`，没有提到时取 `stable`

## 2. 准备更新说明

这一版的更新说明是 `docs/release-notes/<版本号>/` 下每种语言一份的 Markdown，写法见 `AGENTS.md` 的 “更新说明” 一节。先运行发布检查：

```bash
./scripts/check-release.sh <版本号> <通道>
```

- 通过：直接用，进入下一步
- 报错只涉及更新说明：按下面的步骤起草
- 其它报错（版本号格式、构建号、远端标签等）：把报错原样告诉用户，停止

### 起草

先取得远端最新的 main 与标签：

```bash
git fetch origin
```

找到 `origin/main` 上最近的 `v*` 标签：

```bash
git describe --tags --abbrev=0 --match 'v*' origin/main
```

列出此后合并进 main 的 PR，提交标题 “Merge pull request #编号 from …” 里是 PR 编号；还没有标签时去掉 `<标签>..`：

```bash
git log --first-parent --merges --format=%s <标签>..origin/main
```

逐个读 PR 的标题与描述：

```bash
gh pr view <PR 编号> --json title,body
```

然后：

- 按 `AGENTS.md` 的写法写出八份文件，不提交
- 把 `zh-Hans.md` 的内容给用户看，并说明另外七份的位置
- 用户确认后再进入下一步；用户提出修改时，同步改到八份文件里
  - 用户一开始就说了 “不用问” 之类的话，就不问

## 3. 开 release PR

```bash
mise run release <版本号> <通道>
```

- 失败：把脚本的报错原样告诉用户，停止
  - 起草的更新说明留在工作区，告诉用户它们在 `docs/release-notes/<版本号>/`，修好后重试时照常使用
- 成功：输出里 “已创建 PR：” 后面是 PR 链接，链接末尾的数字是 PR 编号

## 4. 等检查

```bash
gh pr checks <PR 编号> --watch
```

- 刚开的 PR 可能还没登记检查，报 `no checks reported` 时等几十秒再运行
- 检查失败：报告失败的检查项与链接，停止，不合并

## 5. 合并

- 检查通过后，问用户一次是否合并
  - 用户一开始就说了 “直接合并” “不用问” 之类的话，就不问
- 用户同意后合并：

```bash
gh pr merge <PR 编号> --merge --delete-branch
```

## 6. 等发布

合并后，release workflow 会对这个 PR 运行一次。先取 PR 最后一个提交的 SHA：

```bash
gh pr view <PR 编号> --json headRefOid --jq .headRefOid
```

再按这个 SHA 找到这次运行：

```bash
gh run list --workflow release.yml --commit <提交 SHA> --json databaseId,url
```

- 列表为空说明运行还没登记，等几秒再查
- 找到后等它结束：

```bash
gh run watch <运行 ID> --exit-status
```

## 7. 报告结果

成功：取 Release 链接给用户。

```bash
gh release view v<版本号> --json url --jq .url
```

失败：给出 Actions 运行链接，并说明：

- PR 已合并，但没有发布
- 修好失败原因后，再说一次 “发布 <版本号>” 即可重发
