# 架构

Spooky 由两个 target 组成：

- 核心库 `SpookyKit`：在本机或服务器上执行 Git、读写仓库文件并解析输出
- App `Spooky`：AppKit 管理窗口、分栏、工具栏和菜单，SwiftUI 承载内容

下文的 A 指运行 Spooky 的 Mac，B 指服务器仓库所在的机器。

本文只写模块的划分与跨模块的设计；单个功能的实现细节写在对应代码的注释里。

## 模块

### SpookyKit

| 目录 | 职责 |
|---|---|
| `Execution/` | Git 命令执行、异步子进程与取消、命令结果与错误分类、仓库写队列、只读结果缓存 |
| `Remote/` | SSH 主连接、连接体检、断线重连与写入核对、远端取消、包装器安装、远端输出的解析与脱敏 |
| `Host/` | 仓库还不存在时在目标机器上的操作：列目录、检查目标路径、新建、克隆与扫描 |
| `Callback/` | 口令、密码、签名口令与编辑器的回调服务，以及本机 Git 的凭据回调 |
| `Environment/` | 本机执行 Git 时的程序与环境：Git 程序、登录 shell 的环境变量、SSH agent |
| `Configuration/` | 全局与仓库本地的 Git 配置 |
| `Repository/` | 仓库位置、本机仓库识别、文件读写、交给本机程序的文件副本、仓库概况 |
| `ExternalTools/` | 交给外部比较与合并工具、编辑器的文件，以及写回前的版本核对 |
| `WorkingCopy/` | 工作区状态、Diff 与选区补丁、暂存与丢弃、文件操作、冲突，以及提交的身份、签名与信息 |
| `History/` | 历史分页与查询、提交图、提交详情、签名校验、版本比较与导出、Reflog |
| `FileViews/` | 文件历史、Blame 与原文 |
| `References/` | 引用快照、分支、标签、远端、分支元数据与分支比较 |
| `Sync/` | Fetch、Pull、Push、Sync、合并与更新分支 |
| `Rewrite/` | 反转、摘取、重置、检出版本、变基与交互式变基 |
| `Undo/` | 撤销记录与恢复 |
| `Stash/` | 储藏与 Auto Stash |
| `Hosting/` | 托管服务的实例与账号、REST 接口、Pull Request 与 Merge Request |
| `Submodules/`、`Worktrees/`、`LFS/` | 子模块、工作树与 Git LFS |
| `Resources/` | 远端包装器 `spooky-remote.pl` |

### Spooky

| 目录 | 职责 |
|---|---|
| `App/` | 入口、窗口与菜单协调、本地化与错误说明、外观、命名色与文本区主题、链接解析 |
| `AppIcon/` | App 图标，随图标样式与连接状态切换 |
| `Components/` | 空状态、错误详情、连接状态、头像等共用视图 |
| `RepositoryManager/`、`Launch/`、`Clone/` | 仓库管理与书签、启动窗口，新建、克隆与扫描 |
| `RepositoryWindow/` | 仓库窗口与菜单动作、侧边栏、搜索、操作对话框与拖放 |
| `Navigation/` | 后退 / 前进记录、视图引用与窗口恢复 |
| `QuickActions/` | 快捷操作面板 |
| `Session/` | 仓库会话：状态与刷新、操作可用性、视图状态、文件监听与自动获取 |
| `WorkingCopy/`、`Diff/`、`Text/` | 工作区与提交区、Diff、文本渲染与语法着色 |
| `History/`、`FileViews/` | 历史与提交详情、文件历史、Blame 与原文 |
| `Sidebar/`、`References/`、`BranchesReview/` | 侧边栏、分支 / 标签 / 远端的管理、分支整理 |
| `Rewrite/`、`Reflog/`、`Undo/`、`Stash/` | 改写历史、Reflog、撤销与重做、储藏 |
| `Activity/` | Activity 窗口、操作记录与仓库写锁 |
| `ExternalTools/` | 外部比较与合并工具、Open With 与远程编辑 |
| `Settings/`、`RepositorySettings/` | 设置窗口与仓库设置 |
| `Accounts/`、`PullRequests/` | 托管账号、Pull Request 与 Merge Request |
| `Submodules/`、`Worktrees/`、`LFS/` | 子模块、工作树与 Git LFS 的视图与对话框 |
| `Help/` | Help 菜单、What's New、诊断报告与崩溃报告 |
| `Updates/` | Sparkle 更新器与更新通道 |
| `HighlightJS/` | 随 App 打包的 highlight.js 与它的许可证 |
| `Resources/` | 各语言文案、系统权限说明、命名色与内置主题 |

