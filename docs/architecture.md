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
| `Remote/` | SSH 主连接、连接体检、断线重连与写入核对、远端取消、包装器安装、远端输出的解析与脱敏、服务器目录在本机的挂载位置 |
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
| `App/` | 入口、窗口与菜单协调、本地化与错误说明、外观、命名色与文本区主题、链接解析、系统通知 |
| `AppIcon/` | App 图标，随图标样式与连接状态切换 |
| `Components/` | 对话框骨架与呈现它的 sheet 或模态窗口，空状态、错误详情、连接状态、头像等共用视图 |
| `RepositoryManager/`、`Launch/`、`Clone/` | 仓库管理与书签、启动窗口，新建、克隆与扫描 |
| `RepositoryWindow/` | 仓库窗口与菜单动作、侧边栏、搜索、操作对话框与拖放 |
| `Navigation/` | 后退 / 前进记录、视图引用与窗口恢复 |
| `QuickActions/` | 快捷操作面板 |
| `Session/` | 仓库会话：状态与刷新、操作可用性、视图状态、文件监听与自动获取 |
| `WorkingCopy/`、`Diff/`、`Text/` | 工作区与提交区、Diff、文本渲染与语法着色 |
| `History/`、`FileViews/` | 历史与提交详情、文件历史、Blame 与原文 |
| `Sidebar/`、`References/`、`BranchesReview/` | 侧边栏、分支 / 标签 / 远端的管理、分支整理 |
| `Rewrite/`、`Reflog/`、`Undo/`、`Stash/` | 改写历史、Reflog、撤销与重做、储藏 |
| `Activity/` | Activity 窗口、按 Remote / Repository / Service 分页的操作与读取记录、读取的增减计数与它的基准、Remote 记录与增减基准的本机保存，以及仓库写锁 |
| `ExternalTools/` | 外部比较与合并工具、Open With 与远程编辑 |
| `Settings/`、`RepositorySettings/` | 设置窗口与仓库设置 |
| `Accounts/`、`PullRequests/` | 托管账号、Pull Request 与 Merge Request |
| `Submodules/`、`Worktrees/`、`LFS/` | 子模块、工作树与 Git LFS 的视图与对话框 |
| `Help/` | 关于窗口、Help 菜单、What's New 与新功能卡片、诊断报告与崩溃报告 |
| `Updates/` | Sparkle 更新器与更新通道 |
| `HighlightJS/` | 随 App 打包的 highlight.js 与它的许可证 |
| `Resources/` | 各语言文案、系统权限说明、命名色与内置主题 |

## Git 命令执行

- Git 调用一律经 `GitRunner`，本机与服务器仓库共用一套接口：
  - `run(_:input:)` 只返回 stdout；`execute(_:input:acceptedExitCodes:onOutput:)` 返回完整结果并提供流式数据块；`operation` 提供有界的进度事件流、完整结果与主动取消
  - `stream(_:to:)` 把导出、归档与补丁这类可能很大的输出边读边写进本机文件，不收进内存；失败或取消时删掉写了一半的文件
    - 例外是快速保存补丁：在仓库所在的机器上用 `git format-patch -o` 直接写进仓库根目录，服务器仓库写在服务器上
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
- 工作区的写入经 `WorkingCopyOperations` 发起：补丁以原始字节生成并核对快照，文件级操作的路径列表经字面 NUL 输入传递
  - 单文件 Diff 用字面包含与子项排除，只比较真实新旧路径；新旧路径互为祖先时，从当前完整状态确定旁支排除范围，每轮重新计算，路径比较使用 UTF-8 字节
  - 状态展示与快照共用严格记录解析；先验证完整输出再过滤，保留原始字段、重命名双 NUL 路径、记录顺序及同路径重复条目。旧重命名条目须匹配当前新旧路径和同一暂存侧
  - 一轮采样中的两侧逐字节补丁和忽略空白的显示补丁共用范围。前后目标状态不同立即拒绝；仅排除范围改变时丢弃整轮结果，最多完整重读一次。指纹只包含选项、所选原始状态及补丁，不包含旁支状态或排除计划
  - 重命名后旧路径新建的独立未跟踪文件，其出现、消失或暂存使旧快照失效；只改内容不改变重命名指纹。按块 / 行写入只生成新路径补丁，不覆盖该独立文件
  - 按块 / 行写入在仓库锁内两次核对快照，并经 `git apply --check` 与正式写入检查。此锁只串行 App 内的写操作；外部 Git 和编辑器仍可改动仓库，因此属于乐观校验，不是跨进程原子快照
