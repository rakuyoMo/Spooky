# Spooky

macOS 原生 Git 客户端：既能打开本机的仓库，也能经 SSH 直接操作另一台机器上的仓库。

当前 App 支持本机与 SSH 服务器工作区：混合最近记录、连接体检、工作区状态、文件 / 块 / 行操作、Diff、提交与冲突收尾、分页历史、分支、获取、拉取、推送、发布分支与合并。
本机通过文件事件刷新，服务器沿用前后台轮询与断线重连。完整 `1.0.0` 按 M1–M10 连续交付。

## 目录

- `SpookyKit/Sources/SpookyKit/`：核心库，负责执行 Git、校验工作区并解析输出
- `SpookyKit/Sources/SpookyKit/Resources/spooky-remote.pl`：版本化远端进程包装器与回调客户端
- `SpookyKit/Sources/Spooky/`：AppKit 窗口与 SwiftUI 内容；`Resources/` 保存五种语言资源
- `SpookyKit/Tests/`：核心库、刷新生命周期、最近记录和本地化测试
- `scripts/build-app.sh`：生成开发 App Bundle
- [docs/testing/M1.md](docs/testing/M1.md)：本机 App 手动验收步骤
- [docs/testing/M2.md](docs/testing/M2.md)：服务器连接、终端、主题与回归验收
- [docs/testing/M3.md](docs/testing/M3.md)：工作区、补丁、提交、冲突与 SFTP 验收
- [docs/testing/M4.md](docs/testing/M4.md)：历史、分支、同步、活动日志与合并验收

## 构建、运行与测试

需要 macOS 26 或更高版本，以及 Swift 6.2 或更高版本。在仓库根目录执行：

```sh
swift build --package-path SpookyKit
swift test --package-path SpookyKit
swift build --package-path SpookyKit --product Spooky
swift run --package-path SpookyKit Spooky
```

App 启动后显示仓库管理，使用 ⌘O 选择本机工作区。⌘R 刷新，⌘1 / ⌘2 切换工作区和历史，⌃⌘R 回到仓库管理。
工具栏的 “关闭当前仓库” 返回管理界面；⌘W 关闭窗口，⌘Q 退出 App。

“添加服务器仓库” 位于管理页、底部 “+” 菜单及 File 菜单，输入 SSH 主机别名和远端绝对路径即可体检。标题、记录和复制路径都带主机前缀；Finder 仅对本机仓库启用。

⌘, 打开 Settings。General 选择已安装的 Terminal、iTerm、Warp、Ghostty、WezTerm、Prompt 或 Otty；Themes 预览内置 `Default`、`Default (Dark)`。App 跟随系统外观，两套主题均使用 Menlo-Regular 11 pt。

普通打开复用已有仓库窗口，或使用发起操作的窗口。最近记录中的 “在新窗口打开” 始终创建独立窗口。
刷新时保留已有数据；失败后显示错误原文并允许重试。失效的最近记录保持可见。

## 历史、分支与同步

History 使用列表与详情两栏，显示提交图、作者、日期和引用。默认每页 100 条，在 General 中可选 100 / 200 / 500 / 1000；滚动到底自动续载，加载时可取消。分页固定引用对应的哈希，新增提交不会让后续页重复或漏项。

选中提交显示完整信息、元信息与变更文件；展开文件时加载 Diff。合并提交统一比较第一父提交。⌘C 复制完整哈希，双击打开文件列表与 Diff 的整页详情。⌃⌘G 切换提交图，列表头菜单提供 24 / 46 pt 两档行高；⌃⌘→ / ⌃⌘← 展开 / 折叠变更集。

侧边栏按本地分支和远端分组。选择分支显示其历史，⌘0 定位 HEAD；选择有上游的本地分支时同时展示两侧历史和未推送 / 未拉取标记。双击检出，双击远端分支创建或使用本地跟踪分支。⌘B 新建分支，支持起点、跟踪与创建后检出；名称输入会自动规范化，确认前由 Git 校验。删除始终确认，未合并分支保留 Git 的普通删除保护。

工具栏、主菜单和右键提供 Fetch、Pull、Push、Merge。⇧⌘F / ⇧⌘P / ⇧⌘U / ⇧⌘M 分别打开参数表单；提交表单后关闭 sheet，活动区持续显示日志并允许取消。⌃⌘0 打开 Activity 查看进行中和已完成的操作，服务器日志保留主机上下文。

Fetch 支持全部远端、清理失效引用和获取全部标签。Pull 先使用 `fetch --porcelain --progress`，再显式 merge 或 rebase；Push 使用 porcelain、目标远端和目标分支，首次发布可设置 upstream。同一仓库的写操作串行，取消后重新读取实际状态，断线不重试写入。

Merge 在对话框中通过 `merge-tree --write-tree` 预览冲突；无法检查时显示未知状态。执行前再次检查工作区，冲突后沿用提交区的解决与中止流程。支持压缩、总是生成合并提交、直接提交、验证签名和跳过钩子的选项。

分支和提交可以拖到 Branches 标题新建分支；本地分支拖到 HEAD / Working Copy 合并，远端分支拖到 HEAD / Working Copy 拉取，本地分支拖到远端或远端分支发布 / 推送。动作均进入对应参数表单。

本机网络操作使用私有 Unix socket 回调输入凭据；SSH 私钥解锁后由 OpenSSH 加入当前 SSH agent。口令不会写入临时文件、操作日志或错误对象。服务器 Git 的认证沿用连接中继。

