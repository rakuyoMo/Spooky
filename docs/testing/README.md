# 测试

## 自动测试

`mise run test` 运行默认开启的测试：

- `Tests/SpookyKitTests/`：核心库的单元测试，以及在临时仓库里运行的本机 Git 测试；解析器的固定输入在 `Fixtures/`
- `Tests/SpookyTests/`：App 的会话、窗口、导航、设置、本地化等测试
- `Tests/ReleaseTests/`：发布检查、发版脚本与更新清单合成的测试，在临时仓库与临时目录里运行 `scripts/` 下的脚本

`Tests/TestSupport/` 是两个测试目标共用的工具：等待主线程状态的 `until`、让脚本里的命令停在闸门上的 `ProcessGate`、直接写出空仓库 `.git` 的 `RepositoryTemplate`。App 测试还链接 `Tests/InvisibleWindows/`：测试进程里的窗口一律透明、sheet 不播动画，运行期间屏幕上不出现窗口。

测试不给单项测试或等待设时间上限；某个测试卡住时，CI 的测试 job 在 30 min 后结束。本机运行时，输出里只有开始、没有结束的测试就是卡住的那一项。

Git LFS 的测试只在 `PATH` 或 Homebrew 的目录里找得到 `git-lfs` 时运行，找不到时跳过。

经辅助功能接口读本进程窗口的测试（表单行的名称、账号对话框里下拉的位置、对话框底栏的进度文字、对话框头部与错误文字的位置、克隆对话框选项区的位置、应用图标一行的名称与图标列表的选中），只在运行测试的进程有辅助功能权限时运行，没有时跳过；在终端里运行时，权限跟随终端程序。

CI 把测试的事件流存成产物 `test-events-<第几次运行>`，每个测试开始与结束的事件都带着发生的时间（`instant.since1970`）。CI 日志里每行的时间是这行输出写出的时间，测试的输出会攒成整块再写，看先后与停顿以事件流为准：

```sh
gh run download <运行编号> -n test-events-1
```

## 显式开启的测试

以下测试默认跳过，用环境变量开启。

### 服务器

需要一台测试专用的服务器：

- `~/.ssh/config` 中有主机别名 `spooky-test`
- 使用测试专用的密钥 `~/.ssh/spooky-test_ed25519` 认证
- 可以读写服务器上的 `/Users/wgy/spooky-test/`

每次运行只在这个目录下新建并清理自己的子目录，不修改双方的 SSH 配置、`known_hosts` 与全局 Git 配置。

`SPOOKY_REMOTE_TESTS=1 swift test` 运行全部测试，包括服务器测试；只运行其中一组时加上 `--filter`：

```sh
SPOOKY_REMOTE_TESTS=1 swift test --filter RemoteConnectionTests
```

服务器测试会同时新建多条 SSH 连接；服务器往返延迟高时，这些连接可能超出 sshd 默认的 `MaxStartups` 而被断开，这时加 `--no-parallel` 串行运行。

| 测试套件 | 覆盖 |
|---|---|
| `RemoteConnectionTests` | 连接、连接体检、断线恢复与回调 |
| `RemoteWorkingCopyTests` | SFTP、服务器提交与服务器文件缓存 |
| `RemoteHistorySyncTests` | 历史、同步与取消，以及 Sync、变基、安全强推、Push To、不询问用户的获取与停在冲突上的合并 |
| `RemoteBranchSyncTests` | 分支的新建、跟踪、改名与删除，两种获取映射的清理，只有未跟踪文件的拉取与合并，租约拒绝，自动储藏，获取的取消与断线，自动获取的远端筛选 |
| `RemoteWorkingCopyFilesTests` | 文件操作与应用补丁 |
| `RemoteDiffTests` | Diff 选项与图片 |
| `RemoteStashTests` | 储藏与 Auto Stash 的断线 |
| `RemoteConflictTests` | 冲突向导、合并工具结果的写回、进行中操作的分类、用编辑后的信息继续、空提交与断线 |
| `RemoteFileViewsTests` | 文件历史、Blame、原文与 NFD 路径 |
| `RemoteCommitSigningTests` | 提交签名 |
| `RemoteHistorySearchTests` | 历史搜索、计数与可达性 |
| `RemoteHistoryDetailsTests` | 合并 Diff、文件树、比较、签名与导出 |
| `RemoteSidebarTests` | 标签说明、分支状态、置顶归档与标签检出 |
| `RemoteReferenceManagementTests` | 分支、标签与远端管理，同名分支的跟踪检出、父分支、归档与撤销、非 HEAD 分支的安全强推与单分支推送 |
| `RemoteRewriteTests` | 反转、摘取、重置、交互式变基与修补旧提交 |
| `RemoteBranchesReviewTests` | 分支比较、分叉点、归档标记与 Update Branch |
| `RemoteReflogUndoTests` | Reflog 与撤销、重做 |
| `RemoteHostOperationsTests` | 列目录、新建、扫描与克隆 |

### github.com

在测试仓库里推送临时分支，新建、评论、修改、检出、合并与关闭 Pull Request，结束后删掉这些分支：

```sh
SPOOKY_GITHUB_TESTS=1 SPOOKY_GITHUB_TOKEN=<令牌> SPOOKY_GITHUB_REPOSITORY=<owner/repo> swift test --filter GitHubLiveTests
```

### 性能

生成一个包含 10 万个文件、6 万个提交的临时仓库，检查首屏、历史分页的耗时与内存占用；服务器上的场景另需 `SPOOKY_REMOTE_TESTS=1`：

```sh
SPOOKY_PERFORMANCE_TESTS=1 swift test -c release -Xswiftc -enable-testing --filter PerformanceTests
```

## 手动验收

