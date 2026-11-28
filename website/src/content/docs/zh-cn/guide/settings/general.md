---
title: "通用、更新与环境"
description: "认识设置窗口，以及通用、更新、环境三页的选项。"
---

设置对整个 Spooky 生效。大多数设置一改就生效，没有 “存储” 按钮。

## 设置窗口 {#window}

选 :ui[app.name > settings.title]（<kbd>⌘,</kbd>）。各页排在窗口顶部，窗口标题是当前这一页的名字。

| 页 | 设置什么 | 说明在 |
|---|---|---|
| :ui[settings.general] | 克隆、后台操作、确认、历史、文件列表与窗口 | [通用](#general) |
| :ui[settings.appearance] | 浅色或深色，以及应用图标 | [外观与主题](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Git 程序、全局的 Git 身份、签名，以及外部比较与合并工具 | [身份档案与 Git 配置](/guide/settings/identity/#git-config) |
| :ui[settings.text] | Diff 与文件里的语法着色、不可见字符与 Tab 宽度 | [外观与主题](/guide/settings/appearance/#text) |
| :ui[settings.editor] | 怎样检查提交信息、怎样折行 | [外观与主题](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Diff 与文件的配色和字体 | [外观与主题](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | 提交时可以换用的几个身份 | [身份档案与 Git 配置](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | GitHub 与 GitLab 账号 | [托管账号](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | 服务器的主机别名，保存在 `~/.ssh/config` 里 | [准备 SSH](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | github.com 的链接、SSH agent 与崩溃报告 | [集成](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | 本机 Git 用的环境变量，以及检查服务器的环境 | [环境](#environment) |
| :ui[settings.updates] | Spooky 怎样更新自己 | [更新](#updates) |

单个仓库的设置，比如它的身份与签名，在仓库窗口里。见 [仓库设置](/guide/settings/identity/#repository)。

## 通用 {#general}

:ui[settings.general] 页很长，下面几节按从上到下的顺序介绍。

::screenshot[设置窗口的通用页，列着克隆位置、终端程序、操作与确认的选项、历史与 Diff 的选项，以及文件列表的选项。]{name="settings-general" frame="window"}

### 克隆与终端 {#cloning}

| 设置 | 作用 |
|---|---|
| :ui[settings.cloneDirectory] | 克隆对话框建议把新仓库放在哪里。起初是个人文件夹。有 `~/Development` 的话，菜单里也会列出它。选 :ui[settings.cloneDirectory.select] 可以换成别的文件夹。 |
| :ui[settings.terminal] | :ui[action.openTerminal] 用哪个 App。见 [终端](/guide/settings/integration/#terminal)。 |

### 操作 {#operations}

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[settings.autoFetch] | 每 30 分钟 | Spooky 在后台获取的频率。见 [自动获取](/guide/branches/sync/#auto-fetch)。 |
| :ui[stash.offerAutoStash] | 打开 | 本地改动挡住操作时，问要不要先储藏它们。见 [自动储藏](/guide/work/stash/#auto-stash)。 |
| :ui[settings.autoUpdateSubmodules] | 关闭 | 操作挪动了已检出子模块的指针后，不问就更新它们。见 [在别的操作之后更新](/guide/advanced/submodules/#auto-update)。 |
| :ui[branch.cleanNames] | 打开 | 输入时把分支、标签与远端的名字改成 Git 接受的样子。见 [新建分支](/guide/branches/branches/#create)。 |
| :ui[settings.autoArchive] | 关闭 | 把看起来已经做完的分支归档。见 [自动归档](/guide/branches/review/#auto-archive)。 |

### 确认 {#confirmations}

下面这几个询问里都有 :ui[dialog.doNotAskAgain]。在询问里勾上它，这里对应的设置就关掉了。重新打开设置，询问就又会出现。四项起初都是打开的。

| 设置 | 在这之前先问 |
|---|---|
| :ui[settings.warnDiscardingChunks] | 丢弃块或行，任何仓库都算。见 [丢弃改动](/guide/work/diff/#discard)。 |
| :ui[settings.warnDiscardingOnServer] | 在服务器仓库里丢弃整个文件 |
| :ui[settings.warnDeletingOnServer] | 服务器没有废纸篓时，永久删除文件 |
| :ui[settings.warnRestoringOnServer] | 在服务器仓库里把文件恢复成某个版本。见 [从某个版本恢复文件](/guide/history/file-views/#restore)。 |

在本机仓库里丢弃整个文件，总是会先问。

### 历史与 Diff {#history}

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[history.pageSize] | 100 | 历史一次读入多少个提交：100、200、500 或 1000 |
| :ui[settings.dateFormat] | 绝对日期 | 绝对日期是简短的写法，如 2026/10/26。相对日期在今天和昨天写 “今天” “昨天”，其余日子写完整日期。菜单里各有一个示例。 |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | 合并提交的变更集显示什么。见 [变更集](/guide/history/commit-details/#changeset)。 |
| :ui[working.diffThreshold] | 20000 | Diff 超过这么多 kB 时，先问再显示。可以从菜单里选，也可以直接输入。见 [看懂 Diff](/guide/work/diff/#read)。 |

日期格式作用于历史、储藏、文件历史与 Reflog。

### 文件列表 {#file-list}

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | 也可以改成在比较工具里打开 |
| :ui[files.openSubmodules] | 打开 | 连按子模块时在 Spooky 里打开它，不交给别的 App |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | 也可以改成用快速查看预览文件 |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | 也可以选 :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | 也可以改成省略长文件名的中间 |

它们在工作区里的效果见 [文件列表的设置](/guide/work/working-copy/#settings)。

### 窗口与仓库管理 {#windows}

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Spooky 启动时重新打开什么。见 [回到上次离开的地方](/guide/repositories/navigation/#restore)。 |
| :ui[settings.showLaunchWindow] | 关闭 | Spooky 启动时显示一个列出最近仓库的窗口 |
| :ui[settings.showWorktreesInRepositoryList] | 关闭 | 在仓库管理里列出每个仓库的工作树 |
| :ui[settings.showHostAliasesInRepositoryList] | 打开 | 在仓库管理里显示每个服务器仓库的主机别名 |
| :ui[settings.showDeveloperMenu] | 关闭 | 加上 :ui[menu.developer] 菜单，里面是测试 Spooky 自身用的工具 |

## 更新 {#updates}

:ui[settings.updates] 页设置更新通道、是否自动检查与下载更新，以及多久检查一次。各项的说明见 [保持更新](/guide/start/install/#updates)。

## 环境 {#environment}

从访达或程序坞打开的 App，拿不到你在终端里的环境。比如 `PATH` 里可能少了 `/opt/homebrew/bin` 这样的文件夹，Git 钩子、凭据助手与 Git LFS 就可能找不到。:ui[settings.environment] 页为本机的 Git 补上这些。

### 本机的变量 {#local-variables}

| 设置 | 作用 |
|---|---|
| :ui[settings.environment.loginShell] | 启动一次你的登录 shell，读出它的启动文件设置的变量，交给 Git 与工具栏按钮的脚本。下方的表格列出读到了什么。起初是打开的。 |
| :ui[settings.environment.custom] | 你自己加的变量。点添加按钮加一个，点移除按钮移除选中的那个。它们会覆盖登录 shell 里的同名变量。 |

还有几点：

- 改动从下一条 Git 命令开始生效，不用重启 Spooky。
- 每次 Spooky 启动时，都会重新读取登录 shell。读取失败时，页面上会写出来。
- 两个自定义变量同名时，靠下的那个生效。名字不合法的变量留在表格里，但不会交给 Git。
- 想用系统之外的 SSH agent，在这里或登录 shell 里设置 `SSH_AUTH_SOCK`。见 [SSH agent](/guide/settings/integration/#ssh-agent)。

:::note[服务器仓库]
这些变量只作用于本机的 Git 与工具栏按钮的脚本。服务器上的 Git 用服务器自己的环境。
:::

### 检查服务器 {#server-check}

在页面底部，不添加仓库也能看到 Git 在服务器上拿到的环境：

1. 在 :ui[remote.host] 旁边的输入框里填主机别名，也可以从 :ui[settings.environment.server.hosts] 菜单里选一个。这个菜单列出你的服务器仓库所在的服务器。
2. 点 :ui[settings.environment.server.check]。

::screenshot[设置窗口环境页底部的服务器检查。检查过一个主机别名，结果显示服务器上找到的 Git 及其版本。]{name="settings-environment" frame="closeup"}

结果里有 SSH 登录时找到的 Git 及其版本，找不到时写 :ui[settings.environment.server.noGit]。下面是 `PATH` 里的每个文件夹，以及以 `GIT_` 开头的变量名。找不到 Git 时，见 [服务器上找不到 Git](/reference/troubleshooting/#server-path)。

## 相关页面

- [外观与主题](/guide/settings/appearance/)
- [身份档案与 Git 配置](/guide/settings/identity/)
- [集成](/guide/settings/integration/)
- [安装 Spooky](/guide/start/install/)