生成可由 Finder 打开的开发应用：

```sh
./scripts/build-app.sh
open SpookyKit/.build/Spooky.app
```

Bundle Identifier 固定为 `com.rakuyo.spooky`。界面跟随系统或 macOS 的应用单独语言设置，支持英文、简体中文、繁体中文、日文和韩文，其它语言回退英文。

## Git 要求

`1.0.0` 要求本机和服务器上的 Git 均为 `2.41.0` 或更高版本。该版本要求由产品使用的 `git fetch --porcelain` 确定；版本不足时，Spooky 会显示最低版本和更新方向，由用户负责更新 Git。

本机仓库默认使用 `/usr/bin/git`；服务器仓库使用 SSH 主机别名对应的服务器 Git。

打开本机仓库时先执行版本检查，版本不足时提示更新 Xcode 或命令行工具。仓库身份由 Git 返回的工作区根路径确定，子目录与符号链接会归一到同一工作区。

核心库的 `GitRunner.execute` 提供 stdout、stderr、退出状态、原始参数、取消标记与数据块回调；`GitRunner.operation` 提供操作事件流与主动取消。每个仓库的写操作串行，同一主机最多执行 8 条命令。
原有 `run(_:input:)` 继续返回 stdout。测试使用临时仓库，隔离用户全局 Git 配置。

## SSH 服务器仓库

使用系统 `/usr/bin/ssh` 和用户已有的主机别名。A 的认证由系统钥匙串或 SSH agent 提供，agent 转发默认关闭；未知或变化的指纹必须先在受信任终端中核实。

服务器需要 Git ≥ `2.41.0`、支持反向 Unix socket 转发的 OpenSSH，以及 `/usr/bin/perl` 的核心模块 `IO::Socket::UNIX`、`JSON::PP`、`POSIX`。B 侧 SSH 口令回调需要 OpenSSH ≥ `8.4` 的 `SSH_ASKPASS_REQUIRE=force`。无需 root 或常驻服务。

首次体检成功后，以当前用户权限原子安装 `~/.spooky/bin/spooky-remote-v1-<内容摘要>` 及 askpass 入口，目录和程序权限为 `0700`。A、B 的运行时目录均为私有 `/tmp/spooky-*`，控制 socket 和中继 socket 不进入仓库；关闭会话后清理运行时目录。版本化程序保留供连接使用。

每个工作区使用 Spooky 专属主连接，空闲 10 分钟退出。前台每 2 秒、后台每 10 秒轮询，重新激活立即刷新。断线保留旧快照，后台重连；中断的写操作不自动重试，重连后核对分支、状态、暂存区锁和进行中的合并 / 变基。

`RepositoryFiles` 使用系统 SFTP、复用当前主连接读写文件；传输经私有临时目录中继，取消只终止当前传输。远端路径不会交给本机文件 API。系统 SFTP 的批处理不能表示含 CR / LF 的路径，相关操作会明确报错。

工作区默认平铺，⌃⌘T / ⌃⌘L 切换树形 / 平铺。三态勾选框和空格切换暂存；⇧⌘E 全部暂存，⌥⇧⌘E 全部取消暂存。详情区分别显示 Staged / Unstaged，行号支持点选、拖选与 ⇧ 范围选择。

⇧⌘C 聚焦提交标题，编辑信息时 ⌘↩ 提交。提交信息经 stdin 传入并规范化为 NFC；修补最近提交需要确认。文件、块、行丢弃始终确认，服务器文案明确说明永久删除或覆盖。

Diff 警告阈值在 General 设置中调整，默认 `20,000 kB`（`1 kB = 1,000` 字节），按单次补丁字节数计算；`256 MiB` 为单次输出上限。Show Diff 只放行当前文件。补丁应用前重新核对文件与暂存区快照，变化时拒绝应用并刷新。

Git askpass、B 侧 SSH 私钥口令与编辑器请求只经当前主连接的反向 Unix socket 返回 A，使用随机会话令牌、一次性应答和 120 秒超时。凭据默认只在内存中，用户可选择存入 A 的钥匙串；输出中的凭据回显会被脱敏。

取消先关闭命令通道，再通知 B 上的包装器结束独立进程组：TERM 后等待 2 秒，再发 KILL 并确认退出。未能确认时明确报告，阻止继续写入直到重连核对。

远端自动测试默认跳过。已配置专用测试别名和密钥时显式运行：

```sh
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteConnectionTests
```

M3 远端提交与 SFTP 验收：

```sh
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteWorkingCopyTests
```

M4 服务器历史与同步验收：

```sh
SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteHistorySyncTests
```

测试只使用 `spooky-test` 和 `~/.ssh/spooky-test_ed25519`，每次在 `/Users/wgy/spooky-test/` 下新建并清理独立子目录。指纹和认证失败使用 A 上的临时配置构造，不修改双方 SSH 配置、known_hosts 或全局 Git 配置。

Warp 的服务器终端入口使用其 Launch Configuration 协议，临时配置写入 `~/.warp/launch_configurations/Spooky-*.yaml`；Prompt 使用会话临时 `.command` 文件。仅清理 Spooky 创建的文件。Prompt 的远端启动方式仍有待实测的 `#warning`，见 M2 验收记录。

## 协议

[GPL-3.0](LICENSE)
