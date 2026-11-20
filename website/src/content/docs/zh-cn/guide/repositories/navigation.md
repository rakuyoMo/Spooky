---
title: "窗口与导航"
description: "使用窗口与标签页、后退与前进、快捷操作、窗口恢复、程序坞菜单和 spooky:// 链接。"
---

这一页讲怎样同时开着几个仓库、在视图之间切换、用快捷操作跳到想去的地方，还有下次启动时怎样回到上次离开的地方。

## 窗口与标签页 {#windows}

每个窗口或标签页显示的要么是仓库管理，要么是一个仓库。

- :ui[menu.file > menu.newTab]（<kbd>⌘T</kbd>）新开一个显示仓库管理的标签页。标签栏末尾的添加按钮作用相同。
- :ui[menu.file > menu.newWindow]（<kbd>⌘N</kbd>）新开一个显示仓库管理的窗口。
- :ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）在当前窗口里显示仓库管理。

仓库已经开着时，再打开它会切换到显示它的那个窗口。还是想在第二个窗口里打开，就在仓库管理的列表里右键点按它，选 :ui[bookmarks.openNewWindow]{1="driftwood"}。

### 切换视图 {#views}

:ui[menu.view] 菜单用来切换仓库的各个视图：

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title]（<kbd>⌃⌘0</kbd>）打开活动窗口。里面列出 Spooky 执行过和正在执行的操作，见 [操作排队与活动](/guide/advanced/queue-activity/)。

## 后退与前进 {#back-forward}

每个窗口都记得你去过的视图与仓库，包括仓库管理。想原路返回：

- :ui[menu.view > navigation.back]（<kbd>⌘[</kbd>），或工具栏上的 :ui[toolbar.previous]
- :ui[menu.view > navigation.forward]（<kbd>⌘]</kbd>），或工具栏上的 :ui[toolbar.next]

后退之后再打开别的地方，原来可以前进到的那些位置就没有了。

## 快捷操作 {#quick-actions}

快捷操作让你输入几个字就找到想要的东西，直接对它执行操作，手不用离开键盘。窗口里显示着仓库时才能用。选 :ui[menu.file > quickActions.menu]（<kbd>⇧⌘A</kbd>），或点工具栏上的 :ui[toolbar.quickActions]。

::screenshot[快捷操作面板盖在仓库窗口上，输入框里是 “dark”。选中的第一个结果是分支 feature/dark-mode，右侧显示它的默认操作与查看更多操作的提示。下面依次是远端分支 origin/feature/dark-mode、深色外观、Default (Dark) 主题，以及两个说明里提到 dark 的提交。]{name="quick-actions" frame="window"}

什么都没输入时，面板依次列出仓库的各个视图、分支（当前分支在最前）、工作树、远端、子模块、远端分支、标签、储藏、身份档案、外观与主题。输入文字后列表会缩小，Spooky 还会查找：

- 当前分支里名称相符的文件
- 输入 5 到 64 个十六进制字符时，哈希以此开头的提交
- 当前分支上说明里含有这段文字的提交，最多 100 个

停止输入一会儿后，文件与提交会加到列表末尾。

面板里可以用这些按键：

| 按键 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 移动选中的行 |
| <kbd>↩</kbd> | 对选中的项执行默认操作 |
| <kbd>Tab</kbd>，或在文字末尾按 <kbd>→</kbd> | 列出选中项的全部操作 |
| 没有文字时按 <kbd>←</kbd>，或按 <kbd>⇧Tab</kbd> | 从操作列表返回 |
| <kbd>Esc</kbd> | 清空文字；没有文字时，从操作列表返回或关闭面板 |

列出的只有当前能执行的操作。

## 回到上次离开的地方 {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] 决定 Spooky 启动时显示什么：

| 选项 | Spooky 启动时 |
|---|---|
| :ui[settings.windowRestoration.always] | 重新打开你的窗口与标签页，每个都显示退出时的仓库与视图 |
| :ui[settings.windowRestoration.never] | 只显示仓库管理窗口 |
| :ui[settings.windowRestoration.system] | 按 macOS 里退出 App 时是否保留窗口的设置决定。这是默认的选项 |

恢复的仓库已经找不到时，它的窗口会说明仓库丢失了，见 [丢失的仓库](/guide/repositories/manager/#missing)。

打开 :ui[settings.showLaunchWindow] 后，Spooky 启动时还会打开一个列出最近仓库的窗口。连按其中一个，或选中后按 <kbd>↩</kbd>，就会打开它。有仓库窗口来到最前面后，这个窗口会自己关闭。

:::note[服务器仓库]
恢复的服务器仓库会在 Spooky 启动时重新连接服务器。
:::

## 最近的仓库与程序坞 {#recent}

:ui[menu.file > menu.openRecent] 列出你最近打开过的仓库，这台 Mac 上的与服务器上的都有。底部的 :ui[menu.clearRecent] 清空这份列表。仓库管理里的书签不受影响。

右键点按 **程序坞** 里的 Spooky 图标，菜单里有 :ui[menu.newWindow] 与最近的仓库。选一个仓库就会打开它，Spooky 还没运行时也一样。

也可以把文件夹拖到程序坞里的 Spooky 图标上，打开它所在的仓库。文件夹不在 Git 仓库里时，Spooky 会询问是否新建一个。

## 用链接打开 Spooky {#links}

以 `spooky://` 开头的链接能打开一个仓库，或者发起克隆。这种链接可以放在其它 App、脚本或笔记里。

### 打开仓库 {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` 必填，写仓库在这台 Mac 上的绝对路径。服务器仓库写成 `alias:path`。都要经过 URL 编码。
- `view` 可以不写。不写时，仓库打开后显示上次的视图。
- 有两种简写可以代替 `view`：`branch=<name>` 打开这个分支的历史，`commit=<hash>` 打开这个提交。

| `view` | 打开 | 其它参数 |
|---|---|---|
| `workingCopy` | 工作区 | |
| `history` | 历史 | `ref=<reference>`，完整的引用名，例如 `refs/heads/main`；可以写多个 |
| `commit` | 一个提交 | `commit=<hash>` |
| `stashes` | 储藏 | |
| `reflog` | Reflog | |
| `pullRequests` | Pull Request 或 Merge Request | |
| `branchesReview` | 分支整理 | |
| `settings` | 仓库设置 | |
| `remote` | 一个远端 | `remote=<name>` |
| `submodule` | 一个子模块 | `path=<path>` |
| `worktree` | 一个工作树 | `path=<path>` |
| `fileHistory` | 一个文件的历史 | `path=<path>` |
| `file` | 一个文件 | `path=<path>`，可以再加 `revision=<revision>`，还可以加 `mode=blame` 或 `mode=raw` |

例如，下面这个链接打开 `/Volumes/Projects/driftwood` 这个仓库里 `main` 分支的历史：

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### 克隆仓库 {#link-clone}

```
spooky://clone?url=<address>
```

这个链接会打开克隆对话框，地址已经填好。你选好放在哪里、点了 :ui[clone.submit] 之后才会开始克隆，见 [克隆仓库](/guide/repositories/manager/#clone)。

:ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] 设为 Spooky 时，github.com 上用桌面 App 打开仓库的链接也会打开这个克隆对话框。

链接用不了时，例如写了不认识的视图，或者给的是相对路径，Spooky 只显示 :ui[link.invalid.title]，不做别的事。

## 相关页面

- [界面一览](/guide/start/tour/)
- [仓库管理窗口](/guide/repositories/manager/)
- [键盘快捷键](/reference/shortcuts/)