## Git 命令执行

- Git 调用一律经 `GitRunner`，本机与服务器仓库共用一套接口：
  - `run(_:input:)` 只返回 stdout；`execute(_:input:acceptedExitCodes:onOutput:)` 返回完整结果并提供流式数据块；`operation` 提供有界的进度事件流、完整结果与主动取消
  - `stream(_:to:)` 把导出、归档与补丁这类可能很大的输出边读边写进本机文件，不收进内存；失败或取消时删掉写了一半的文件
  - `immutableRun` 缓存只由对象哈希决定的读取，如历史分页、提交变更集与补丁、双向计数、指定提交的信息
  - 每条调用都带上 `--no-pager`、`--no-optional-locks`、`color.ui=never` 与 `core.quotepath=off`
- 本机执行 Settings → Git Config 所选的 Git 程序，默认 `/usr/bin/git`
  - `openLocalRepository()` 先检查最低版本 `2.41.0`，再由 Git 识别工作区根目录
  - Git 程序、登录 shell 与自定义环境变量、SSH agent 集中在 `LocalExecutionSettings.current`，作用于本机的每条 Git 调用
- 服务器仓库经 `/usr/bin/ssh` 在 B 上执行，用 B 自己的环境，Settings → Environment 只能检查
- 远端命令使用非交互模式：需要标准输入时（如 `commit -F -` 的提交信息）经 `input` 传入；交互式变基的提交序列与信息由内联在命令里的编辑器写入，在仓库所在的机器上运行

### 写操作

- 写命令经 `RepositoryOperationQueue` 按仓库串行；纯读取命令登记在 `RepositoryOperationQueue.isReadOnly`
- 组合操作用 `GitRunner.writeTransaction` 持有仓库锁
- 工作区的写入经 `WorkingCopyOperations` 发起：补丁以原始字节生成并核对快照，路径列表经字面 NUL 输入传递
- App 内同一仓库同时只允许一个写操作（`RepositoryWriteLocks`）；菜单、工具栏、右键菜单与拖放统一使用 `RepositorySession` 的 `can…` 可用性规则
- 写操作经 `RepositorySession.performGit(undo:)` 声明与撤销记录的关系：
  - `.reversible`：只改仓库自己的引用、索引、工作区、储藏与 `branch.*` 配置
  - `.irreversible`（默认）：改动远端、远端跟踪分支或其它配置
  - `.unrecorded`：自动获取这类不由用户直接发起的操作，以及撤销、重做本身
- 撤销的快照建在仓库所在的机器上，写进仓库自己的对象库；恢复前核对仓库仍与记录一致
- 移进废纸篓的文件不进快照：写操作期间由 `TrashLog` 记下它们在废纸篓里的位置，撤销时移回原处，重做时重新移进废纸篓；废纸篓程序不报告位置时这次操作不能撤销

## 服务器仓库

- 只通过 `~/.ssh/config` 中的主机别名访问；连接、认证、主机指纹与复用交给系统 SSH
- `RemoteConnection` 为每个工作区管理专属的 ControlMaster，空闲 10 分钟后退出
  - 控制与中继 socket 位于 `0700` 的会话目录
  - 不使用也不关闭用户的其它 SSH 主连接
