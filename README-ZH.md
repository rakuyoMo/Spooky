<h1 align="center">Spooky</h1>

<div align="center">

[English](README.md) | 简体中文

macOS 原生 Git 客户端，本机仓库和服务器上的仓库都能直接操作。

</div>

> [!NOTE]
> Spooky 仍在开发中，尚未发布正式版本，目前只能从源码构建，功能和界面都可能调整。

## 简介

Spooky 既能打开本机的 Git 仓库，也能经 SSH 直接操作另一台机器上的仓库。

服务器仓库的工作区始终留在服务器上：Git 命令在服务器上执行，文件经 SFTP 读写，不需要把仓库克隆到本机。

连接使用系统自带的 SSH 和 `~/.ssh/config` 里的主机别名，认证、主机指纹和连接复用都交给 OpenSSH 处理。

## 功能

- **本机与服务器仓库**：两种仓库共用同一套界面，最近记录混合显示。服务器仓库的标题、记录和复制的路径都带主机前缀

- **连接检查与断线恢复**：添加服务器仓库时，先检查连接、Git 版本和运行环境。断线后保留上次读取的状态并在后台重连，恢复前禁止写入

- **自动刷新**：本机仓库随文件变化刷新；服务器仓库在前台每 2 秒、后台每 10 秒刷新一次。也可以随时手动刷新

- **按仓库记住视图**：每个窗口最多记住 15 个仓库的视图、选中项和提交信息草稿，切回仓库时恢复

- **错误说明**：错误会写明类别、所在仓库和 Git / SSH 的原始输出，原文可以选择复制

- **按文件、块、行暂存**：工作区支持平铺和树形显示、多选与三态勾选框。Diff 中可以按行选择，只暂存或丢弃选中的行

- **提交与冲突收尾**：支持修补最近一次提交。合并、变基、摘取或反转进行中时，可以采用 ours / theirs 版本、标记已解决，再继续或中止

- **历史**：分页加载，显示提交图、引用标记和领先 / 落后计数。合并提交显示与第一父提交之间的 Diff

- **分支**：新建、跟踪、检出和删除分支。输入名称时自动规范成有效的引用名

- **同步与合并**：获取、拉取、推送和首次发布分支；合并前先预览是否会冲突。所有操作的日志集中在 “活动” 窗口里，进行中的操作可以取消

- **拖放操作**：把分支或提交拖到侧边栏，就能新建分支、合并、拉取、发布或推送

- **在终端中打开**：支持 Terminal、iTerm、Warp、Ghostty、WezTerm、Prompt 和 Otty。服务器仓库会在终端里经 SSH 进入远端路径

- **默认主题**：内置 Default 与 Default (Dark)，随系统浅色、深色外观切换

- **支持八种语言**：英文、简体中文、繁体中文、日文、韩文、德文、法文和西班牙文，自动跟随系统语言。其它语言环境下显示英文

## 系统要求

- macOS 26 或更高版本
- 本机和服务器上的 Git 都需要 `2.41.0` 或更高版本，这个要求来自 Spooky 使用的 `git fetch --porcelain`
  - 本机仓库使用 `/usr/bin/git`，版本不足时，Spooky 会提示更新 Xcode 或命令行工具
  - 服务器仓库使用该主机上的 Git
- 服务器还需要：
  - 支持反向 Unix socket 转发的 OpenSSH
  - `/usr/bin/perl`，以及核心模块 `IO::Socket::UNIX`、`JSON::PP`、`POSIX`
  - 在服务器上输入 SSH 私钥口令时，OpenSSH 需要 `8.4` 或更高版本
  - 不需要 root 权限，也不安装常驻服务

## 从源码构建

Spooky 尚未提供下载，需要从源码构建。构建需要 Swift 6.2 或更高版本。

项目使用 Swift Package Manager 管理，命令都在仓库根目录执行：

```sh
# 编译核心库与 App
swift build

# 直接启动 App
swift run Spooky
```

也可以生成能在 Finder 中打开的开发版 App：

```sh
# 生成 .build/Spooky.app
./scripts/build-app.sh

# 启动生成的 App
open .build/Spooky.app
```

发布版 App 使用 release 构建，带应用图标，并做 ad-hoc 签名：

```sh
# 生成 build/Spooky.app
./scripts/bundle.sh
```

## 权限说明

### 自动化

终端程序选的是 Terminal 或 iTerm 时，Spooky 会通过 AppleScript 让它打开仓库。第一次使用时，macOS 会询问是否允许 Spooky 控制这个程序。

如果当时拒绝了，可以在 “系统设置 › 隐私与安全性 › 自动化” 里重新开启。

## 工作原理

### 服务器连接