- App 内同一仓库同时只允许一个写操作（`RepositoryWriteLocks`）；菜单、工具栏、右键菜单与拖放统一使用 `RepositorySession` 的 `can…` 可用性规则
- 写操作经 `RepositorySession.performGit(target:)` 声明记在 Activity 的哪一页：传了连接的对象（`ActivityTarget`：传输方向、远端名与 refspec）就记在 Remote 页，记录的标题与图标由它写出；没传的记在 Repository 页
  - 一次写操作连接几个对象时分成几条记录，如获取全部远端时每个远端一条，同步的拉取与推送各一条：动作里经 task-local 的 `ActivityRecording` 另起记录，这些事件与 Git 输出走同一个流，先后不乱
  - 核心库不知道 Activity，只报出分界：`RepositorySync.fetch` 获取全部远端时在每个远端开始前经 `onRemote` 报出远端名，`RepositorySync.sync` 在每一步开始前经 `onStep` 报出步骤；App 据此为每个远端、为同步的推送另起记录
- 写操作经 `RepositorySession.performGit(undo:)` 声明与撤销记录的关系：
  - `.reversible`：只改仓库自己的引用、索引、工作区、储藏与 `branch.*` 配置
  - `.inverse`：快照记不住的改动，如远端设置、assume-unchanged 标记、Git LFS 的启用，发布的分支与标签、重命名的远端分支，以及子模块的增删、移动、改名、本地设置与子模块里检出的版本；操作前读出撤销要用的内容，撤销时执行反向操作、先核对前提，重做时再执行一次原操作（添加子模块的重做复用撤销时留下的 Git 目录）；要推送的撤销与重做记在 Activity 的 Remote 页
  - `.irreversible`（默认）：推送、删除远端引用这类其余改动服务器的操作，以及提交身份、exclude 规则或其它配置
  - `.unrecorded`：自动获取这类不由用户直接发起的操作，以及撤销、重做本身
- 撤销的快照建在仓库所在的机器上，写进仓库自己的对象库；恢复前核对仓库仍与记录一致
- 移进废纸篓的文件不进快照：写操作期间由 `TrashLog` 记下它们在废纸篓里的位置，撤销时移回原处，重做时重新移进废纸篓；废纸篓程序不报告位置时这次操作不能撤销
- 发布分支与标签只连接一次远端：写操作期间由 `PushLog` 记下 `push --porcelain` 的逐条结果，新建了远端引用才登记撤销，已是最新时不碰撤销记录，快进了远端已有的分支与推送一样不能撤销

- 本机与服务器的 Git 子进程都清除 `GIT_LITERAL_PATHSPECS`、`GIT_GLOB_PATHSPECS`、`GIT_NOGLOB_PATHSPECS`、`GIT_ICASE_PATHSPECS`；文件补丁通过字面包含与子项排除限定实际新旧路径，目录历史查询仍递归匹配。

### 获取与自动获取

- 不经对话框的获取（快速获取、Fetch All Remotes、自动获取、添加远端后的获取）共用 `SyncPreferences.fetchOptions(in:)` 给出的清理与子模块选项；获取对话框里入口带来的预选只作用于这一次，用户在对话框里切换的选项才写进偏好
- 自动获取由 `RepositoryAutoFetch` 调度，每个远端各自计时：上次获取的时刻按仓库与远端名存在偏好 `remoteLastFetch`，跨重启保留；它是运行状态，不登记为用户数据
  - 进入仓库视图、换仓库、sheet 结束、远端名单变化与改间隔时重新计时，10 s 后检查，之后每 160 s 检查一次；显示仓库管理或挂着 sheet 时暂停
  - 每次检查只获取距上次获取已满设定间隔的远端，一个结束再开始下一个；各获取入口开始获取一个远端时都记下时刻，失败也记
  - 跳过设了 `skipFetchAll` 的远端；本机仓库另跳过解析不出主机的地址（本机路径、`file://`），系统网络路径不可用时这次不获取；服务器仓库的地址交给 B 上的 Git，A 不判断主机与网络

## 进行中的操作与提交

- 进行中的操作由 `OperationProgress` 一次读出：状态文件经同一次 `rev-parse --git-path` 定位、经 `RepositoryFiles` 读取，本机与服务器同一路径
  - 核心库给出分类：变基总是序列，摘取与反转以 `sequencer/` 是否存在为准；停在 `edit` 指令且有 `rebase-merge/amend` 时是 edit 步。另给出步数、edit 步的父提交、冲突时对方的提交与预填的提交信息
  - 横幅、提交区、Skip、空提交确认与冲突向导都读这份结果，不各自判断