- 远端包装器由资源 `spooky-remote.pl` 按内容摘要版本化，首次体检通过后原子安装到 B 的 `~/.spooky/bin`
  - 负责远端进程组、回调客户端与签名、校验程序的入口
  - 依赖 B 的系统 Perl 核心模块，不安装常驻服务
- 文件读写经 `RepositoryFiles`；SFTP 经 `RemoteConnection.sftpCommand()` 接入同一主连接，读、写分别遵循主机并发与仓库写队列
- 删除文件与丢弃未跟踪文件移进 B 的废纸篓：连接体检找出 B 上的程序，macOS 用系统自带的 `/usr/bin/trash`，Linux 依次找 `gio` 与 `trash-put`；都找不到时界面先确认，再永久删除
- 服务器仓库里删除或覆盖文件前的确认都可以勾选不再提醒，Settings → General 逐项列出
- 刷新：
  - 服务器仓库按 `RemoteConnection` 的常量轮询，前台 2 秒、后台 10 秒；只读 status 与所选文件的内容哈希，有变化才读取身份、引用、历史与 Diff
  - 本机仓库由 `RepositoryFileMonitor` 的递归 FSEvents 触发刷新
  - 写入完成、重连、窗口重新激活与手动刷新执行完整刷新
- 断线：保留上次读取的状态并在后台重连；写入中途断线时不重试，重连后先核对分支、工作区、暂存区锁、远端跟踪分支与进行中的合并或变基，再允许写入
- 取消：先关闭命令通道，再由包装器结束远端的整组进程，发 TERM、2 秒后发 KILL，并确认进程已退出；没能确认时，重连核对之前不能写入
- 新建、克隆、扫描与目录浏览在仓库存在之前进行：
  - 服务器经 `RemoteConnection.host(_:)` 的主机连接在 B 上执行，App 先用 `RemoteConnection.presentingHost(_:)` 装上询问凭据的处理器
  - 本机与服务器执行同一份脚本，扫描只在用户选定的目录里进行

## 凭据、签名与回调

- 口令、密码、签名口令与编辑器的请求经 `CallbackRelay` 回到 A：服务器仓库经当前主连接上的反向 Unix socket，本机仓库经私有的 Unix socket
  - 每个请求带会话令牌，只能应答一次，120 秒后超时
  - 凭据不进入记录、日志或错误对象；用户选择保存时只写 A 的钥匙串
- 不由用户直接发起的操作（如自动获取）放在 `RemoteCallbackRequest.$allowsInteraction.withValue(false)` 里执行：回调只用钥匙串里已存的凭据，取不到按取消处理，不弹出输入框
- 签名：
  - 本机会生成提交的命令（`commit`、`merge`、`rebase`、`cherry-pick`、`revert`）经 `LocalGitAuthentication` 执行：SSH 签名的私钥口令经回调询问，GPG 交给本机的 pinentry
  - 服务器仓库在 B 上签名：经包装器的 `-gpg`、`-ssh-keygen` 入口接入中继，仍执行仓库配置的签名程序；gpg 以 loopback 模式运行，只在确实需要口令时询问
  - 身份档案的签名密钥由 `SigningKeys.local` 从 A 的 gpg 钥匙环与 SSH agent 列出；服务器仓库要在 B 上有同一把密钥
- 校验签名一律经 `SignatureVerification.run`：服务器仓库用包装器的 `-gpg` 入口，本机仓库为这次校验临时放一份包装器；包装器给 `--verify` 加上 `--no-auto-key-retrieve --no-auto-check-trustdb`，校验不访问网络

## 文件与外部工具

- 交给 Quick Look、默认程序、比较工具或拖出的文件一律经 `RepositoryFileCache`
  - 本机工作区文件用原路径；服务器文件与历史版本写进会话专属的 `0700` 缓存目录，只保留文件名，关闭仓库时删除
  - 远端路径不交给本机文件 API
