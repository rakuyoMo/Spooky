---
title: "集成"
description: "选择外部比较与合并工具、编辑器和终端，设置与访达的集成。"
---

Spooky 能与 Mac 上的其它 App 配合：浏览器、比较与合并 App、编辑器、终端，以及访达。这一页说明各自在哪里设置。

## 集成页 {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] 里有三项设置。

### 来自 github.com 的链接 {#github-links}

在 github.com 上，仓库页面里那个用桌面 App 打开仓库的按钮，会给你的 Mac 发一个链接。:ui[settings.github] 决定由哪个 App 接收它。菜单里列出这台 Mac 上能打开这种链接的 App。

选 Spooky，这些链接就会打开克隆对话框。见 [克隆仓库](/guide/repositories/navigation/#link-clone)。

### SSH agent {#ssh-agent}

SSH agent 存着已经解锁的密钥。Spooky 经 SSH 登录服务器和远端、用 SSH 密钥为提交签名时，都用它。

:ui[settings.sshAgent] 只有一个选项：:ui[settings.sshAgent.system]。Spooky 按下面的顺序找它：

1. :ui[settings.environment] 页里你自己加的 `SSH_AUTH_SOCK`（见 [本机的变量](/guide/settings/general/#local-variables)）
2. 从登录 shell 读到的 `SSH_AUTH_SOCK`，前提是那里打开了读取
3. macOS 替你启动的 agent

想用别的 agent，比如密码管理器带的那个，就在 :ui[settings.environment] 页或登录 shell 里设置 `SSH_AUTH_SOCK`。

agent 没在运行时，菜单旁边会出现黄色的警告按钮。点它可以看到该怎么办。

:::note[服务器仓库]
Spooky 从不把你的 agent 转发到服务器。服务器上的 Git 用那台机器自己的 agent 与密钥。
:::

### 崩溃报告 {#crash-reports}

Spooky 上次意外退出时，下次启动会问要不要报告这次崩溃。勾选 :ui[settings.crashReports.always]，就不再问，直接打开问题页。起初是关闭的。

报告里有什么，见 [崩溃报告](/reference/data-privacy/#crash-reports)。

## 比较与合并工具 {#diff-merge-tools}

这些工具在 :ui[settings.gitConfig] 页设置。

| 设置 | 作用 |
|---|---|
| :ui[externalTool.diffTool] | 用来比较文件的 App。起初是 :ui[externalTool.noneSelected]。 |
| :ui[externalTool.directoryDiff] | 比较多个文件时，在一个窗口里把它们当作两个文件夹打开。只有 Kaleidoscope 支持。别的 App 一次打开一个文件。起初是打开的。 |
| :ui[externalTool.mergeTool] | 用来解决冲突的 App。起初是 :ui[externalTool.noneSelected]。 |
| :ui[externalTool.keepBackups] | 在文件旁边留一份合并前的样子，文件名末尾加 `.orig`。起初是关闭的。 |

Spooky 支持这些 App：

| App | 比较 | 合并 |
|---|---|---|
| Araxis Merge | 支持 | 支持 |
| BBEdit | 支持 | 不支持 |
| Beyond Compare | 支持 | 支持 |
| DeltaWalker | 支持 | 支持 |
| FileMerge | 支持 | 支持 |
| Kaleidoscope | 支持 | 支持 |
| P4Merge | 支持 | 支持 |
| TextMate | 支持 | 不支持 |
| Visual Studio Code | 支持 | 支持 |

菜单里也会列出没安装的 App，但选不了。还没选工具就用到它时，Spooky 会问用哪个 App。

怎样使用，见 [在别的 App 里比较](/guide/work/diff/#external) 与 [在别的 App 里合并](/guide/work/conflicts/#merge-tool)。

## 编辑器 {#editors}

Spooky 没有单独的编辑器设置。想用别的 App 打开文件，在工作区里右键点按它，选 :ui[files.open] 或 :ui[files.openWith]。:ui[files.openWith] 子菜单列出能打开这个文件的 App，默认的那个排在最前。提交的文件树与冲突向导里也有同样的子菜单。

在服务器仓库里，Visual Studio Code、Visual Studio Code Insiders 与 Cursor 装了 Remote SSH 扩展时，会直接打开服务器上的文件。别的 App 拿到的是一份副本，保存时 Spooky 把改动写回服务器。见 [终端与其它 App](/guide/server/local-location/#terminal)。

## 终端 {#terminal}

:ui[settings.general] 页的 :ui[settings.terminal] 决定 :ui[action.openTerminal] 用哪个 App。Spooky 支持 Terminal、iTerm、Warp、Ghostty、WezTerm 与 Otty，菜单里只列出已安装的。起初用 Terminal。

这些地方有 :ui[action.openTerminal]：

- :ui[menu.file] 菜单
- 工具栏里的 :ui[toolbar.terminal]
- 侧边栏里工作区的菜单
- 工作区文件列表里文件或文件夹的菜单。终端打开在那个文件夹，或者文件所在的文件夹。
- 仓库管理窗口里仓库的菜单，以及最近克隆的菜单
- 侧边栏里工作树的菜单
- [快捷操作](/guide/repositories/navigation/#quick-actions)

本机仓库的终端打开在这台 Mac 上的文件夹里。服务器仓库则经 SSH 登录，进入服务器上的文件夹。见 [终端与其它 App](/guide/server/local-location/#terminal)。

Spooky 第一次打开 Terminal 或 iTerm 时，macOS 会问是否允许 Spooky 控制它。不允许的话，Spooky 会显示 :ui[error.terminal]。之后想允许，选 **苹果菜单 › 系统设置 › 隐私与安全性 › 自动化**，在 Spooky 下面打开那个 App。

## 访达 {#finder}

- **显示文件夹**：:ui[action.revealFinder] 在访达里显示仓库文件夹或文件。服务器仓库需要有本机位置，见 [在访达中显示](/guide/server/local-location/#show-in-finder)。
- **添加仓库**：把仓库文件夹从访达拖进仓库管理窗口。见 [添加仓库](/guide/repositories/manager/#add)。
- **程序坞**：把文件夹拖到 Spooky 的图标上，打开它所在的仓库。右键点按图标，可以选一个最近的仓库，服务器仓库也在里面。见 [最近的仓库与程序坞](/guide/repositories/navigation/#recent)。
- **主题**：在访达里打开 `.spookytheme` 文件，就能添加主题。见 [分享主题](/guide/settings/appearance/#share-themes)。

## 相关页面

- [通用、更新与环境](/guide/settings/general/)
- [身份档案与 Git 配置](/guide/settings/identity/)
- [本机位置](/guide/server/local-location/)
- [准备 SSH](/guide/server/prepare-ssh/)