- 提交信息有普通、修补与合并三种编辑模式，共用一份草稿：进入修补前记下草稿，取消或修补成功后恢复；进入合并或序列的下一步时换成预填的信息
- 提交与继续都经 `commit -F -` 传入信息，并加 `--cleanup=whitespace`，注释行先按设置处理；继续序列时先用编辑后的信息提交这一步，再让 Git 继续剩下的步骤
- 合并以 `RepositorySync.merge` 的结果区分是否停在冲突上：退出码为 1 时在同一写事务里核对 `MERGE_HEAD`（压缩合并为 `SQUASH_MSG`）与冲突条目，其余失败照原样抛出
- 冲突向导的两侧版本取自索引的 stage，对方的提交在变基时取 `REBASE_HEAD`；选择只在视图里，不写仓库；交给本机程序的版本先写进 `RepositoryFileCache`
- 旧提交的 Amend 与 Edit 用同一份 todo（目标为 edit、其余为 pick），Amend 停在目标本身；有本地改动时先询问是否储藏，储藏不自动恢复

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
- Show in Finder：B 的目录经 SMB、NFS、AFP、WebDAV 或 sshfs 挂载到这台 Mac 时，`RemoteMountLocator` 找出它在本机的位置
  - 找卷：比较 `ssh -G <别名>` 得到的主机与网络卷重新挂载地址里的主机解析出的地址
  - 找目录：按远端路径从最长的后缀试起，在卷里找带 `.git` 的目录
  - 核对：经 SSH 在 B 的 Git 目录里临时写一个随机命名的空文件，本机看得到才算同一个目录，随后删掉
  - `RepositoryMountState` 按 B 上的目录缓存结果：仓库目录以外的工作树各自查找，读到工作树清单、这台 Mac 挂载或卸载卷时查找，结果只在本次运行里保留
  - 仓库设置里可以为仓库目录手动指定本机目录：选定时按上面的办法核对一次，通过才记进这台 Mac 的偏好（`ServerLocalFolders`）；指定了就不再自动查找仓库目录，仓库目录以外的工作树照旧查找
- 刷新：
  - 服务器仓库按 `RemoteConnection` 的常量轮询，前台 2 秒、后台 10 秒；只读 status 与所选文件的内容哈希，有变化才读取身份、引用、历史与 Diff
  - 本机仓库由 `RepositoryFileMonitor` 的递归 FSEvents 触发刷新
  - 写入完成、重连、窗口重新激活与手动刷新执行完整刷新
  - 刷新引起的重读不先清空已显示的内容，读取在后台进行、不显示进度：
    - 历史从头重读时至少读回已加载的条数，读完一次替换；选中的提交仍在列表里就保留选择
    - 同一提交的变更集，以及展开与选中文件的补丁，读到的与已显示的相同时不替换；不在新变更集里的文件移出展开与选中
    - 文件历史在 HEAD 移动后同样处理时间线与所选提交的详情
    - 选中的提交不在新的列表里时，选择与详情照常清空
- 断线：保留上次读取的状态并在后台重连；写入中途断线时不重试，重连后先核对分支、工作区、暂存区锁、远端跟踪分支与进行中的合并或变基，再允许写入
- 取消：先关闭命令通道，再由包装器结束远端的整组进程，发 TERM、2 秒后发 KILL，并确认进程已退出；没能确认时，重连核对之前不能写入
  - 同一主机同时执行的命令最多 8 条，取消通道另外最多 1 条：被取消的命令在 B 上结束之前一直占着会话，取消得到确认时那个会话也可能还没释放；三者合计不超过 OpenSSH 默认的每条连接 10 个会话（`MaxSessions`）
- 新建、克隆、扫描与目录浏览在仓库存在之前进行：
  - 服务器经 `RemoteConnection.host(_:)` 的主机连接在 B 上执行，App 先用 `RemoteConnection.presentingHost(_:)` 装上询问凭据的处理器
  - 本机与服务器执行同一份脚本，扫描只在用户选定的目录里进行

## 凭据、签名与回调

