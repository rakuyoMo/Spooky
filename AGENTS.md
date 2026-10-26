# AGENTS.md

本文件是协作 Agent（Claude Code、Codex 等）在本仓库工作时的指引，同时也是人类阅读的协作规范源。

## 项目概述

Spooky 是一个原生 macOS Git 客户端：既能打开本机仓库，也能经 SSH 直接操作另一台机器上的仓库。

- `Spooky` 是可运行的桌面 App；`SpookyKit` 核心库负责在本机或远端执行 Git、读取工作区状态并解析输出
- 当前 App 支持以下能力，并可打包发布用 App；产品按 M1–M10 逐步完成 `1.0.0`
  - 本机与服务器工作区、连接体检与环境提示、断线重连与写入核对
  - 仓库书签的文件夹、排序与详情；本机与服务器上的新建、后台克隆与最近克隆、目录扫描与服务器目录浏览
  - 标签页、窗口恢复、启动窗口、后退 / 前进、快捷操作面板与工具栏自定义
  - 工作区的三种显示模式、忽略规则与文件操作；带显示选项、语法着色、行内高亮与图片对照的 Diff；文件 / 块 / 行操作
  - 提交信息编辑、身份档案与提交签名；冲突向导与冲突收尾；储藏与 Auto Stash
  - 分页历史的组合搜索、排序分组与视图设置；提交详情的文件树、签名与合并 Diff 方式；版本比较、导出与保存补丁；文件历史、Blame 与原文
  - 侧边栏的文件夹、过滤、置顶与归档、标签分组与分支状态；分支、标签、远端与父分支的管理
  - 完整的 Fetch / Pull / Push、Sync、安全强推、Push To 与自动获取；合并预览与 Activity
  - 反转、摘取、重置、检出版本、变基到别处与交互式变基；Branches Review 与自动归档；Reflog 与按仓库的撤销、重做
  - 文件监听与轮询刷新、按仓库恢复的视图状态、终端程序与文本区主题管理
  - 外部比较与合并工具、Open With 与编辑器副本回写；`spooky://` 链接与 github.com 仓库链接
  - 完整的设置页与仓库设置；Help 菜单、诊断报告与崩溃报告；Sparkle 自动更新与发布流程
  - github.com、GitLab.com 与私有部署 GitLab 的托管账号；Pull Request 与 Merge Request 的列表、详情、新建、修改、评论、关闭、合并与检出；发布仓库；提交信息的 Issue 编号补全；分支整理的请求状态与服务端合并识别
  - 子模块的增删改移、更新与修复；工作树的新建、打开、移动、修复与删除；Git LFS 的启用、跟踪规则与对象传输
- 远端仓库的工作区留在远端机器，客户端经系统 SSH、用 `~/.ssh/config` 中的主机别名访问
- 纯开源的个人工具，只在 GitHub 分发
- 许可证为 [GPL-3.0](LICENSE)
  - 引入外部代码前先确认许可证与 GPL-3.0 兼容，并保留所需的版权与许可声明

## 技术栈与环境