| 文档 | 范围 |
|---|---|
| [M1](M1.md) | App 的启动、打开本机仓库与刷新 |
| [M2](M2.md) | 服务器连接、终端与主题 |
| [M3](M3.md) | 工作区、Diff、提交与冲突 |
| [M4](M4.md) | 历史、分支、同步与活动 |
| [M5](M5.md) | 集成、恢复、性能、可访问性与发布前检查 |
| [M6](M6.md) | 工作区、Diff、主题、储藏、冲突向导、文件视图与提交体验 |
| [M7](M7.md) | 历史、提交详情、侧边栏、引用、同步、改写、分支整理、Reflog 与撤销 |
| [M8](M8.md) | 仓库管理、窗口与导航、外部工具、链接、设置、帮助与发布更新 |
| [M9](M9.md) | 托管账号、Pull Request 与 Merge Request、发布仓库、Issue 补全、分支整理的协作状态、子模块、工作树与 Git LFS |
| [M10](M10.md) | 工作区状态头与提交人、丢弃与删除进废纸篓及撤销、服务器仓库的确认、修补、硬折行与冲突向导 |
| [M11](M11.md) | 历史续载与回到很靠后的提交、版本选择器、补丁、去掉完全合并、推送与发布、后台自动获取、对话框头部与 Activity 的分页 |
| [M12](M12.md) | 去掉的功能、主题、Dock 与打开文件、系统通知、新功能卡片、开发者菜单、Show in Finder 与远程编辑器、仓库设置、终端与外部工具、Activity、撤销、子模块菜单、Dock 图标与关于窗口 |
| [M13](M13.md) | 私有部署 GitLab 的版本与用户名密码登录、账号令牌用于 Git 认证、请求的讨论与右键菜单、托管服务的对话框、对话框对齐输入列与侧边栏的活动区 |
| [M14](M14.md) | 主菜单的系统项、标题、分组与快捷键，Open Recent 与 Clear Menu，显示仓库管理时的视图切换；工具栏的标签、提示、可见优先级、Fetch / Pull / Push / Push To / Force Push 的图标、跟随内层分栏的分隔符、内层分栏的列表停在工具栏下沿与刷新中的 Refresh；丢失页的自动重试，File › Open… 的面板与新建询问，侧边栏的首次宽度，New Window 开成标签页；对话框骨架，引用、子模块、工作树、LFS 与克隆对话框的版式、标题与主按钮；分支与同步对话框的标题、主按钮、宽度、表单间距与下拉宽度；改写、版本、储藏、工作区文件、外部工具选择与添加服务器仓库的对话框；会话里确认的标题、主按钮与 Do not ask me again；其余询问的确认版、备选底栏与按钮放不下时的加宽；Git 错误框的标题、说明、原文区与拉大，恢复说明、无效链接与 Local Folder 的提示版；History 筛选的引用消失后侧边栏按行号选中接替的行，后退 / 前进到这种 History 时留在当前视图；回调中继的认证询问与编辑器中继的对话框；空状态的间距、位置、颜色、背景与按钮行 |
| [M15](M15.md) | 语言识别、头文件语法、按内容识别的字符数边界、Diff 两侧着色与语法记号颜色；主题色的色彩空间、推导色与颜色面板的往返保存；文件头部、原生动作组与重命名显示；目录文件历史、对象能力与精确补丁路径；变更集计数、部分展开与空行；可见详情的菜单路由与自动展开阈值；块内字符复制、折行与行号键盘 / 辅助功能；组合 Diff 多父列、文件头摘要与大 Diff 警告；工作区单文件快照安全边界、块头吸顶与分隔线；行选择、提示联动、末行补丁与按块原文跨重载保留；不可见字符、真实行尾与源串复制 |
| [M16](M16.md) | 提交区的计数、提交进度与头像，进行中操作的分类、步数与横幅，Show only conflicts，合并冲突直接显示工作区与自动储藏后的冲突，提交信息的注释询问与编辑后继续，两种空提交确认，冲突向导的版本卡片、选择、版本菜单与外部比较，历史中旧提交的 Amend 与 Edit 停顿 |
| [M17](M17.md) | 分支名的规范化与校验原因，新建、跟踪、改名与删除分支的对话框，获取的临时预选与保存的偏好、添加远端后获取，拉取与合并的候选、冲突预览与未跟踪文件，推送 HEAD 的 Destination、发布与没有远端时的入口，按远端计时的自动获取，自动储藏默认不恢复改动 |
| [M18](M18.md) | Working Copy 行的标记、提示与右键菜单，分支、文件夹与分组标题的菜单和 ⌘⌫ 删除，双击、定位与同名分支的跟踪检出，引用的公共顺序与侧边栏默认值，父分支子菜单，归档建议与归档对话框，拖放落点、拖动影像上的动作名与 Push Branch |
| [M19](M19.md) | 设置窗口各页居中、按冒号对齐的表单与组距、分隔线与弹出菜单图标，大 Diff 阈值组合框，Editor 的折行与插件说明，Environment 表格；Working Copy 分支栏、提交区、标题框与正文框，视图选项按钮；侧边栏三档行高、分组标题与计数徽标；关于窗口的说明文字；刷新时历史、变更集、储藏、比较与文件历史保持选中、展开与滚动位置 |
| [M20](M20.md) | Appearance 页的应用图标一行与图标列表，两组图标在运行中与没运行时的 Dock、⌘Tab 与 Finder 里的显示，自定义图标的写入、清除与写不进去时的提示 |
| [M20.5](M20.5.md) | 方向键跟着焦点走，历史列表的选中、日期与分隔线，变更文件的状态图标、选中与分隔线，Working Copy 的行间分隔线，对话框高度变化的动画，工具栏的关闭仓库项，Dock 菜单的最近仓库 |