- 口令、密码、签名口令与编辑器的请求经 `CallbackRelay` 回到 A：服务器仓库经当前主连接上的反向 Unix socket，本机仓库经私有的 Unix socket
  - 每个请求带会话令牌，只能应答一次，120 秒后超时
  - 凭据不进入记录、日志或错误对象；用户选择保存时只写 A 的钥匙串
- 不由用户直接发起的操作（如自动获取）放在 `RemoteCallbackRequest.$allowsInteraction.withValue(false)` 里执行：回调只用账号令牌与钥匙串里已存的凭据，取不到按取消处理，不弹出输入框
- HTTPS 远端属于已登录的托管账号时，Git 用账号的令牌认证：
  - `GitCredentialScopes` 记着交给 Spooky 回答的地址前缀：账号实例的 HTTPS 网页地址，与关联到已登录账号的 HTTPS 远端（去掉用户名）；App 在启动与账号、关联变化时写入
  - 本机与服务器上的每条 Git 命令为每个前缀先清空已有的凭据助手，再加上包装器的 `credential` 入口，并打开 `credential.useHttpPath`，助手与 askpass 都拿到带路径的地址
  - 包装器只把 `get` 与 `erase` 的地址经中继交给 App，`store` 不交；`AccountGitCredentials` 按手动关联、账号实例的顺序找账号，回答 `username` 与 `password`，用户名与密码登录换来的令牌配用户名 `oauth2`；服务器仓库的令牌只经中继回到 B 上助手的标准输出
  - 回答的顺序：账号令牌、钥匙串里存过的凭据、弹框询问。对不上账号、账号需要重新认证或令牌被 Git 拒绝过时，助手不输出，Git 接着问 askpass
  - 同一操作对刚回答过的地址发来 `erase`，说明 Git 拒绝了令牌：只在内存里标记这个账号，重新认证或移除后清掉；之后这个账号的地址回到询问，说明里写明账号的令牌没能通过
  - 中继只把应答里 `password=` 行的值记进脱敏集合
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
  - 令牌只放在请求头：GitHub 与用户名和密码登录的 GitLab 账号用 `Authorization: Bearer`，其余 GitLab 账号用 `PRIVATE-TOKEN`
  - 请求不用 URLCache 里的旧响应；失败按 `HostingError` 分类并保留服务端原文
- 令牌只存在钥匙串，服务名 `com.rakuyo.spooky.hosting.<实例网页地址>`，账户名是账号 UUID
  - 个人访问令牌与浏览器授权的令牌存原文
  - 私有部署 GitLab 的用户名与密码经 `GitLabPasswordGrant` 换成 OAuth 令牌，钥匙串存访问令牌、刷新令牌与到期时间的 JSON，密码不保存
  - 这种账号的客户端在每次请求前经 `HostingAccounts.token(for:)` 取令牌：距到期不到 60 秒时先用刷新令牌续期，同一账号的续期串行进行；刷新令牌被拒时账号标为需要重新认证
- 请求的提交与改动在仓库所在的机器上比较：源分支提交不在仓库里时，从目标远端的 `refs/pull/<编号>/head`（GitLab 是 `refs/merge-requests/<编号>/head`）取到 `FETCH_HEAD`；合并时带上源分支提交让服务端核对，合并后在仓库所在的机器上获取目标远端

## 仓库管理与系统集成

- 仓库书签由 `RepositoryBookmarks` 存在偏好里，全部窗口共用；打开成功的仓库自动加入书签，失效只做标记，从不自动删除
- 仓库设置只写仓库本地配置（`GitRunner.setLocalConfig`）
- 本地分支的置顶、归档、父分支与分支整理标记由 `BranchMetadata` 写在 `branch.<名称>.spooky-*`，改名时随段移动，删除分支时随段清除
- 引用的公共顺序由 `ReferenceOrder` 定义：侧边栏、恢复版本的候选、Reflog 的引用菜单、合并与拉取的下拉共用，当前分支不提前
- 侧边栏行的拖放落点是 `RepositoryDropView` 承载的 AppKit 视图，只登记拖放类型、点击穿透给所在的行；`ReferenceDropAction` 按来源、落点与 ⌥ 解析出动作，拖动中把动作名作为徽标加到拖动影像上，落下时执行同一个动作
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
    - 同名的主题仍是旧的默认配色时换成 `BuiltinThemes.json` 的配色，旧配色与它不同的几种颜色记在 `LegacyBuiltinThemeColors.json`
  - Default 与 Default (Dark) 按名称认出，可以编辑，不能改名、删除
  - 浅色与深色外观各选一个主题；找不到时按名称回退到 Default 或 Default (Dark)，再退到 `BuiltinThemes.json` 里的版本
  - Diff、原文、Blame 与 Themes 页的 Diff 预览取主题一律用 `TextTheme.current(dark:)`；在 SwiftUI 的 `body` 里调用，即随主题的编辑、切换与外观变化刷新
  - 主题文件的 RGB 分量按 calibrated RGB（Generic RGB）直接构色，正文、背景、选区、语法记号、增删行底色与 Themes 页共用；颜色面板也先转到 Generic RGB 再保存，避免编辑往返改变颜色
  - 行号、描边与原文 / Blame 的次要文字、段高亮、分隔线从文件的原始分量按 sRGB 推导；`NamedColors.json` 的命名色同样保持 sRGB