- 每个服务器工作区使用 Spooky 专属的 SSH 主连接（ControlMaster），空闲 10 分钟后退出。Spooky 不会使用或关闭用户自己的其它 SSH 主连接
- 默认不转发 SSH agent。主机指纹未知或发生变化时，需要先在可信的终端里核实
- 首次连接检查通过后，Spooky 以当前用户的权限，在服务器的 `~/.spooky/bin/` 里安装一个按内容摘要命名的小程序，用来管理远端进程和回调。它依赖服务器自带的 Perl，不常驻运行
- 文件读写使用系统 SFTP，复用同一个主连接
  - 系统 SFTP 的批处理无法表示含 CR / LF 的路径，涉及这类路径的文件操作会明确报错
- 轮询只读取状态和所选文件的内容哈希，有变化时才读取其它内容；只由提交哈希决定的历史分页和提交详情会缓存起来，减少往返

### 写操作与断线

- 同一仓库的写操作排队依次执行；同一时间只有一个窗口能对它发起写操作，完成后显示这个仓库的窗口都会刷新
- 写操作中途断线时不会自动重试。重新连接后，Spooky 会先核对分支、工作区、暂存区锁，以及是否有进行中的合并或变基，说明 HEAD 是否已经变化，再允许写入
- 取消服务器上的操作时，Spooky 先关闭命令通道，再结束远端的整组进程：先发 TERM，2 秒后发 KILL，并确认进程已退出
  - 无法确认时会明确提示，重新连接核对之前不能继续写入

### 凭据

- 服务器上的 Git 需要密码、SSH 私钥口令或编辑器时，请求经当前主连接上的反向 Unix socket 回到本机，由 Spooky 弹窗处理
  - 每个请求都带随机的会话令牌，只能应答一次，120 秒后超时
- 本机仓库的网络操作同样通过私有的 Unix socket 回调输入凭据；SSH 私钥解锁后，由 OpenSSH 加入当前的 SSH agent
- 凭据默认只保存在内存中，勾选 “存入这台 Mac 的钥匙串” 后才写入本机钥匙串
- 凭据不会写入临时文件、活动日志或错误信息，输出中回显的凭据会被隐去

### 数据与对系统的改动

本机：

- 设置和最近记录保存在偏好设置域 `com.rakuyo.spooky`
- 存入钥匙串的凭据，服务名为 `com.rakuyo.spooky.remote.<主机别名>`
- 连接和回调使用私有的 `/tmp/spooky-*` 临时目录，关闭会话后清理
- 用 Warp 打开服务器仓库时，会在 `~/.warp/launch_configurations/` 写入 `Spooky-*.yaml`；用 Prompt 打开时使用临时的 `.command` 文件。退出 Spooky 时只清理它自己创建的这些文件

服务器：

- `~/.spooky/bin/`：远端程序与 askpass 入口，权限为 `0700`，会话结束后保留，供下次连接使用
- `/tmp/spooky-*`：会话期间的私有运行时目录，关闭会话后清理

## 开发

### 测试

```sh
swift test
```

- 测试使用 Swift Testing
- 涉及 Git 的测试在临时仓库中运行，不读取系统和用户的全局 Git 配置

服务器测试默认跳过，运行它们需要一台测试专用的服务器：

- `~/.ssh/config` 中配置了主机别名 `spooky-test`
- 使用密钥 `~/.ssh/spooky-test_ed25519` 认证
- 可以读写服务器上的 `/Users/wgy/spooky-test/`

准备好后，可以显式开启：

```sh
# 连接、连接检查、断线恢复与回调
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConnectionTests

# SFTP 与服务器提交
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteWorkingCopyTests

# 服务器历史、同步与取消
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistorySyncTests
```

每次运行只在这个目录下新建并清理独立的子目录，不修改双方的 SSH 配置、`known_hosts` 或全局 Git 配置。

大仓库的性能测试同样默认跳过。它会生成一个包含 10 万个文件、5 万个提交的临时仓库，检查首屏状态的读取时间与内存占用：

```sh
SPOOKY_PERFORMANCE_TESTS=1 swift test -c release -Xswiftc -enable-testing --filter PerformanceTests
```

## 参与贡献

- 提交 PR 前，请用 [mise](https://mise.jdx.dev) 运行 `mise run swift:lint`、`mise run build` 和 `mise run test`，确认都能通过；CI 会在每个 PR 上运行同样的检查
- 改动 App 时，还要实际启动 App，确认改动的效果
- 分支命名和提交信息等约定见 [AGENTS.md](AGENTS.md)
- 引入外部代码前，请先确认它的许可证与 GPL-3.0 兼容

## 许可证

Spooky 以 [GNU General Public License v3.0](LICENSE) 许可证发布。