- 服务器仓库不在 B 上运行 difftool / mergetool：两侧内容经 `ExternalToolFiles` 取到缓存目录，在 A 上启动工具；合并结果经 SFTP 写回后再 `git add`
- 编辑器副本（`EditingCopy`）写回前核对 B 上的版本，不一致时询问是否覆盖

## 托管服务

- 接口一律经 `HostingClient` 从 A 发起
  - 令牌只放在请求头：GitHub 用 `Authorization: Bearer`，GitLab 用 `PRIVATE-TOKEN`
  - 请求不用 URLCache 里的旧响应；失败按 `HostingError` 分类并保留服务端原文
- 令牌只存在钥匙串，服务名 `com.rakuyo.spooky.hosting.<实例网页地址>`，账户名是账号 UUID
- 请求的提交与改动在仓库所在的机器上比较：源分支提交不在仓库里时，从目标远端的 `refs/pull/<编号>/head`（GitLab 是 `refs/merge-requests/<编号>/head`）取到 `FETCH_HEAD`；合并时带上源分支提交让服务端核对，合并后在仓库所在的机器上获取目标远端

## 仓库管理与系统集成

- 仓库书签由 `RepositoryBookmarks` 存在偏好里，全部窗口共用；打开成功的仓库自动加入书签，失效只做标记，从不自动删除
- 仓库设置只写仓库本地配置（`GitRunner.setLocalConfig`）
- 本地分支的置顶、归档、父分支与分支整理标记由 `BranchMetadata` 写在 `branch.<名称>.spooky-*`，改名时随段移动，删除分支时随段清除
- `ViewReference` 是窗口里一个可以回到的视图，同时用于后退 / 前进、窗口恢复与 `spooky://` 链接；新增主视图时三处一起覆盖
- 链接：
  - `spooky://open?repository=<位置>` 可带 `view`、`branch` 或 `commit`；服务器仓库的位置写 `<主机别名>:<远端路径>`
  - `spooky://clone?url=<地址>`
  - github.com 的 “Open with Desktop” 链接只接受 github.com 的 https 仓库网址
  - 解析不了的链接只显示错误，不执行任何动作
- 诊断报告与崩溃报告离开本机前经 `DiagnosticRedactor` 脱敏；崩溃报告只打开预填的 GitHub 新问题页，由用户自己提交
- `UpdateController` 按 Settings → Updates 的通道接收更新清单里的条目，只接受 EdDSA 签名的清单与更新包；`swift run` 时更新器不启动

## 文本区

- 主题：
  - 一个主题一个 `.spookytheme` JSON，放在 `~/Library/Application Support/Spooky/Themes`
  - App 启动时由 `ThemeStore.installDefaultThemes()` 从 `BuiltinThemes.json` 写入 Default 与 Default (Dark)：只在文件缺少或无法加载、且名称没被别的主题占用时写
  - 浅色与深色外观各选一个主题；找不到时按名称回退到 Default 或 Default (Dark)，再退到 `BuiltinThemes.json` 里的版本
  - Diff、原文、Blame 与主题示例取主题一律用 `TextTheme.current(dark:)`；在 SwiftUI 的 `body` 里调用，即随主题的编辑、切换与外观变化刷新
- 语法着色、Tab 宽度与不可见字符的偏好集中在 `TextPreferences`；一行文本按 `TextStyle` 经 `TextLineRenderer` 渲染
- 提交详情、储藏详情与文件历史的只读 Diff 共用 `ReadOnlyFileDiffView`
- 语法着色经 `SyntaxHighlighter` 借用 highlight.js 的上下文执行
  - 最多两份上下文，每份是一个 `HighlightRuntime` actor，只在自己的串行队列上使用，由全局 actor `SyntaxActor` 负责借还
  - 一份被已取消的长任务占着时，新的请求由另一份接手