- 语法着色、Tab 宽度与不可见字符的偏好集中在 `TextPreferences`；一行文本按 `TextStyle` 经 `TextLineRenderer` 渲染
- Tab 与源空格的可见符号附在原空格位置，LF 标记附在实际换行字符上，由 Diff、原文与 Blame 共用的 AppKit 布局管理器绘制；符号不参与正文推进和折行。CR 保留到行渲染器，CRLF 只标 CR。
- 原文与 Blame 的末行 LF 都由已读 blob 决定，复制使用 blob 的完整解码源串与 UTF-16 显示映射；显示层对其它 Unicode 分隔符的替代不改变复制内容。Themes 预览跟随既有不可见字符偏好。
- Diff 外层按块懒加载，每块正文是独立的 TextKit 1 文本区，原生字符选择只在块内跨行。行号栏与正文共享实际折行矩形，写入选区仍使用逻辑补丁行标识。
- 每个显示行记录显示 UTF-16 范围、源范围与所属补丁行；无换行提示单独成行但指向所属行。复制从源映射取字符，保留原始 Tab、CR 与已有的末尾 LF，不复制显示替换标记。
- 每块的行选择由独立模型管理，鼠标按下与拖动立即更新正文和行号，块头计数在松开时发布；键盘和辅助功能动作立即完成。范围使用显示行位置，写入只传逻辑行标识，无换行提示不增加选择单位。正文字符选区不受行选择影响。
- 工作区行选择由仓库会话持有，只保存当前文件条目与暂存侧；成功重载时按完整块原文字节复用模型，块序号仅用于当前快照寻址。块头、前缀、内容或无换行标记改变即退役旧模型，文件扩展头和其它块的变化不影响未变块。
- 换文件 / 侧、关闭、阈值变化，以及开启着色时当前主题变化会清空选择；按行写入被接受后只清发起块，取消确认或拒绝入队不清。视图复用同时重绑行号、正文与计数，迟到读取和旧范围事件不能回写新范围。
- 普通重载不按整个快照指纹重建视图；语法任务仍以安全指纹和有效着色开关为身份，并在发布前检查取消。核心补丁写入的快照校验独立于显示选择。
- 选中行号取系统选中色；正文按有效 Diff 语法着色开关选择字色或底色，不能用语法片段是否已读完代替。整块跟踪悬停，只有可操作行号格使用手形光标。
- 组合 Diff 在核心保留全部父范围、逐父前缀与行号向量，App 按父顺序及最后的结果列显示；第一父 / 结果的双侧投影仍供语法着色使用。组合块只读，不能生成按行补丁或匹配可写行。
- 提交详情、储藏详情与文件历史的只读 Diff 共用 `ReadOnlyFileDiffView`
  - 工作区、文件历史和整页提交的独立单文件块头吸顶；变更集内嵌的块头随内容滚动
  - 块头高 32 pt，使用不透明的系统底色，分隔线绘制在高度内部；每个文件的首块无顶线，后续块仅在正常位置显示顶线，底线始终保留。吸顶状态从正文的自然位置判断，不依赖已浮动块头的位置
- 目录文件历史按完整变更集筛选真实新旧路径，每文件独立读取、放行与重试；当前提交和第一父提交的树条目决定目录范围与内容能力，不从 HEAD 推断历史类型。逐文件请求与可见登记有独立身份，换目标、关闭或重读时旧结果不能覆盖新状态。
- 语法着色经 `SyntaxHighlighter` 借用 highlight.js 的上下文执行
  - 最多两份上下文，每份是一个 `HighlightRuntime` actor，只在自己的串行队列上使用，由全局 actor `SyntaxActor` 负责借还
  - 一份被已取消的长任务占着时，新的请求由另一份接手