- Swift 6.2，工程由 Swift Package Manager 管理
- 包的最低平台为 macOS 26，定义于 `Package.swift`
- Git 子进程通过 [swift-subprocess](https://github.com/swiftlang/swift-subprocess) 启动
- 自动更新使用 [Sparkle 2](https://github.com/sparkle-project/Sparkle)，以 MIT 许可证随 App 分发，许可证随发布 Bundle 附在 `Contents/Resources/Sparkle-LICENSE.txt`
- 单元测试使用 Swift Testing（`import Testing`），不使用 XCTest
- `Spooky` executable target 使用 AppKit 管理窗口、分栏、工具栏和菜单，SwiftUI 承载内容
- App 的 Bundle Identifier 为 `com.rakuyo.spooky`；`Info.plist` 嵌入可执行文件，开发 Bundle 由 `scripts/build-app.sh` 生成，发布 Bundle 由 `scripts/bundle.sh` 生成
- 界面资源位于 `Sources/Spooky/Resources/`，支持 `en`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`de`、`fr`、`es`，默认跟随系统并以英文回退

### `mise`

根目录的 `mise.toml` 定义构建、测试、打包与代码规范检查的 task，这些操作优先经 `mise run` 执行。

- 没有对应 task 的 Swift 命令直接执行
- 纯 shell 命令不经 `mise` 执行
- 本机专用的配置写进 `mise.local.toml`（已列入 `.gitignore`）

## 常用命令

命令都在仓库根目录执行，不切换工作目录。

| 命令 | 作用 |
|---|---|
| `mise run build` | 编译核心库与 App |
| `mise run test` | 运行核心库、会话状态与本地化测试 |
| `mise run swift:lint` | 检查代码规范 |
| `mise run swift:format` | 按代码规范格式化，并自动修复可修复的问题 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConnectionTests` | 显式运行 `spooky-test` 远端集成测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteWorkingCopyTests` | 显式运行 M3 的 SFTP 与远端提交测试，以及 M6 的服务器文件缓存测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistorySyncTests` | 显式运行 M4 的服务器历史、同步与取消测试，以及 M7 的 Sync、变基、安全强推、Push To 与不询问用户的获取测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteWorkingCopyFilesTests` | 显式运行 M6 的服务器文件操作与应用补丁测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteDiffTests` | 显式运行 M6 的服务器 Diff 选项与图片测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteStashTests` | 显式运行 M6 的服务器储藏与 Auto Stash 断线测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConflictTests` | 显式运行 M6 的服务器冲突向导与断线测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteFileViewsTests` | 显式运行 M6 的服务器文件历史、Blame、原文与 NFD 路径测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteCommitSigningTests` | 显式运行 M6 的服务器提交签名测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistorySearchTests` | 显式运行 M7 的服务器历史搜索、计数与可达性测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHistoryDetailsTests` | 显式运行 M7 的服务器合并 Diff、文件树、比较、签名与导出测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteSidebarTests` | 显式运行 M7 的服务器标签说明、分支状态、置顶归档与标签检出测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteReferenceManagementTests` | 显式运行 M7 的服务器分支、标签与远端管理测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteRewriteTests` | 显式运行 M7 的服务器反转、摘取、重置与交互式变基测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteBranchesReviewTests` | 显式运行 M7 的服务器分支比较、分叉点、归档标记与 Update Branch 测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteReflogUndoTests` | 显式运行 M7 的服务器 Reflog 与撤销、重做测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteHostOperationsTests` | 显式运行 M8 的服务器列目录、新建、扫描与克隆测试 |
| `SPOOKY_GITHUB_TESTS=1 SPOOKY_GITHUB_TOKEN=<令牌> SPOOKY_GITHUB_REPOSITORY=<owner/repo> swift test --filter GitHubLiveTests` | 显式运行 M9 在 github.com 测试仓库上的 Pull Request 新建、评论、修改、检出、合并与关闭测试 |
| `swift build --product Spooky` | 编译可执行 App product |
| `swift run Spooky` | 启动 App 的仓库管理窗口 |
| `./scripts/build-app.sh` | 生成开发用 `.build/Spooky.app` |
| `mise run bundle` | release 构建并生成 `build/Spooky.app`，拷贝资源、图标与更新框架后由内向外 ad-hoc 签名并校验 |
| `mise run release X.Y.Z [通道]` | 检查通过后切出发布分支、写入版本号与构建号并开 release PR，见 “发布流程” |
| `mise run appcast <通道> [<上一份更新清单>]` | 把 `build/Spooky.app` 压缩成更新包，在 `build/updates/` 生成签名的更新清单 |
| `SPOOKY_PERFORMANCE_TESTS=1 swift test -c release -Xswiftc -enable-testing --filter PerformanceTests` | 显式运行大仓库首屏、历史分页与内存的性能验收 |
| `swift scripts/make-icon.swift Sources/Spooky/AppIcon` | 重新生成全部四份应用图标 |

## 目录结构

```
Package.swift                 Swift Package 定义与平台、依赖配置
Package.resolved              依赖版本锁定
Sources/SpookyKit/            库源码，按功能分目录
  Execution/                  Git 命令执行
    GitRunner.swift           本机 / 远端 Git 命令执行
    CommandExecutor.swift     异步子进程、管道收集与取消
    GitCommandResult.swift    命令结果、错误分类与流式输出事件
    RepositoryOperationQueue.swift 仓库写队列、主机并发限制与操作事件
    ImmutableReadCache.swift  只由对象哈希决定的读取结果缓存
  Remote/                     服务器连接
    RemoteConnection.swift    SSH 主连接、体检、重连与远端取消
    RemoteConnection+HealthCheck.swift 经主连接依次检查远端 Git、路径权限、工作区与状态格式
    RemoteConnection+Wrapper.swift 包装器的安装脚本，以及凭据、编辑器、SSH 与签名程序的远端回调配置
    RemoteConnectionError.swift 连接分类与服务器仓库身份
    RemoteOutputFilter.swift  远端完成帧与退出状态解析
    RemoteOutputRedactor.swift 中继凭据的跨输出块脱敏
    SSHConfiguration.swift    SSH 参数及远端环境清洗
    RemoteConnection+Host.swift 不绑定仓库的主机连接，新建、克隆、扫描与目录浏览在仓库存在之前使用
    RemoteConnection+Recovery.swift 写入中断后重连时核对仓库的事实
    RemoteConnectionState.swift 连接状态
    RemoteHostEnvironment.swift 体检读到的 B 端非交互环境：主目录、PATH、Git 与 GIT_ 变量名
  Host/                       仓库还不存在时在目标机器上的操作，本机与服务器执行同一份脚本
    HostDirectories.swift     列出子目录与检查目标路径，服务器经主机连接在 B 上执行
    HostExecution.swift       在目标机器上执行 Git 以外的程序
    HostOperationError.swift  目标路径与环境不能使用的原因
    RepositoryCreation.swift  在本机或服务器上 git init
    RepositoryClone.swift     后台克隆、LFS 与子模块选项，以及从地址取仓库名
    CloneProgress.swift       从 stderr 解析的克隆进度
    RepositoryScan.swift      只在选定目录里用 find 寻找仓库，结果流式返回
  Configuration/              全局与仓库本地配置
    GlobalGitConfiguration.swift 本机全局配置里的身份、签名与 Issue 追踪
    RepositorySettings.swift  仓库设置读写的本地配置，以及忽略、排除与 LFS 跟踪规则
    ConfigRecords.swift       config -z --get-regexp 输出的解析
  Environment/                本机执行 Git 时的程序与环境
    LocalExecutionSettings.swift 所选的 Git 程序、登录 shell 与自定义变量、SSH agent，作用于本机的每条 Git 调用
    LoginShellEnvironment.swift 从登录 shell 读出环境变量
    SSHAgent.swift            系统与 1Password 的 SSH agent
    GitProgram.swift          本机可选的 Git 程序
  ExternalTools/              交给本机外部工具的文件
    ExternalToolFiles.swift   比较两侧的文件：工作区、暂存区、提交与对象
    MergeToolFiles.swift      合并工具的三方文件与结果写回
    EditingCopy.swift         服务器文件的编辑器副本与写回前的版本核对
  Callback/                   口令、密码、签名口令与编辑器回调
    CallbackRelay.swift       本机 Unix socket 回调服务，请求标明发起的操作能否询问用户
    LocalGitAuthentication.swift 本机凭据与 SSH 签名口令回调、SSH agent 接入
  Repository/                 仓库位置与文件读写
    RepositoryLocation.swift  本机或 SSH 远端仓库位置
    LocalRepository.swift     Git 最低版本检查与本机工作区识别
    RepositoryFiles.swift     本机文件访问与复用主连接的 SFTP 传输
    RepositoryFileCache.swift 交给本机程序的文件副本，位于会话专属的 0700 缓存目录，关闭仓库时删除
    RepositorySummary.swift   仓库管理详情的概况：分支、最后提交、提交人、描述与远端
  Submodules/                 子模块
    Submodule.swift           子模块模型：路径、名称、两处配置、指针、检出的版本与问题
    RepositorySubmodules.swift 子模块清单的并发读取与本地改动数
    RepositorySubmodules+Parsing.swift .gitmodules、本地配置、gitlink 与 submodule status 的解析，相对地址的换算
    RepositorySubmodules+Operations.swift 添加、初始化、更新、同步、获取、检出版本、改地址与选项
    RepositorySubmodules+Structure.swift 移动、改名、删除与修复配置不完整的子模块
  Worktrees/                  工作树
    Worktree.swift            工作树模型与 worktree list --porcelain -z 的解析
    RepositoryWorktrees.swift 清单、新建、移动、修复与删除
  LFS/                        Git LFS
    RepositoryLFS.swift       可用性与版本、仓库本地启用、跟踪规则、LFS 对象的获取、拉取与推送
  Hosting/                    托管服务：账号、接口与请求
    HostingInstance.swift     github.com、GitLab.com 与私有部署 GitLab 的实例，远端地址到项目路径的对应
    HostingAccount.swift      托管账号、认证方式与令牌对应的用户
    HostingClient.swift       REST 接口的请求、分页与失败分类，令牌只放在请求头
    HostingClient+PullRequests.swift Pull Request 与 Merge Request 的列表、详情、评论、新建、修改、关闭、合并选项与合并
    HostingClient+GitHub.swift github.com 的接口与响应
    HostingClient+GitLab.swift GitLab 的接口与响应
    HostingClient+Repositories.swift 发布仓库用到的所有者、是否已存在与新建仓库
    HostingClient+Issues.swift 提交信息补全用到的打开着的 Issue
    HostingError.swift        托管服务失败的分类
    GitHubDeviceFlow.swift    github.com 的设备授权
    PullRequest.swift         请求、评论、合并方式、合并选项与不能合并的原因
    RepositoryPullRequests.swift 请求在仓库所在机器上的 Git 动作：取回源分支提交、比较基准与检出
  WorkingCopy/                工作区状态、Diff、文件操作、冲突与提交
    WorkingCopyStatus.swift   porcelain v2 工作区状态模型与解析
    WorkingTreeFiles.swift    暂存区清单与被忽略文件清单
    RepositoryDiff.swift      Diff 显示选项、按字节解析 Diff 与生成选区补丁
    RepositoryDiff+Combined.swift 合并提交的组合 Diff 解析，只读显示时折成单列
    InlineDiff.swift          块内修改行的单词级比较，标出成对的删除行与新增行中改动的部分
    DiffImageSource.swift     图片 Diff 两侧的字节
    WorkingCopyOperations.swift 工作区写操作、快照校验、身份与进行中状态
    WorkingCopyOperations+Diff.swift 按显示选项读取补丁与忽略空白时的写入补丁
    WorkingCopyFileOperations.swift 停止跟踪、删除、移动、assume-unchanged、忽略 / 排除规则与应用补丁
    PatchPreimage.swift       补丁文件头的前像读取
    MergeConflict.swift       冲突的三方内容、恢复、采用两侧与手动编辑的识别
    OperationProgress.swift   进行中操作的两侧、步数、已解决冲突与空步骤继续
    CommitConfiguration.swift 提交身份、签名、注释字符与钩子的读取，身份档案的写入
    SigningKeys.swift         本机 gpg 钥匙环与 SSH agent 中可用于提交签名的密钥
    CommitMessage.swift       提交信息的拼接、注释行与按字数折行
  History/                    历史、提交详情与引用日志
    RepositoryHistory.swift   NUL 历史分页、提交变更集与按合并 Diff 方式读取的补丁
    RepositoryHistory+Query.swift 按查询分页与计数、按哈希前缀查找与可达性判断
    HistoryQuery.swift        历史搜索的条件、排序方式与第一父
    CommitGraph.swift         与界面解耦的增量提交图
    MergeDiffMode.swift       合并提交的三种 Diff 方式
    CommitSignature.swift     提交与标签的签名校验结果
    SignatureVerification.swift 经包装器的 gpg 入口校验签名，关闭自动取钥与信任库检查
    RevisionComparison.swift  两个版本之间的提交与改动
    RevisionExport.swift      导出文件、归档与保存补丁，输出边读边写进本机文件
    RepositoryReflog.swift    reflog 的分页、按说明搜索与把分支恢复到某条记录
  FileViews/                  文件历史、Blame 与原文
    RepositoryFileViews.swift 文件历史分页与筛选、树条目、Unicode 等价路径、原文、Blame 与贡献者
    FileBlame.swift           blame --porcelain 解析
  References/                 引用、分支、标签与远端
    RepositoryReferences.swift 引用快照、分支读写与双向计数
    RepositoryReferences+Branches.swift 快进、上游、改名、删除与远端分支的改名、删除
    ReferenceNames.swift      分支、标签、远端名、refspec 与远端地址的校验
    BranchMetadata.swift      写在 branch.<名称> 段的置顶、归档、父分支与分支整理标记
    BranchCondition.swift     完全合并、陈旧与跟踪错误的判断，以及基准分支名单
    BranchComparison.swift    分支与基准分支的双向计数与合并预览
    RepositoryTags.swift      标签的新建、签名、推送与删除
    RepositoryRemotes.swift   远端的增删改名、地址、refspec、自动获取排除项与网页地址
  Sync/                       同步与合并
    RepositorySync.swift      Fetch、Pull、Push、合并与预览
    RepositorySync+Push.swift 安全强推的核对与推送任意版本
    RepositorySync+Rebase.swift Sync 的三个步骤与变基当前分支
    RepositorySync+UpdateBranch.swift 把父分支的新提交合并或变基进本地分支
  Rewrite/                    改写历史
    RepositoryRewrite.swift   反转、摘取、重置、检出版本与变基到别处
    RepositoryRewrite+Interactive.swift 交互式变基的计划与执行
    RepositoryRewrite+Execution.swift 交互式变基的内联编辑器参数与已推送、已并入提交的判断
    RepositoryRewrite+FilePick.swift 只把提交里的一个文件套用到工作区
    RewritePlan.swift         交互式变基的动作、计划与 todo 指令
  Undo/                       撤销与重做
    RepositoryState.swift     撤销记录的仓库状态与拒绝恢复的原因
    RepositoryUndo.swift      记录状态，核对现状后恢复成另一份记录
    RepositoryUndo+Files.swift 恢复工作区时对未跟踪文件的处理
  Stash/                      储藏
    StashEntry.swift          储藏记录与 stash list -z 解析
    RepositoryStashes.swift   储藏读写、快照、单文件应用与 Auto Stash
  Resources/spooky-remote.pl  远端进程组、回调客户端与签名、校验程序入口
Sources/Spooky/               App 入口、窗口协调、会话状态与各内容视图，按功能分目录
  App/                        入口、窗口与菜单协调、本地化与错误说明、命名色与主题、提交日期格式、回调请求呈现
    SpookyURL.swift           spooky:// 链接与 github.com 仓库链接的解析
    AppAppearance.swift       App 的浅色、深色或跟随系统外观
    TextTheme.swift           文本区主题模型、资源里的默认主题与 .spookytheme 主题文件格式
    ThemeStore.swift          主题目录、启动时写入默认主题、浅色与深色外观的主题选择与导入
    CommitDateFormat.swift    提交日期的绝对与相对两种写法，历史、储藏、文件历史、版本比较与 Reflog 共用
  AppIcon/                    Dock 与 ⌘Tab 中的 App 图标随 “图标与小组件样式” 与连接状态切换，以及四份 icns
    AppIcon.icns              默认应用图标，指示灯灭着；与下面三份一样由 scripts/make-icon.swift 生成
    AppIconConnected.icns     指示灯亮着的默认图标，App 连着服务器时换到 Dock 与 ⌘Tab
    AppIconDark.icns          深色应用图标，指示灯灭着；App 运行时按 “图标与小组件样式” 换到 Dock 与 ⌘Tab
    AppIconDarkConnected.icns 指示灯亮着的深色图标
  Components/                 空状态、错误详情、连接状态、头像与版本组合框等共用视图
    AvatarStore.swift         按邮箱的 SHA-256 向 Gravatar 读取作者头像，只在内存里缓存，取不到时用首字母
  RepositoryManager/          仓库管理：书签树与文件夹、详情、拖放页，新建本机仓库、添加服务器仓库与它们的对话框
    RepositoryBookmarks.swift 全部窗口共用的书签、最近打开时间与失效标记，从旧版本的最近记录迁移
  Launch/                     启动窗口：最近打开的仓库与打开入口
  Navigation/                 后退 / 前进记录、视图引用与窗口恢复
    ViewReference.swift       窗口里一个可以回到的视图，后退 / 前进、窗口恢复与 spooky:// 链接共用
  Clone/                      克隆对话框、后台克隆与最近克隆、克隆进度、目录扫描，以及选择本机或服务器目录、浏览服务器目录
  QuickActions/               快捷操作面板：对象与动作、模糊匹配与执行
  ExternalTools/              外部比较与合并工具、Open With 菜单与远程编辑
  RepositorySettings/         仓库设置的 General、Git LFS、Ignores 与 Excludes 四段
  Accounts/                   Settings → Accounts 页、添加与重新认证账号的对话框、账号列表与钥匙串里的令牌
  PullRequests/               请求视图的列表、详情、讨论与对话框，远端到账号与项目的对应与手动关联，发布仓库的对话框
  Submodules/                 子模块详情、对话框与请求，以及它的状态
  Worktrees/                  工作树详情、对话框与请求，以及它的状态
  LFS/                        LFS 对象获取、拉取与推送的对话框
  Help/                       Help 菜单的链接、What's New 窗口、诊断报告、崩溃报告与它们共用的脱敏
  RepositoryWindow/           仓库窗口与菜单动作、侧边栏、搜索、操作与同步对话框、导出与比较对话框、拖放
    SyncDialog.swift          Sync、变基、安全强推与推送任意版本的对话框
    RepositoryOperationDrop.swift 提交、文件、分支与标签拖到侧边栏时的摘取、反转、变基、新建标签、改名与发布
  Session/                    仓库会话、操作可用性、视图状态、文件监听与自动获取，各功能的会话动作分在扩展文件中
    RepositoryAutoFetch.swift 按设置的间隔获取窗口里仓库的全部远端，只在前台进行，不询问凭据
  WorkingCopy/                工作区文件列表与显示模式、文件状态、Quick Look 与拖出、文件操作对话框、冲突向导与进行中操作横幅、提交区的信息编辑器、自动补全与身份菜单
    CommitBodyResizeHandle.swift 提交信息正文的拖柄：改正文高度，并移动工作区列表右侧的分隔线
    CommitCommentsDialog.swift 提交信息含注释行时的询问 sheet
  Diff/                       工作区 Diff、块与行选择、行内高亮、底栏选项、图片对照、语法着色的两侧全文，以及提交 / 储藏 / 文件历史共用的只读 Diff
  Text/                       语法着色、一行文本的渲染、Settings → Text 的偏好
    SyntaxHighlighter.swift   按路径与内容识别语言，把 highlight.js 的记号映射到主题颜色，并借还 highlight.js 的上下文
    HighlightRuntime.swift    一份载入 highlight.js 的 JavaScriptCore 上下文，只在自己的串行队列上使用
    HighlightMarkup.swift     把 highlight.js 输出的 HTML 还原成每行的语法片段
  History/                    历史列表与搜索过滤面板、视图设置、提交详情与文件树、签名、版本比较、与基准分支比较与提示条、右键菜单与列表内拖放
  Sidebar/                    侧边栏的引用树、分支行与徽标、过滤框、视图设置菜单，以及同步与归档的右键菜单
    SidebarPreferences.swift  侧边栏视图设置的偏好键与默认值，所有仓库窗口共用
  References/                 分支、标签与远端管理的对话框、右键菜单与远端设置视图
  Rewrite/                    反转、摘取、重置、检出版本、变基到别处、改信息与交互式变基确认的对话框
  BranchesReview/             分支整理的列表与详情、批量归档与自动归档
  Reflog/                     Reflog 视图与它的读取状态
  Undo/                       按仓库共用的撤销栈，以及交给 Edit 菜单的撤销管理器
  FileViews/                  文件历史、原文与 Blame 的整页视图、行号与注释栏、版本与文件选择器
    ContributorCompletion.swift 文件历史与历史搜索的补全：在输入框下方列出作者或文件路径的建议
  Stash/                      储藏视图、储藏对话框、拖放与状态
  Activity/                   Activity 窗口、操作记录与仓库写锁
  Updates/                    Sparkle 更新器、更新通道与 Settings → Updates 页；更新失败时显示原始错误
  Settings/                   设置窗口的 General、Appearance、Git Config、Text、Editor、Themes、User Profiles、Accounts、Integration 与 Environment 页，以及终端程序与本机执行偏好
    SettingsPage.swift        页签与顺序
    AddUserProfileDialog.swift 把当前身份存成身份档案的 sheet
  HighlightJS/                随 App 打包的 highlight.js 11.12.0，原样拷入并保持目录结构
    highlight.min.js          核心与常用语言
    languages/                其余语言，每种一个 .min.js
    LICENSE                   highlight.js 的 BSD-3-Clause 许可证
  Resources/                  各语言文案、系统权限说明、命名色与默认主题
    BuiltinThemes.json        Default 与 Default (Dark)，启动时写入主题目录，也是主题的最后回退
  Info.plist                  应用身份和支持语言
Tests/SpookyKitTests/         单元测试（Swift Testing）
  Fixtures/                   固定的 Git 输出夹具
Tests/SpookyTests/            会话生命周期、书签、错误呈现、本地化、App 图标、主题存储、语法着色与提交补全测试，历史、侧边栏、引用、改写、分支整理、Reflog、撤销与操作接线的会话测试，以及窗口、导航、快捷操作、克隆、链接、设置与帮助的测试
Tests/ReleaseTests/           发布检查、发版脚本与更新清单合成的测试，在临时仓库与临时目录里运行 scripts/ 下的脚本
scripts/build-app.sh          开发 App Bundle 生成脚本
scripts/bundle.sh             发布 App Bundle 生成脚本，输出到 build/Spooky.app；Sparkle 框架放进 Contents/Frameworks 并附上它的许可证
scripts/check-release.sh      发布检查：版本号与通道、构建号、更新说明与远端标签，本机发版与两个发布 workflow 共用
scripts/release.sh            mise run release：切出发布分支、写入版本号与构建号并开 release PR，失败时撤回分支
scripts/appcast.sh            mise run appcast：压缩更新包、生成并签名更新清单
scripts/compose-appcast.swift 把各语言的更新说明嵌进更新清单，并带上更稳定的各通道里最新的条目
scripts/make-icon.swift       应用图标生成脚本，在无窗口的 WebKit 中运行 make-icon.js，为默认与深色图标各合成指示灯灭着、亮着两份 .icns
scripts/make-icon.js          应用图标的 Canvas 2D 绘制
.github/workflows/ci.yml      PR 与 main 上的代码规范检查、编译、测试与打包
.github/workflows/release-check.yml release PR 的发布检查，改标题时也会运行
.github/workflows/release.yml release PR 合并后打包、生成签名的更新清单并创建 GitHub Release
.claude/skills/release/SKILL.md 从起草更新说明到确认 Release 已创建的发布流程
mise.toml                     构建、测试、打包与代码规范检查的 task
docs/testing/M1.md            M1 的 App 手动验收步骤
docs/testing/M2.md            M2 的连接、终端与主题验收步骤
docs/testing/M3.md            M3 的工作区、Diff、提交与冲突验收步骤
docs/testing/M4.md            M4 的历史、分支、同步与活动验收步骤
docs/testing/M5.md            M5 的集成、恢复、性能、可访问性与发布前验收步骤
docs/testing/M6.md            M6 的工作区、Diff、主题、储藏、冲突向导、文件视图与提交体验验收步骤
docs/testing/M7.md            M7 的历史、提交详情、侧边栏、引用、同步、改写、分支整理、Reflog 与撤销验收步骤
docs/testing/M8.md            M8 的仓库管理、窗口与导航、外部工具、链接、设置、帮助与发布更新验收步骤
docs/testing/M9.md            M9 的托管账号、Pull Request 与 Merge Request、发布仓库、Issue 补全、分支整理协作状态、子模块、工作树与 Git LFS 验收步骤
README.md                     英文 README：介绍、功能、系统要求、构建、权限、工作原理、开发与贡献说明
README-ZH.md                  README.md 的简体中文版，与它同步修改
LICENSE                       GPL-3.0 许可证全文
```

## 开发注意事项

### 本机与远端仓库

- git 调用一律经 `GitRunner` 执行：`run(_:input:)` 保持只返回 stdout 的 API，`execute(_:input:acceptedExitCodes:onOutput:)` 返回完整结果并提供流式数据块；`operation` 提供有界进度事件流、完整结果和主动取消
- 本机调用 Git Config 页所选的 Git 程序，默认 `/usr/bin/git`；`openLocalRepository()` 先检查最低版本 `2.41.0`，再通过 Git 识别工作区根目录；UI 不组装进程参数
- 远端调用 `/usr/bin/ssh`，由系统 SSH 处理连接、认证、主机指纹与复用
- `GitRunner` 给每条调用带上 `--no-pager`、`--no-optional-locks`、`color.ui=never`、`core.quotepath=off`，子命令里不必重复；要解析输出的子命令能用 `-z` 就用
- 远端仓库只通过 `~/.ssh/config` 中的主机别名访问，不把主机名、用户、路径或网络地址写死在库代码里
- 远端命令使用非交互模式；需要标准输入时（如 `commit -F -` 的提交信息）通过 `input` 参数传入
- `RemoteConnection` 为每个工作区管理专属 ControlMaster；控制与中继 socket 位于 `0700` 会话目录，绝不操作用户的其它 SSH 主连接
- 远端包装器由资源 `spooky-remote.pl` 按内容摘要版本化，原子安装到 B 的 `~/.spooky/bin`；依赖 B 的系统 Perl 核心模块，不安装常驻服务
- 所有写命令通过仓库队列串行；断线不重试写入，未确认的取消需要重连核对；新增纯读取命令时在 `RepositoryOperationQueue.isReadOnly` 明确登记
- 回调请求使用会话令牌和一次性应答，凭据不进入记录、日志或错误对象；用户选择保存时仅写 A 的钥匙串
- 服务器轮询间隔统一使用 `RemoteConnection` 的前台 2 秒、后台 10 秒常量；本机使用 `RepositoryFileMonitor` 的递归 FSEvents，并保留手动刷新
- 服务器轮询只读 status 与所选文件的内容哈希，有变化才读取身份、引用、历史与 Diff；写入完成、重连、窗口重新激活和手动刷新执行完整刷新
- 只由对象哈希决定的读取（历史分页、提交变更集与补丁、双向计数、指定提交的信息）经 `GitRunner.immutableRun` 缓存；结果会随工作区、索引或配置变化的命令不能使用它
- App 内同一仓库同时只允许一个写操作（`RepositoryWriteLocks`）；菜单、工具栏、右键菜单与拖放统一使用 `RepositorySession` 的 `can…` 可用性规则
- 文件读写使用 `RepositoryFiles`；SFTP 经 `RemoteConnection.sftpCommand()` 接入同一主连接，读写分别遵循主机并发和仓库写队列规则
- 工作区 UI 通过 `WorkingCopyOperations` 发起写入；组合操作用 `GitRunner.writeTransaction` 持有仓库锁，补丁以原始字节生成并核对快照，路径列表经字面 NUL 输入传递
- 交给 Quick Look、默认程序、比较工具或拖出的文件一律经 `RepositoryFileCache`：本机工作区文件用原路径，服务器文件与历史版本写进缓存目录、只保留文件名，关闭仓库时删除；远端路径不交给本机文件 API
- 按路径寻址树中对象的只读查询使用 `RepositoryFileViews.storedPathOptions`，路径先经 `storedEntry(for:in:)` 换成树中存储的形式：macOS 的 Git 会把命令行参数里的路径转成 NFC，树中以 NFD 存储的路径用原样的参数查不到
- 会生成提交的命令（`commit`、`merge`、`rebase`、`cherry-pick`、`revert`）在本机同样经 `LocalGitAuthentication` 执行：SSH 签名的私钥口令经回调询问，GPG 交给本机的 pinentry
- 远端的签名经包装器的 `-gpg`、`-ssh-keygen` 入口（`-c gpg.program=…`、`-c gpg.ssh.program=…`）接入中继，仍执行仓库配置的签名程序；gpg 以 loopback 模式运行，只在确实需要口令时询问
- 身份档案的签名密钥由 `SigningKeys.local` 从 A 的 gpg 钥匙环与 SSH agent 列出，值原样写进仓库配置；服务器仓库在 B 上签名，B 上要有同一把密钥
- `stash list` 与 `stash show` 是读取，其余 `stash` 子命令（包括不带子命令的 `stash`）按写操作排队；储藏全部改动时不加 `--literal-pathspecs`，它会让 `stash push -u` 把未跟踪文件留在工作区
- 采用两侧版本在仓库所在的机器上完成：`checkout-index --stage=all` 把三方写成仓库根目录下的临时文件，`merge-file --union` 合并后以 `hash-object --path` 按真实路径写入对象库，临时文件无论成败都删除；只用 Git 2.41 已有的选项
- `merge-tree --write-tree` 会往对象库写入对象，按写操作排队；`archive`、`format-patch`、`verify-tag` 与 `diff-tree` 已登记为读取
- 导出、归档与补丁这类可能很大的输出经 `GitRunner.stream(_:to:)` 边读边写进本机文件，不收进内存；失败或取消时删掉写了一半的文件
- 校验签名一律经 `SignatureVerification.run`：服务器仓库用包装器的 `-gpg` 入口，本机仓库为这次校验临时放一份包装器；包装器给 `--verify` 加上 `--no-auto-key-retrieve --no-auto-check-trustdb`，校验不访问网络
- 不由用户直接发起的操作（如自动获取）放在 `RemoteCallbackRequest.$allowsInteraction.withValue(false)` 里执行：回调只用钥匙串里已存的凭据，取不到按取消处理，不弹出输入框
- `fetch --porcelain` 不能与 `--recurse-submodules` 同用：获取一律带 `--no-recurse-submodules`，需要时在之后经 `submodule foreach --recursive` 获取子模块
- 交互式变基经 `RepositoryRewrite` 执行：提交序列与信息由内联在命令里的编辑器写入，在仓库所在的机器上运行；HEAD 或 Git 给出的 todo 与计划不一致时不改写任何提交
- 本地分支的置顶、归档、父分支与分支整理标记由 `BranchMetadata` 写在仓库配置的 `branch.<名称>.spooky-*`，改名时随段移动、删除分支时随段清除；布尔标记只写 `true`，取消时删除这个键
- 写操作经 `RepositorySession.performGit(undo:)` 声明与撤销记录的关系：只改仓库自己的引用、索引、工作区、储藏与 `branch.*` 配置的用 `.reversible`；改动远端、远端跟踪分支或其它配置的保持默认的 `.irreversible`；自动获取这类不由用户直接发起的操作与撤销、重做本身用 `.unrecorded`

### 仓库管理与系统集成

- 仓库书签由 `RepositoryBookmarks` 存在偏好 `repositoryBookmarks`：文件夹、手动顺序与最近打开时间，全部窗口共用；打开成功的仓库自动加入书签，失效只做标记，从不自动删除
- 新建、克隆、扫描与目录浏览在仓库存在之前进行：服务器经 `RemoteConnection.host(_:)` 的主机连接在 B 上执行，App 用 `RemoteConnection.presentingHost(_:)` 先装上询问凭据的处理器；本机与服务器执行同一份脚本，扫描只在用户选定的目录里进行
- 克隆在后台进行：`CloneActivities` 在开始时加入书签，移除没有完成的克隆时连书签一起移除；打开还没克隆完的书签显示克隆进度页，完成后打开仓库
- 服务器仓库不在 B 上运行 difftool / mergetool：两侧内容经 `ExternalToolFiles` 取到会话缓存目录，在 A 上启动工具；合并结果经 SFTP 写回后再 `git add`；编辑器副本写回前核对 B 上的版本，不一致时询问是否覆盖
- 视图引用 `ViewReference` 同时用于后退 / 前进、窗口恢复与 `spooky://` 链接；新增主视图时三处一起覆盖
- 链接：`spooky://open?repository=<位置>` 可带 `view`、`branch` 或 `commit`，`spooky://clone?url=<地址>`；服务器仓库写 `<主机别名>:<远端路径>`；github.com 的 “Open with Desktop” 链接只接受 github.com 的 https 仓库网址；解析不了的链接只显示错误，不执行任何动作
- 仓库设置只写仓库本地配置（`GitRunner.setLocalConfig`）；`spooky.commitbodylimit`、`spooky.commitshowsguide` 覆盖 Editor 设置页的正文折行
- 本机执行 Git 的程序与环境集中在 `LocalExecutionSettings.current`：Git Config 页的 Git 程序、Environment 页的登录 shell 与自定义变量、Integration 页的 SSH agent；服务器仓库用 B 自己的环境，Environment 页只能检查
- 诊断报告与崩溃报告离开本机前经 `DiagnosticRedactor` 脱敏；崩溃报告只打开预填的 GitHub 新问题页，由用户自己提交
- `UpdateController` 按 Settings → Updates 的通道接收更新清单里的条目，只接受 EdDSA 签名的清单与更新包；`swift run` 时更新器不启动

### 托管服务与仓库扩展

- 托管服务的接口一律经 `HostingClient` 从 A 发起：令牌只放在请求头（GitHub 用 `Authorization: Bearer`，GitLab 用 `PRIVATE-TOKEN`），请求不用 URLCache 里的旧响应；失败按 `HostingError` 分类并保留服务端原文
- 令牌只存在钥匙串，服务名 `com.rakuyo.spooky.hosting.<实例网页地址>`、账户名是账号 UUID；账号列表存在偏好 `hostingAccounts`，远端的手动关联与选定的账号存在 `hostingAssociations`，键是远端地址；`HostingAccounts` 的令牌存放处可以换成内存，测试不写钥匙串
- GitLab 最低 15.7：Merge Request 的 `diffs` 接口与 `detailed_merge_status` 从这一版起都有；添加与重新认证账号时经 `/version` 检查
- 请求的提交与改动在仓库所在的机器上比较：源分支提交不在仓库里时，从目标远端的 `refs/pull/<编号>/head`（GitLab 是 `refs/merge-requests/<编号>/head`）取到 FETCH_HEAD；合并时带上源分支提交让服务端核对，合并后在仓库所在的机器上获取目标远端
- 请求界面按选中远端的服务在 Pull Request 与 Merge Request 两套文案之间选：资源键分别以 `pr.`、`mr.` 开头，经 `RepositorySession.pullRequestText` 取，两组都登记在 `LocalizationTests.dynamicKeys`
- 子模块：`submodule status` 遇到没有 `.gitmodules` 映射的 gitlink 时整体失败，清单另经 `ls-files -s -z` 取 gitlink；`git rm` 删不掉缺配置的 gitlink，改用 `rm --cached` 再清理目录；改名时移动 `.git/modules/<名称>`，写相对的 gitfile，并经 `config --file` 设置 `core.worktree`
- 工作树：清单用 `worktree list --porcelain -z`；在子模块里 Git 会把 gitdir 报成主工作树，当前工作树按 `rev-parse --git-dir`、`--git-common-dir` 与 `--show-toplevel` 判断
- Git LFS：`lfs version` 已登记为读取，其余 `lfs` 子命令按写操作排队；每个写操作先确认 Git LFS 可用且不低于 2.9.0；`GitRunner.globalOptions` 带 `lfs.forceprogress=true`，输出不是终端时也写出传输进度；`lfs untrack` 认不出转义了方括号的规则，去掉后读回 `.gitattributes` 核对；git-lfs 3.8 在仓库路径含 `*`、`?` 或 `\[` 时扫描引用会失败

### 文本区

- Diff、原文、Blame 与主题示例取主题一律用 `TextTheme.current(dark:)`；在 SwiftUI 的 `body` 里调用，即随主题的编辑、切换与外观变化刷新
- 主题在 `~/Library/Application Support/Spooky/Themes`，一个主题一个 `.spookytheme` JSON
  - App 启动时由 `ThemeStore.installDefaultThemes()` 从 `BuiltinThemes.json` 写入 Default 与 Default (Dark)：只在文件缺少或无法加载、且名称没被别的主题占用时写，之后它们与其它主题一样可以编辑、改名与删除
  - 两种外观所选的主题按标识记在偏好 `lightTheme`、`darkTheme`；找不到时按名称回退到 Default 或 Default (Dark)，再退到 `BuiltinThemes.json` 里的版本
- 语法着色、Tab 宽度与不可见字符的偏好集中在 `TextPreferences`，一行文本按 `TextStyle` 经 `TextLineRenderer` 渲染；提交详情、储藏详情与文件历史的只读 Diff 共用 `ReadOnlyFileDiffView`
- 语法着色经 `SyntaxHighlighter` 借用 highlight.js 的上下文执行
  - 最多两份上下文，每份是一个 `HighlightRuntime` actor，只在自己的串行队列上使用，由全局 actor `SyntaxActor` 负责借还；一份被已取消的长任务占着时，新的请求由另一份接手
  - 调用方 `await` 识别与着色：任务取消时尚未开始的着色跳过、跑完的结果丢弃；写入视图状态前检查 `Task.isCancelled`
  - highlight.js 的脚本与 `LICENSE` 原样放在 `Sources/Spooky/HighlightJS/`，以 `.copy` 资源保持目录结构；`.process` 会把子目录摊平到资源包根目录
- Diff 的行号色由 `TextStyle.lineNumberColor` 从主题正文色推出；行内高亮在视图外按整份补丁算一次（`DiffSegment.highlights(in:)`），高亮色是命名色 `diff_inline_added_highlight_color`、`diff_inline_deleted_highlight_color`，不随主题变化
- Blame 注释栏的宽度存于偏好 `blameAnnotationWidth`（175–600 pt），所有窗口共用
- Diff 的块是懒加载栈里的分节：文件头与各块经 `DiffSegment` 排成栈里同一层的元素，块内每行连同无换行提示只占一个元素，身份带上块的起点；一个元素展开成多个视图或行的身份在各块间重复时，块头与行会漏显示

### 日志

- 使用 `os.Logger`，subsystem 为 `com.rakuyo.spooky`，category 为所在类型名；每个类型声明一个 `private static let logger`，`@MainActor` 类型再加 `nonisolated`
- 日志用中文，只记连接状态切换、远端会话的建立与关闭、Git 命令的失败与取消、写操作的起止与失败、回调请求、文件监听失败和退出超时；成功的读取不记
- 退出码、错误类别、状态名、Git 子命令名与操作名用 `privacy: .public`；仓库路径、主机别名等用户数据用 `privacy: .private`
- 不记命令参数、命令输出、提交信息、凭据、口令与环境变量；Git 命令只记 `RepositoryOperationQueue.command(in:)` 取出的子命令名
- 日志插值里引用属性时先取到局部常量：格式化会删掉插值中的 `self.`，而编译器要求显式写出
- 实时查看：`log stream --predicate 'subsystem == "com.rakuyo.spooky"' --level info`

### 测试

- 新增或修改 Git 输出解析时，测试覆盖成功输出、路径特殊字符和格式错误
- 涉及本机 Git 的测试使用临时目录，并在测试结束后清理
- Git 测试通过隔离环境忽略系统和用户全局配置，提交身份只写入临时仓库的本地配置
- Git 或 SSH 的失败路径检查 `GitError` 的退出码与错误信息
- 改动 App 时还须运行 `swift build --product Spooky`，按 [M1 验收步骤](docs/testing/M1.md) 实际启动、操作并截图；未执行的检查明确记录为未验证
- M2 的服务器、终端与主题场景见 [M2 验收步骤](docs/testing/M2.md)；远端测试默认不跑，必须通过 `SPOOKY_REMOTE_TESTS=1` 显式开启
- M3 的本机 / 服务器提交闭环、行选择、确认与冲突收尾见 [M3 验收步骤](docs/testing/M3.md)
- M4 的分页历史、分支、同步、合并预览、活动日志与取消见 [M4 验收步骤](docs/testing/M4.md)
- M5 的跨视图一致性、错误恢复、性能、可访问性与发布检查见 [M5 验收步骤](docs/testing/M5.md)；性能测试默认不跑，通过 `SPOOKY_PERFORMANCE_TESTS=1` 显式开启
- M6 的工作区文件操作、Diff 选项、主题、储藏、冲突向导、文件视图、提交体验与本机 / 服务器端到端流程见 [M6 验收步骤](docs/testing/M6.md)
- M7 的历史搜索与视图设置、提交详情与导出、侧边栏、引用与远端管理、同步与自动获取、改写操作、Branches Review、Reflog 与撤销，以及本机 / 服务器端到端流程见 [M7 验收步骤](docs/testing/M7.md)
- M8 的书签与仓库详情、新建、克隆与扫描、窗口与导航、快捷操作、外部工具、链接、设置与仓库设置、帮助与崩溃报告、发布与更新，以及本机 / 服务器端到端流程见 [M8 验收步骤](docs/testing/M8.md)
- M9 的托管账号、Pull Request 与 Merge Request、发布仓库、Issue 补全、分支整理协作状态、子模块、工作树与 Git LFS 见 [M9 验收步骤](docs/testing/M9.md)；github.com 的实测默认不跑，必须通过 `SPOOKY_GITHUB_TESTS=1` 并给出令牌与测试仓库显式开启；Git LFS 的测试在找不到 `git-lfs` 时跳过
- 侧边栏的视图设置以 `@AppStorage` 读 `SidebarPreferences` 的键；测试换用独立的偏好域时，视图的 `.defaultAppStorage` 与传给 `SidebarViewSettingsMenu` 的 `UserDefaults` 要一起换
- 测试里同一个偏好键要换成别的值时，新值写进另一个偏好域，不覆盖已有的值：进程的偏好缓存被清掉后，覆盖写入之后紧接着的读取可能仍得到旧值
- 会话测试要求刷新后用 `waitForRefresh()` 等刷新全部结束，不只等 `refreshTask`：本机仓库的文件监听会在写入后另起刷新，其间要求的完整刷新排在它之后
- 解析器的固定输入放在 `Tests/SpookyKitTests/Fixtures/`，由真实 Git 在隔离配置、固定身份与时间的临时仓库中生成
- 远端实测只使用 `spooky-test` 和测试专用密钥，写入仅限 `/Users/wgy/spooky-test/`、`~/.spooky/` 与会话临时目录；不分配 PTY，不转发 agent，不修改双方 SSH 和全局 Git 配置
- 本地化新增资源键时同步全部支持语言，并保持格式参数一致；动态拼接的资源键登记在 `LocalizationTests.dynamicKeys`；错误标题和恢复说明本地化，Git 原文保持不变

### 版本号

- 版本号写在 `Sources/Spooky/Info.plist`：`CFBundleShortVersionString` 是对外版本号，`CFBundleVersion` 是正整数构建号
  - 构建号每次发布由 `mise run release` 增加 `1`，跨版本持续递增、从不回退；更新按它比较新旧
- 1.0.0 之前，完成里程碑 Mn 的 PR 把 `CFBundleShortVersionString` 改为 `0.n.0`，如 M5 为 `0.5.0`、M10 为 `0.10.0`
- 1.0.0 由维护者确认后手动发起发布，见 “发布流程”

### README

- README 不写使用方法：快速上手、操作步骤和快捷键说明都不放进 README，使用方法由项目的专门网站介绍

## 协作约定

- 对用户的每一次发言，都先 **ultrathink** 再回答
- 实现需求时，拿不准或靠推测写下的地方，用 `#warning("TODO: ...")` 标记，并在修改完成后汇报

## 编码规范

### 通用

- 尽可能使用模块化思想，组件、文件、类型都要符合 “**高内聚低耦合**”
- 使用**提前返回**优化执行逻辑
- 私有方法放在文件最后面，越是工具性质的方法越靠后
- 每个文件末尾保留**一个**空行：不能让代码成为最后一行，也不能有多个连续空行

### Swift

- 按功能组织类型；相关模型可以像当前的 `WorkingCopyStatus.swift` 一样放在同一个文件中，不为满足 “每个文件一个类型” 而机械拆分
  - 源文件放进所属 target 下对应功能的子目录，如 `Sources/SpookyKit/WorkingCopy/`；现有目录都不合适时，按功能新建目录
- 文件名与主要类型名保持一致
- 访问级别按 API 边界取：
  - 对外 API 用 `public`
  - 模块内共享或供测试访问的用默认的 `internal`，不显式写出
  - 只在本文件、本类型内用的用 `fileprivate`、`private`
- 闭包里尽量用 `$0`、`$1` 等简写参数
  - 参数超过 2 个时写完整参数名
  - 嵌套闭包中，内层要引用外层的参数时，外层必须用命名参数

### 中文行文

- 日志、代码注释、文档使用中文；git、ssh 等外部工具原样输出的错误信息保留原文
- 中文与英文之间、中文与数字之间、符号和文本之间留一个空格，如 `2 × 2`、`100 / 1024`、`A → B`、`——`
  - 引号的外侧同样留空格，连着的几个引号之间也留，如 `仓库放在 “文稿” “桌面” “下载” 等位置时`
  - 紧贴不留空格的：
    - 范围号 `–`（`01–08`）与负号（`−5 pt`）
    - 数字后的单位符号（`5.5%`、`45°`）
    - 英文词内的连字符（`ad-hoc`）
    - 快捷键（`⌘⇧.`）
    - 与数字连写的记号（`#22`、`@2x`）
    - 括号与引号的内侧
    - 全角括号的外侧（`项目（Spooky）中`）
    - 挨着中文标点或位于行首、行尾的一侧（`见 “常用命令”。`）
- 使用中文弯引号（`“”`），不使用直引号（`""`）
- 照抄系统原生文案的界面文字保持原样，不按本节的空格规则改动
- `// MARK:` 的分节名：
  - 顶层的 `// MARK: -` 用英文，如类型名、`Private`、`Helpers`
  - 类型体内的用中文

### 注释

- 每个类型、属性、函数（特别是构造函数）的声明都要有完整注释
- 函数实现内部按功能块补充必要说明，帮助读者快速理解意图；**禁止逐行翻译代码**
- **禁止行尾注释**

### 简洁性

- 不为只用一次的逻辑创建抽象层
- 除非逻辑会复用、能显著提升可读性，或有明确的业务边界，否则不新增只调用另一个函数的 wrapper
- 优先使用项目已有的工具和组件，不新造轮子

### 代码规范验证流程

代码风格以 [RakuyoKit/swift](https://github.com/RakuyoKit/swift) 为准；运行过任一 `mise run` task 后，规则原文位于 `.build/checkouts/swift/Sources/RakuyoSwiftFormatTool/`。

- 新建或编辑 `.swift` 文件后，运行 `mise run swift:lint`；不通过时先运行 `mise run swift:format` 自动修复，再运行 `mise run swift:lint`
- SwiftLint 以 `--strict` 运行，警告同样算不通过；长度上限为类型体 250 行、函数体 80 行、闭包体 30 行、文件 600 行（不计纯注释行）
  - 类型体超限时，按功能把成员移到 `类型名+功能.swift` 的扩展文件，如 `RepositorySession+Stash.swift`
- `mise run swift:lint`、`mise run build` 与 `mise run test` 都通过才算完成；CI 在每个 PR 与推送到 main 时运行同样的检查

## 产物可追溯性（番茄炒蛋原则）

> 名字来自一个段子：让 AI 做番茄炒蛋，它加了东坡肉；删掉之后，它又把菜名改成 “番茄炒蛋（无东坡肉）”。东坡肉和它的影子都不该存在。

本节管的不是代码风格，是**产物里能出现什么**。

**产物** = 代码、注释、命名、commit message、PR 文案、文档。

**产物只有两个输入：需求与仓库现状。** 模型自己的想法、多轮讨论里出现过又被否掉的东西、上一版草稿，都不是输入。

判据一句话：**产物里的每一个元素，都要能指出它来自需求的哪一句、或仓库的哪个既有模式；指不出来的，不写。** 追溯不到的就是 dead code：删除，不在代码里解释。

讨论、试错、被否掉的方案、认错与解释，都只留在对话里；产物只装最终状态，不装任何相对中间稿、相对对话的描述。

### 铁律

1. **歧义取最小。** 需求没说清的地方按最小解释做，不按最丰富的；“以防以后要” 不是理由。
2. **想加的，说，不做。** 觉得需求之外还该有什么，在回复末尾用一句话列出，交给用户；不实现、不写进注释，也不为它留 TODO。
3. **注释只写 “是什么、为什么这样”。** “为什么” 只写结论，不复述论证，不指向自己考虑过的其它做法；不写 “暂不” “无需” “后续可” “也可以”。
4. **纠错无痕。** 被指出 “不该有” 的东西是**错误**，不是被否决的**方案**：抹平，不解释它曾经存在，并把为它而存在的参数、导入、辅助方法、测试、文档提及一并清掉。
5. **按身份命名。** 名字说它是什么，不说它比上一版少了什么；“无 XX” “不含 XX” 这类靠 “没有什么” 定义的名字不用。
6. **最小改动的基准是仓库原状，不是自己的上一版草稿。** 理解错了就从纠正后的理解重写，草稿没有任何需要保留的价值。
7. **为没看过对话的人写。** 产物的读者是未来维护者与 reviewer，他们看不到会话；删掉对话记录后说不通、没价值的句子，一律不写。
8. **上下文被压缩或恢复之后，以仓库现状为准，不以摘要为准。** 摘要会保留 “否决了什么”，而那正是不该进产物的东西；续做前重读相关的代码与文档。

**唯一允许写 “为什么不” 的情形**：一个没看过对话的未来维护者也很可能自己走到那条错路上。此时只留**一句**警示，不复述论证。“自己刚想到 / 刚犯过” 不构成理由。

### 交付前自检（必做，放在每次产出的最后一步）

对本次新增的每个元素 —— 代码、注释、名字、commit / PR 文案、文档 —— 问两个问题：

- 指得出它来自需求的哪一句、或仓库的哪个既有模式吗？指不出 → 删
- 删掉对话记录后，这句话还说得通、还有价值吗？说不通 → 删

命中了即改，不必征询。本节的违反是**规范违反**，不是 “代码风格偏好”，review 时不得以后者为由过滤。

## 工作纪律

- **以验证为目标。** 先定义成功标准，循环到验证通过为止，而不是把步骤走完就算完成
- **冲突要摆出来，不要折中。** 两种写法互相矛盾时，选一种（更新的、验证更充分的），在回复里说明理由并指出另一种待清理；不要混用
- **测试验证意图。** 测试要表达 “为什么这个行为重要”；业务逻辑改了还不会失败的测试是错的
- **失败要大声说。** 有步骤被静默跳过，就不能说 “完成”；有测试被跳过，就不能说 “测试通过”；默认把不确定说出来，而不是藏起来

## 发布流程

每个版本发往一个通道，对应 Settings → Updates 的三个选项：

- `stable`：所有用户都会收到
- `beta`：选了 Beta 或 Development 的用户会收到
- `development`：只有选了 Development 的用户会收到

发布一个新版本：

1. 写这一版的更新说明，放在 `docs/release-notes/X.Y.Z/`，见 “更新说明”；可以先合并进 `main`，也可以留在工作区，由下一步带进发布提交
2. 在 `main` 上运行 `mise run release X.Y.Z [stable|beta|development]`，通道默认为 `stable`；脚本先检查以下各项，任一不满足就报错退出，不做任何改动：
   - 版本号为 `X.Y.Z`，三段都是不带前导零的非负整数，不带 `v`；通道是三者之一
   - Info.plist 的当前构建号是正整数
   - 这一版的更新说明齐全：每种语言一份，都有内容
   - 标签 `vX.Y.Z` 在远端不存在
   - 当前在 `main` 分支，除 `docs/release-notes/X.Y.Z/` 下的新增或改动外工作区干净，本地 `main` 与 `origin/main` 一致
   - `gh` 已登录，`origin` 是本仓库而不是 fork：fork 的 PR 拿不到发布所需的写权限
   - 本地与远端都没有 `release/X.Y.Z` 分支
3. 检查通过后，脚本切出 `release/X.Y.Z` 分支，把 Info.plist 的版本号改成 `X.Y.Z`、构建号增加 `1`，连同这一版的更新说明一起提交并推送，再向 `main` 开 release PR
   - PR 标题为 `release: X.Y.Z`，测试与开发版本在后面加 ` (beta)` 或 ` (development)`
   - 推送或开 PR 失败时，脚本删掉本机与远端的发布分支，更新说明留在工作区
4. 标题以 `release:` 开头的 PR 由 “发布检查” workflow 运行 `scripts/check-release.sh`：标题格式、Info.plist 的版本号与标题一致、构建号比 `main` 增加 `1`、更新说明齐全、远端没有同名标签；改标题时也会重新检查
5. 检查通过后合并 PR；“发布” workflow 对合并提交再做一次同样的检查，然后：
   - 打包并压缩为 `Spooky-X.Y.Z.zip`，生成签名的更新清单，每种语言的更新说明都嵌在清单里
   - 测试与开发版本的清单带上最新 Release 清单里更稳定的各通道最新的条目，选了这些通道的用户仍能收到它们
   - 在合并提交上打标签 `vX.Y.Z`，创建标为 latest 的 GitHub Release：名称为 `vX.Y.Z`，测试与开发版本带上通道；正文是这一版的 `en.md`，附上 zip 与更新清单

失败时到仓库的 Actions 页面查看原因，修好后再运行一次 `mise run release X.Y.Z`。

也可以对 Claude Code 说 “发布 X.Y.Z”，由 [`release` skill](.claude/skills/release/SKILL.md) 走完起草更新说明、开 PR、等检查、合并、等发布的全过程。

更新签名：

- 更新包与更新清单都用 Sparkle 的 EdDSA 私钥签名；App 只接受签名的更新清单，下载的更新包先验证签名再解压安装，签名不符时不安装、保留当前版本
- 私钥须与 Info.plist 的 `SUPublicEDKey` 配对，由 Sparkle 的 `generate_keys` 管理；只存于仓库 secret `SPARKLE_PRIVATE_KEY` 与维护者本机钥匙串的 `com.rakuyo.spooky` 账户，不进仓库
- App 从标为 latest 的 Release 附带的 `appcast.xml` 读取更新清单
- 本机先运行 `mise run bundle`，再运行 `mise run appcast <通道> [<上一份更新清单>]`，在 `build/updates/` 生成更新包与签名的更新清单

## 更新说明

每个版本的更新说明放在 `docs/release-notes/X.Y.Z/`，每种语言一份：`en.md` `zh-Hans.md` `zh-Hant.md` `ja.md` `ko.md` `de.md` `fr.md` `es.md`，与 `Sources/Spooky/Resources/` 下的 `.lproj` 同名。

- `mise run appcast` 把每份说明嵌进签名的更新清单，App 的更新窗口按用户的语言显示其中一份
- `en.md` 同时是 GitHub Release 的正文
- `scripts/check-release.sh` 检查每份都存在且有内容：发版脚本、“发布检查” 与 “发布” 两个 workflow 都调用它

### 写法

- 写给用户看：只写用户能感知的改动
  - 不写 PR 编号与链接
  - 不写文档、CI、测试、重构这类与 App 行为无关的改动
- 不写顶层标题：更新窗口与 GitHub 都会显示版本号
- 按类别分节，节标题用 `###`，取下表中该语言的叫法，只保留有内容的节；每条列表项写一个改动
- Markdown 只用 `###` 标题、无序列表、粗体、链接
- 界面上的叫法与该语言的 `Localizable.strings` 一致
- `zh-Hans` `zh-Hant` 按 “中文行文” 一节；`ja` `ko` 的引号等写法照各自 `Localizable.strings` 的现有用法
- `de` `fr` `es` 与 `en` 一样用粗体标出界面上的叫法；`de` 的 `…` 之前，`fr` 的 `:` `;` `!` `?` 之前与 `« »` 之内，用不换行空格（U+00A0），免得它们被折到行首

| 语言 | 新增 | 改进 | 修复 |
|---|---|---|---|
| `en` | New | Improved | Fixed |
| `zh-Hans` | 新增 | 改进 | 修复 |
| `zh-Hant` | 新增 | 改進 | 修正 |
| `ja` | 新機能 | 改善 | 修正 |
| `ko` | 새 기능 | 개선 | 수정 |
| `de` | Neu | Verbessert | Behoben |
| `fr` | Nouveautés | Améliorations | Corrections |
| `es` | Novedades | Mejoras | Correcciones |

## 分支命名

- 只用两种前缀，后接 `rakuyo/<简述>`：
  - `fix/`：修缺陷
  - `feature/`：其它改动，包括新功能、文档、排版整改等
- `<简述>` 用小写英文单词，以连字符连接，如 `feature/rakuyo/working-copy-status`
- 前缀不随提交类型变化：提交类型是 `feat`、`docs`、`style` 等时，分支前缀仍是 `feature/`

## commit message

- 格式为 `<type>: <简述>`，代码标识用反引号，默认不带正文
- type 取值：
  - `feat`：新增或改变行为
  - `fix`：修缺陷
  - `refactor`：行为不变的结构调整
  - `docs`：只动文档
  - `chore`：构建、依赖、流程工具
  - `style`：行为不变的排版、注释措辞、命名整改
  - `test`：只动测试
- 简述用中文写成一句 “改动结果”
- 标题不超过 50 个字符，中文一字算一，可用 `printf '%s' '<标题>' | wc -m` 核对
- 不含任何 AI 署名：`Co-Authored-By`、`Generated with`、🤖 之类的行与尾注一律不写
- 例外：merge commit 保留默认生成的提交信息，如 `Merge pull request #12 from …`，不按本节格式改写

## PR 标题与描述

PR 文案与 commit message 一样是产物，受 “产物可追溯性” 一节约束：为没看过对话的人写，只在对话里成立的说法不写。

### 标题

- 与 commit message 同一格式：`<type>: <简述>`，type 取值、反引号、50 字上限都相同
- 简述是一句 “改动结果”，不带主语；一个 PR 做了几件事就并列写出，如 `feat: 支持经 SSH 执行 git，解析 porcelain v2 工作区状态`
- type 按 PR 的主要改动取

### 描述

按下面的顺序写，哪一节没有内容就整节不写：

1. 开头一两句说清做了什么、为什么；承接上一个 PR 的写 “承接 #编号”，对应需求文档时写出文档名
2. `## 改动`：按关注点分条，每条说清行为上的结果；关键的新类型顺带点到即可，不罗列改动的文件，diff 本身就有
3. `## 验证`：构建、单元测试数量、远端或本机实测的场景与数据、审查结论
4. `## 未验证`：没验到的项与原因
5. `## 注意`：平台限制、与需求仍有的差别、留下的 `#warning`

口吻是作者向 reviewer 说明：自然的中文，不带 “我”，不刻板也不俏皮；事实与数字照实写，不含任何 AI 署名。

## PR 合并方式

- 合并 PR 一律使用 merge commit，不使用 squash 把整个 PR 压成一个普通提交

## 本文件的回写约定

- 协作规范、目录约定、流程纪律等长期信息写入本文件
- 仓库里不放 `CLAUDE.md`：Claude Code 默认只在项目没有 `CLAUDE.md` 时读取本文件
  - 发现仓库里出现了 `CLAUDE.md`，把其中的规范搬进本文件，再删掉它
- 本文件正文不使用 `@路径` 语义（避免被 Claude Code 误展开），引用其它文件统一用 Markdown 链接
