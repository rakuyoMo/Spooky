# 测试

## 自动测试

`mise run test` 运行默认开启的测试：

- `Tests/SpookyKitTests/`：核心库的单元测试，以及在临时仓库里运行的本机 Git 测试；解析器的固定输入在 `Fixtures/`
- `Tests/SpookyTests/`：App 的会话、窗口、导航、设置、本地化等测试
- `Tests/ReleaseTests/`：发布检查、发版脚本与更新清单合成的测试，在临时仓库与临时目录里运行 `scripts/` 下的脚本

Git LFS 的测试只在 `PATH` 或 Homebrew 的目录里找得到 `git-lfs` 时运行，找不到时跳过。

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

| 测试套件 | 覆盖 |
|---|---|
| `RemoteConnectionTests` | 连接、连接体检、断线恢复与回调 |
| `RemoteWorkingCopyTests` | SFTP、服务器提交与服务器文件缓存 |
| `RemoteHistorySyncTests` | 历史、同步与取消，以及 Sync、变基、安全强推、Push To 与不询问用户的获取 |
| `RemoteWorkingCopyFilesTests` | 文件操作与应用补丁 |
| `RemoteDiffTests` | Diff 选项与图片 |
| `RemoteStashTests` | 储藏与 Auto Stash 的断线 |
| `RemoteConflictTests` | 冲突向导与断线 |
| `RemoteFileViewsTests` | 文件历史、Blame、原文与 NFD 路径 |
| `RemoteCommitSigningTests` | 提交签名 |
| `RemoteHistorySearchTests` | 历史搜索、计数与可达性 |
| `RemoteHistoryDetailsTests` | 合并 Diff、文件树、比较、签名与导出 |
| `RemoteSidebarTests` | 标签说明、分支状态、置顶归档与标签检出 |
| `RemoteReferenceManagementTests` | 分支、标签与远端管理 |
| `RemoteRewriteTests` | 反转、摘取、重置与交互式变基 |
| `RemoteBranchesReviewTests` | 分支比较、分叉点、归档标记与 Update Branch |
| `RemoteReflogUndoTests` | Reflog 与撤销、重做 |
| `RemoteHostOperationsTests` | 列目录、新建、扫描与克隆 |

### github.com

在测试仓库里推送临时分支，新建、评论、修改、检出、合并与关闭 Pull Request，结束后删掉这些分支：

```sh
SPOOKY_GITHUB_TESTS=1 SPOOKY_GITHUB_TOKEN=<令牌> SPOOKY_GITHUB_REPOSITORY=<owner/repo> swift test --filter GitHubLiveTests
```

### 性能

生成一个包含 10 万个文件、5 万个提交的临时仓库，检查首屏、历史分页的耗时与内存占用；服务器上的场景另需 `SPOOKY_REMOTE_TESTS=1`：

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
