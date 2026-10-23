# AGENTS.md

本文件是协作 Agent（Claude Code、Codex 等）在本仓库工作时的指引，同时也是人类阅读的协作规范源。

## 项目概述

Spooky 是一个原生 macOS Git 客户端：既能打开本机仓库，也能经 SSH 直接操作另一台机器上的仓库。

- `Spooky` 是可运行的桌面 App；`SpookyKit` 核心库负责在本机或远端执行 Git、读取工作区状态并解析输出
- 当前 App 支持本机与服务器工作区、混合最近记录、连接体检、断线重连与写入核对、Diff、文件 / 块 / 行操作、提交与冲突收尾、分页历史、分支、同步、合并预览、Activity、文件监听与轮询刷新、按仓库恢复的视图状态、终端与默认主题设置，并可打包发布用 App；产品按 M1–M10 逐步完成 `1.0.0`
- 远端仓库的工作区留在远端机器，客户端经系统 SSH、用 `~/.ssh/config` 中的主机别名访问
- 纯开源的个人工具，只在 GitHub 分发
- 许可证为 [GPL-3.0](LICENSE)
  - 引入外部代码前先确认许可证与 GPL-3.0 兼容，并保留所需的版权与许可声明

## 技术栈与环境

- Swift 6.2，工程由 Swift Package Manager 管理
- `SpookyKit` 的最低平台为 macOS 26，定义于 `SpookyKit/Package.swift`
- Git 子进程通过 [swift-subprocess](https://github.com/swiftlang/swift-subprocess) 启动
- 单元测试使用 Swift Testing（`import Testing`），不使用 XCTest
- `Spooky` executable target 使用 AppKit 管理窗口、分栏、工具栏和菜单，SwiftUI 承载内容
- App 的 Bundle Identifier 为 `com.rakuyo.spooky`；`Info.plist` 嵌入可执行文件，开发 Bundle 由 `scripts/build-app.sh` 生成，发布 Bundle 由 `scripts/bundle.sh` 生成
- 界面资源位于 `SpookyKit/Sources/Spooky/Resources/`，支持 `en`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`de`、`fr`、`es`，默认跟随系统并以英文回退

### `mise`

根目录的 `mise.toml` 定义构建、测试、打包与代码规范检查的 task，这些操作优先经 `mise run` 执行。

- 没有对应 task 的 Swift 命令直接执行
- 纯 shell 命令不经 `mise` 执行
- 本机专用的配置写进 `mise.local.toml`（已列入 `.gitignore`）

## 常用命令

命令都在仓库根目录执行，用 `--package-path` 指定包目录，不切换工作目录。

| 命令 | 作用 |
|---|---|
| `mise run build` | 编译核心库与 App |
| `mise run test` | 运行核心库、会话状态与本地化测试 |
| `mise run swift:lint` | 检查代码规范 |
| `mise run swift:format` | 按代码规范格式化，并自动修复可修复的问题 |
| `SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteConnectionTests` | 显式运行 `spooky-test` 远端集成测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteWorkingCopyTests` | 显式运行 M3 的 SFTP 与远端提交测试 |
| `SPOOKY_REMOTE_TESTS=1 swift test --package-path SpookyKit --filter RemoteHistorySyncTests` | 显式运行 M4 的服务器历史、同步与取消测试 |
| `swift build --package-path SpookyKit --product Spooky` | 编译可执行 App product |
| `swift run --package-path SpookyKit Spooky` | 启动 App 的仓库管理窗口 |
| `./scripts/build-app.sh` | 生成开发用 `SpookyKit/.build/Spooky.app` |
| `mise run bundle` | release 构建并生成 `build/Spooky.app`，拷贝资源与图标后 ad-hoc 签名并校验 |
| `SPOOKY_PERFORMANCE_TESTS=1 swift test --package-path SpookyKit -c release -Xswiftc -enable-testing --filter PerformanceTests` | 显式运行大仓库首屏、历史分页与内存的性能验收 |
| `swift scripts/make-icon.swift SpookyKit/Sources/Spooky/AppIcon.icns` | 重新生成静态应用图标 |

## 目录结构

```
SpookyKit/                    核心库与 App 的 Swift Package
  Package.swift               Swift Package 定义与平台、依赖配置
  Package.resolved            依赖版本锁定
  Sources/SpookyKit/          库源码
    RepositoryLocation.swift  本机或 SSH 远端仓库位置
    GitRunner.swift           本机 / 远端 Git 命令执行
    CommandExecutor.swift     异步子进程、管道收集与取消
    GitCommandResult.swift    命令结果、错误分类与流式输出事件
    RepositoryOperationQueue.swift 仓库写队列、主机并发限制与操作事件
    RemoteConnection.swift    SSH 主连接、体检、重连与远端取消
    RemoteConnection+HealthCheck.swift 经主连接依次检查远端 Git、路径权限、工作区与状态格式
    SSHConfiguration.swift    SSH 参数及远端环境清洗
    CallbackRelay.swift       本机 Unix socket 回调服务
    RemoteOutputFilter.swift  远端完成帧与退出状态解析
    RemoteOutputRedactor.swift 中继凭据的跨输出块脱敏
    RemoteConnectionError.swift 连接分类与服务器仓库身份
    Resources/spooky-remote.pl 远端进程组与回调客户端
    LocalRepository.swift     Git 最低版本检查与本机工作区识别
    WorkingCopyStatus.swift   porcelain v2 工作区状态模型与解析
    RepositoryDiff.swift      按字节解析 Diff 与生成选区补丁
    WorkingCopyOperations.swift 工作区写操作、快照校验、身份与进行中状态
    RepositoryFiles.swift     本机文件访问与复用主连接的 SFTP 传输
    RepositoryHistory.swift   NUL 历史分页、提交变更集与第一父 Diff
    CommitGraph.swift         与界面解耦的增量提交图
    RepositoryReferences.swift 引用快照、分支读写与双向计数
    RepositorySync.swift      Fetch、Pull、Push、合并与预览
    LocalGitAuthentication.swift 本机凭据回调与 SSH agent 接入
    ImmutableReadCache.swift  只由对象哈希决定的读取结果缓存
  Sources/Spooky/             App 入口、窗口协调、会话状态与各内容视图
    Info.plist                应用身份和支持语言
    AppIcon.icns              静态应用图标，由 scripts/make-icon.swift 生成
    Resources/                各语言文案、系统权限说明、命名色与内置主题 JSON
  Tests/SpookyKitTests/       单元测试（Swift Testing）
    Fixtures/                 固定的 Git 输出夹具
  Tests/SpookyTests/          会话生命周期、最近记录、错误呈现与本地化测试
scripts/build-app.sh          开发 App Bundle 生成脚本
scripts/bundle.sh             发布 App Bundle 生成脚本，输出到 build/Spooky.app
scripts/make-icon.swift       应用图标生成脚本
.github/workflows/ci.yml      PR 与 main 上的代码规范检查、编译、测试与打包
mise.toml                     构建、测试、打包与代码规范检查的 task
docs/testing/M1.md            M1 的 App 手动验收步骤
docs/testing/M2.md            M2 的连接、终端与主题验收步骤
docs/testing/M3.md            M3 的工作区、Diff、提交与冲突验收步骤
docs/testing/M4.md            M4 的历史、分支、同步与活动验收步骤
docs/testing/M5.md            M5 的集成、恢复、性能、可访问性与发布前验收步骤
README.md                     英文 README：介绍、功能、系统要求、构建、权限、工作原理、开发与贡献说明
README-ZH.md                  README.md 的简体中文版，与它同步修改
LICENSE                       GPL-3.0 许可证全文
```

## 开发注意事项

### 本机与远端仓库

- git 调用一律经 `GitRunner` 执行：`run(_:input:)` 保持只返回 stdout 的 API，`execute(_:input:acceptedExitCodes:onOutput:)` 返回完整结果并提供流式数据块；`operation` 提供有界进度事件流、完整结果和主动取消
- 本机调用 `/usr/bin/git`；`openLocalRepository()` 先检查最低版本 `2.41.0`，再通过 Git 识别工作区根目录；UI 不组装进程参数
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
- 改动 App 时还须运行 `swift build --package-path SpookyKit --product Spooky`，按 [M1 验收步骤](docs/testing/M1.md) 实际启动、操作并截图；未执行的检查明确记录为未验证
- M2 的服务器、终端与主题场景见 [M2 验收步骤](docs/testing/M2.md)；远端测试默认不跑，必须通过 `SPOOKY_REMOTE_TESTS=1` 显式开启
- M3 的本机 / 服务器提交闭环、行选择、确认与冲突收尾见 [M3 验收步骤](docs/testing/M3.md)
- M4 的分页历史、分支、同步、合并预览、活动日志与取消见 [M4 验收步骤](docs/testing/M4.md)
- M5 的跨视图一致性、错误恢复、性能、可访问性与发布检查见 [M5 验收步骤](docs/testing/M5.md)；性能测试默认不跑，通过 `SPOOKY_PERFORMANCE_TESTS=1` 显式开启
- 解析器的固定输入放在 `Tests/SpookyKitTests/Fixtures/`，由真实 Git 在隔离配置、固定身份与时间的临时仓库中生成
- 远端实测只使用 `spooky-test` 和测试专用密钥，写入仅限 `/Users/wgy/spooky-test/`、`~/.spooky/` 与会话临时目录；不分配 PTY，不转发 agent，不修改双方 SSH 和全局 Git 配置
- 本地化新增资源键时同步全部支持语言，并保持格式参数一致；动态拼接的资源键登记在 `LocalizationTests.dynamicKeys`；错误标题和恢复说明本地化，Git 原文保持不变

### 版本号

- 版本号写在 `SpookyKit/Sources/Spooky/Info.plist`：`CFBundleShortVersionString` 是对外版本号，`CFBundleVersion` 是正整数构建号
- 1.0.0 之前，完成里程碑 Mn 的 PR 把 `CFBundleShortVersionString` 改为 `0.n.0`，如 M5 为 `0.5.0`、M10 为 `0.10.0`
- 1.0.0 由维护者确认后手动发起发布

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

代码风格以 [RakuyoKit/swift](https://github.com/RakuyoKit/swift) 为准；运行过任一 `mise run` task 后，规则原文位于 `SpookyKit/.build/checkouts/swift/Sources/RakuyoSwiftFormatTool/`。

- 新建或编辑 `.swift` 文件后，运行 `mise run swift:lint`；不通过时先运行 `mise run swift:format` 自动修复，再运行 `mise run swift:lint`
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
