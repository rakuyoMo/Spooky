<h1 align="center">Spooky</h1>

<div align="center">

[English](README.md) | 简体中文

macOS 原生 Git 客户端，本机仓库和服务器上的仓库都能直接操作。

[![CI](https://github.com/rakuyoMo/Spooky/actions/workflows/ci.yml/badge.svg)](https://github.com/rakuyoMo/Spooky/actions/workflows/ci.yml)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

</div>

> [!NOTE]
> 想直接使用 Spooky 的话，从 [GitHub Releases](https://github.com/rakuyoMo/Spooky/releases/latest) 下载；第一次打开前，先看使用手册里的 [安装 Spooky](https://spooky.rakuyo.dev/zh-cn/guide/start/install/)。

## 简介

Spooky 既能打开本机的 Git 仓库，也能经 SSH 直接操作另一台机器上的仓库。

服务器仓库的工作区始终留在服务器上：Git 命令与文件读写都在服务器上执行，不需要把仓库克隆到本机。

连接使用系统自带的 SSH 和 `~/.ssh/config` 里的主机别名，认证、主机指纹和连接复用都交给 OpenSSH 处理。

本文写给开发者：需要哪些工具，怎样构建、运行、测试与调试 Spooky，以及怎样参与贡献。

## 环境要求

### 开发环境

- macOS 26 或更高版本

- 带 Swift 6.2 或更高版本的 Xcode。CI 与发布使用 [`ci.yml`](.github/workflows/ci.yml) 里 `DEVELOPER_DIR` 指定的 Xcode，想得到与 CI 相同的结果时用同一版

- [mise](https://mise.jdx.dev)，用来执行 `mise.toml` 里定义的构建、测试、代码规范、发布与官网任务

### Git 与服务器

Spooky 在仓库所在的机器上执行 Git，用来测试的机器需要：

- 本机和服务器上的 Git 都需要 `2.41.0` 或更高版本，这个要求来自 Spooky 使用的 `git fetch --porcelain`
  - 本机仓库使用 `/usr/bin/git`，也可以在设置里换成别的 Git 程序
  - 服务器仓库使用该主机上的 Git

- 服务器上：
  - 支持反向 Unix socket 转发的 OpenSSH
  - 在服务器上为 Git 输入 SSH 私钥口令时，OpenSSH 需要 `8.4` 或更高版本
  - sshd 的 `MaxSessions` 不小于 10（OpenSSH 的默认值）
  - `/usr/bin/perl`，以及核心模块 `IO::Socket::UNIX`、`JSON::PP`、`POSIX`
  - 不需要 root 权限，也不安装常驻服务

- 使用 Git LFS 的仓库，需要仓库所在的机器上有 Git LFS `2.9.0` 或更高版本，并在那里 Git 使用的 `PATH` 里

- 经 sshfs 挂载服务器仓库时，本机需要 sshfs 及 macFUSE 或 FUSE-T

- Pull Request 与 Merge Request 需要 github.com、GitLab.com 或私有部署 GitLab `9.0` 及以上版本的账号

## 构建与运行

命令都在仓库根目录执行：

```sh
# 获取源码
git clone https://github.com/rakuyoMo/Spooky.git
cd Spooky

# 编译核心库与 App
mise run build

# 启动 App
swift run Spooky
```

`swift run` 直接启动可执行文件，没有 App 包才带的应用图标、更新说明、许可证与本地化的权限说明，更新与系统通知也不启用。

需要这些，或者要从访达打开 Spooky、在系统设置里单独设置它的语言时，生成开发版 App：

```sh
# 生成 .build/Spooky.app
./scripts/build-app.sh

# 启动生成的 App
open .build/Spooky.app
```

发布版 App 使用 release 构建，并做 ad-hoc 签名与校验：

```sh
# 生成 build/Spooky.app
mise run bundle
```

## 架构

Spooky 是一个 Swift Package，主要有两个 target，都按功能分目录：

- `SpookyKit`（`Sources/SpookyKit/`）：核心库，在本机或服务器上执行 Git、读写仓库文件并解析输出

- `Spooky`（`Sources/Spooky/`）：App，AppKit 管理窗口、分栏、工具栏和菜单，SwiftUI 承载内容

贯穿整个代码库的几项设计：

- **Git 一律经 `GitRunner` 执行**：本机与服务器仓库共用一套接口。本机仓库执行设置里选的 Git 程序，服务器仓库经 `/usr/bin/ssh` 在服务器上执行

- **一次一个写操作**：每个仓库一条写队列，打开它的窗口共用；写操作按发起的先后一次执行一个，正有写操作时发起的排队等着轮到。纯读取的 Git 命令登记在 `RepositoryOperationQueue.isReadOnly`，其余命令都按写操作处理

- **服务器连接**：每个服务器工作区使用专属的 SSH 主连接（ControlMaster），空闲 10 分钟后退出。首次连接检查通过后，Perl 写的远端包装器 `spooky-remote.pl` 按内容摘要命名，安装到服务器的 `~/.spooky/bin/`，负责远端进程与回调。文件同样由包装器读写，命令经主连接上一个常驻的包装器会话执行；只有一次读取放不下的大文件经 SFTP 取回

- **回调**：Git 需要密码、口令或编辑器时，请求经 `CallbackRelay` 回到本机：服务器仓库经主连接上的反向 Unix socket，本机仓库经私有的 Unix socket

- **刷新**：本机仓库在 FSEvents 报告文件变化时刷新；服务器仓库在前台每 2 秒、后台每 10 秒轮询一次，服务器持续回得慢时间隔拉长

- **交给其它程序的文件**：Quick Look、外部工具与拖出的文件一律经 `RepositoryFileCache` 取得，服务器上的路径不会交给本机的文件 API

- **托管服务**：对 GitHub 与 GitLab 的请求都经 `HostingClient` 从本机发出

各目录的职责与跨模块的设计见 [架构](docs/architecture.md)，写代码时必须遵守的约束见 [AGENTS.md](AGENTS.md)。

## 测试

```sh
# 运行默认开启的测试
mise run test

# 只运行一个测试套件
swift test --filter LocalizationTests
```

- 测试使用 Swift Testing；涉及 Git 的测试在临时仓库中运行，不读取系统和用户的全局 Git 配置

- App 测试里的窗口一律透明、sheet 不播动画，运行期间屏幕上不出现窗口

- 经辅助功能接口读取窗口的测试，只在运行测试的进程有辅助功能权限时运行；在终端里运行时，权限跟随终端程序

- Git LFS 的测试只在 `PATH` 或 Homebrew 的目录里找得到 `git-lfs` 时运行

- 测试不设时间上限。运行卡住时，输出里只有开始、没有结束的那一项就是卡住的测试；CI 的测试 job 在 30 分钟后结束

需要服务器、github.com 或大仓库的测试默认跳过，用环境变量开启：

| 环境变量 | 开启的测试 |
|---|---|
| `SPOOKY_REMOTE_TESTS=1` | 服务器测试，连接 SSH 主机别名 `spooky-test` |
| `SPOOKY_GITHUB_TESTS=1` | 在 github.com 测试仓库上进行的 Pull Request 测试，另需 `SPOOKY_GITHUB_TOKEN` 与 `SPOOKY_GITHUB_REPOSITORY` |
| `SPOOKY_PERFORMANCE_TESTS=1` | 在生成的 10 万个文件、6 万个提交的仓库上进行的性能测试 |

准备方法见 [测试](docs/testing/README.md)，那里还有各里程碑的手动验收步骤。

## 调试

### 日志

Spooky 的日志写在 `com.rakuyo.spooky` 子系统下，category 是所在的类型名：

```sh
# 实时查看日志
/usr/bin/log stream --predicate 'subsystem == "com.rakuyo.spooky"' --level info

# 查看最近 5 分钟的日志
/usr/bin/log show --last 5m --predicate 'subsystem == "com.rakuyo.spooky"' --info
```

日志记录连接状态的切换、远端会话、Git 命令的失败与取消、写操作与回调请求，不记命令参数、命令输出、提交信息与凭据。

仓库路径、主机别名等用户数据标为私有，在日志里显示为 `<private>`。zsh 里的 `log` 是内建命令，所以要写完整路径。

### Developer 菜单

在设置的 “通用” 页勾选 “显示 Developer 菜单” 后，菜单栏多出 Developer 菜单：

- **User Defaults**：把全部偏好打印到标准输出；重置设置，保留书签、身份档案、账号、服务器仓库的本机位置与工具栏按钮；或者不经询问清空整个偏好域

- **Test Crash Reporting**：用伪造的异常或非法内存访问让 App 崩溃，检查崩溃报告

- **Auto-Archive Branches**：立即运行自动归档，或清掉各仓库上次检查自动归档的时刻

- **Show What’s New Card**：在侧边栏重新显示新功能卡片

- **Auto-Reload Repository**：打开或关闭文件监听与轮询触发的刷新

### 数据存放的位置

本机：

| 数据 | 位置 |
|---|---|
| 设置、书签、身份档案、账号列表、服务器仓库的本机位置与工具栏按钮 | 偏好设置域 `com.rakuyo.spooky` |
| 主题，一个主题一个 `.spookytheme` 文件 | `~/Library/Application Support/Spooky/Themes/` |
| 把服务器仓库登记进最近文稿的 `.spookyrepo` 文件夹 | `~/Library/Application Support/Spooky/Locations/` |
| “活动” 窗口里的远程操作记录，保留 7 天 | `~/Library/Application Support/Spooky/Activity/` |
| “活动” 窗口用来计算增减的上一次清单 | `~/Library/Application Support/Spooky/Baselines/` |
| 存入钥匙串的凭据 | 钥匙串，服务名 `com.rakuyo.spooky.remote.<主机别名>` |
| 托管账号的令牌 | 钥匙串，服务名 `com.rakuyo.spooky.hosting.<实例地址>` |
| 在设置的 “SSH 主机” 页管理的主机别名 | `~/.ssh/config`，系统 SSH 读的那份配置 |
| 连接与回调 | 私有的 `/tmp/spooky-*` 目录，关闭会话后清理 |
| 交给 Quick Look 和其它程序的文件副本 | 私有的 `spooky-files-*` 临时目录，关闭仓库后清理 |

服务器：

| 数据 | 位置 |
|---|---|
| 远端包装器及其 askpass、GPG 与 ssh-keygen 入口 | `~/.spooky/bin/`，会话结束后保留，供下次连接使用 |
| 会话期间的运行时文件 | `/tmp/spooky-*`，关闭会话后清理 |

仓库里，分支的置顶、归档、父分支与分支整理标记保存在仓库自己的 Git 配置里，键为 `branch.<名称>.spooky-*`；仓库设置同样写进这份配置。

## 本地化

Spooky 支持英文、简体中文、繁体中文、日文、韩文、德文、法文和西班牙文，跟随系统语言，其它语言环境下显示英文。文案在 `Sources/Spooky/Resources/<语言>.lproj/`。

新增文案时，所有语言一起加上，格式参数保持一致。任一语言缺少资源键、译文为空、格式参数对不上，或者资源键没有被界面用到时，`LocalizationTests` 都会失败；运行时拼出的资源键登记在 `LocalizationTests.dynamicKeys`。

## 官网

官网 [spooky.rakuyo.dev](https://spooky.rakuyo.dev) 有首页与使用手册，由 `website/` 用 [Astro](https://astro.build) 与 [Starlight](https://starlight.astro.build) 构建。构建需要 Node.js 24，由 mise 只为官网的任务安装：

```sh
# 安装依赖并启动开发服务器
mise run website:dev

# 运行官网的自测，检查类型与站内链接，构建到 website/dist/
mise run website:build
```

页面里的界面叫法按资源键取自 `Localizable.strings`，官网用到的资源键改名或删除时，官网的构建会失败。首页的模拟窗口还从 `BuiltinThemes.json` 与 `NamedColors.json` 取颜色。首页与 404 页上的应用图标和幽灵，构建时由 `scripts/make-icon/` 里应用图标的绘制脚本画出。截图存在 [Git LFS](https://git-lfs.com) 里，克隆前先装好它才能取到截图。

在本机打开首页时（开发服务器或预览构建出的站点），页面上铺一层带序号的网格，页头读出视口顶边与幽灵中心所在的格，方便按坐标说明跟着滚动的小幽灵在哪里该做什么；发布的站点上不显示这层网格。

改到官网的 PR 由 GitHub Actions 构建一次，`main` 上官网有变化时再发布到 GitHub Pages。

## 代码规范

代码风格以 [RakuyoKit/swift](https://github.com/RakuyoKit/swift) 为准：

```sh
# 按代码规范格式化，并自动修复可修复的问题
mise run swift:format

# 检查代码规范
mise run swift:lint
```

SwiftLint 以严格模式运行，警告同样算不通过。其余编码约定见 [AGENTS.md](AGENTS.md)。

## 参与贡献

- 提交 PR 前，请运行 `mise run swift:lint`、`mise run build` 和 `mise run test`，确认都能通过；CI 会在每个 PR 与推送到 `main` 时运行同样的检查，并打包 App

- 改动 App 时，还要实际启动 App，确认改动的效果，基本步骤见 [M1](docs/testing/M1.md)

- 代码、注释、日志、测试、分支命名、提交信息与 PR 的约定见 [AGENTS.md](AGENTS.md)，Claude Code、Codex 等编程 Agent 同样遵循它

- 引入外部代码前，请先确认它的许可证与 GPL-3.0 兼容

## 友链

[LINUX DO](https://linux.do)

## 许可证

Spooky 以 [GNU General Public License v3.0](LICENSE) 许可证发布。

### 第三方软件

- [Sparkle](https://sparkle-project.org) 2.10.0，用于更新，以 MIT 许可证发布；许可证随 App 附在 `Contents/Resources/Sparkle-LICENSE.txt`
- [highlight.js](https://highlightjs.org) 11.12.0，用于语法着色。Copyright (c) 2006, Ivan Sagalaev，以 BSD 3-Clause 许可证发布；许可证全文见 [`Sources/Spooky/HighlightJS/LICENSE`](Sources/Spooky/HighlightJS/LICENSE)，并随 App 一同分发
- [Octicons](https://primer.style/octicons) 19.43.0，用于 Pull Request 与 Merge Request 的状态图标。Copyright (c) 2026 GitHub Inc.，以 MIT 许可证发布；许可证全文见 [`Sources/Spooky/Octicons/LICENSE`](Sources/Spooky/Octicons/LICENSE)，并随 App 一同分发
- [swift-subprocess](https://github.com/swiftlang/swift-subprocess) 1.0.1，用于启动 Git 等子进程，以 Apache License 2.0 发布；许可证随 App 附在 `Contents/Resources/Subprocess-LICENSE.txt`
- [Inter](https://rsms.me/inter/) 4.001 与 [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) 2.004，用于宣传片的文字，以 SIL Open Font License 1.1 发布；许可证全文见 [`artifacts/promo/fonts/`](artifacts/promo/fonts/)
