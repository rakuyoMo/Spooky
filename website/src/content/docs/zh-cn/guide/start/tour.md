---
title: "界面一览"
description: "认识仓库管理窗口与仓库窗口：侧边栏、工具栏、三栏和快捷操作。"
---

Spooky 的窗口显示两样东西：仓库管理和仓库。仓库管理列出你所有的仓库，仓库窗口是你实际干活的地方。这一页介绍两者的各个部分，手册的其它页都用这些叫法。

## 仓库管理窗口 {#repositories-window}

第一次打开 Spooky 时，窗口显示仓库管理。侧边栏在 :ui[repositories.title] 下列出你的仓库。仓库可以分进不同的分组。

- 选中一个仓库，右边显示它的详情：位置、上次打开的时间、最近的提交、当前分支与改动、远端。
- 选中一个分组或什么都不选，右边是一块写着 :ui[bookmarks.dropZone.title] 的区域，下面有 :ui[bookmarks.dropZone.add]、:ui[action.addRemote]、:ui[bookmarks.dropZone.create] 与 :ui[bookmarks.dropZone.clone] 几个按钮。
- 侧边栏底部的添加按钮用来添加分组与仓库。

连按一个仓库就能打开它。仓库在同一个窗口里打开，取代仓库管理。想回到列表，点侧边栏上方的 :ui[toolbar.bookmarks]。[仓库管理窗口](/guide/repositories/manager/) 详细介绍这个列表。

## 仓库窗口 {#repository-window}

打开仓库后，窗口标题显示仓库的名称。下面一行是当前的视图和简短的摘要，例如分支与改动文件的数量。

::screenshot[一个仓库窗口。左边的侧边栏列出仓库的各个视图、分支、标签与远端；顶部是工具栏；中间一栏上方是提交区，下方是改动的文件列表；右边一栏显示所选文件的改动。]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. 侧边栏
2. 工具栏
3. 中间一栏：当前视图的列表
4. 右边一栏：中间一栏所选内容的详情

:::note[服务器仓库]
窗口标题以主机别名开头，形如 `alias:name`。工具栏上多出一项 :ui[toolbar.host]，显示主机别名。连接断开时窗口显示什么，见 [连接状态与重连](/guide/server/connection/)。
:::

### 侧边栏 {#sidebar}

最上面的 :ui[workspace.group] 一组用来切换仓库的各个视图：

| 视图 | 显示的内容 |
|---|---|
| :ui[workspace.title] | 还没提交的改动。旁边的数字是改动文件的数量 |
| :ui[history.title] | 提交记录 |
| :ui[stash.title] | 暂时收起来的改动 |
| :ui[pr.title] | 托管服务上的 Pull Request 或 Merge Request |
| :ui[review.title] | 你的分支，用来找出可以清理的分支 |
| :ui[reflog.title] | HEAD 去过哪些地方。在 :ui[sidebar.viewSettings] 里打开 :ui[sidebar.showReflog] 后才显示 |
| :ui[repositorySettings.title] | 这个仓库的设置，见 [仓库设置](/guide/settings/identity/#repository) |

再往下依次是 :ui[sidebar.pinned]（置顶了分支后才有）、:ui[branch.group]、:ui[sidebar.archived]、:ui[sidebar.tags]、:ui[remote.group]、:ui[submodule.group] 与 :ui[worktree.group]。:ui[branch.group] 里，带 HEAD 标记的是你当前所在的分支。↑3 这样的箭头加数字，表示还有几个提交没推送。

侧边栏底部一栏有 :ui[sidebar.filter] 输入框、新建分支等引用用的 :ui[reference.addMenu] 按钮、决定侧边栏显示什么的 :ui[sidebar.viewSettings]。

### 工具栏 {#toolbar}

工具栏上的按钮从左到右依次是：

- :ui[toolbar.bookmarks]：回到仓库管理
- :ui[toolbar.previous] 与 :ui[toolbar.next]：在去过的视图之间后退、前进
- :ui[toolbar.finder] 与 :ui[toolbar.terminal]：在访达里显示仓库文件夹，或在终端里打开它
- :ui[sync.fetch]、:ui[sync.pull] 与 :ui[sync.push]：与远端交换提交
- :ui[toolbar.forcePush]：改写过提交之后，用你的分支替换远端分支
- :ui[toolbar.applyStash] 与 :ui[toolbar.saveStash]：取回收起来的改动，或把当前的改动收起来
- :ui[toolbar.createBranch]：新建一个分支
- :ui[action.refresh]：重新读取仓库
- :ui[action.search]：筛选当前视图的列表

按住 <kbd>⌥</kbd> 时，:ui[sync.fetch]、:ui[sync.pull] 与 :ui[sync.push] 会换成快速版本，例如 :ui[sync.quickPush]。快速版本直接对跟踪分支执行，不弹出对话框。

有最近的克隆时，工具栏上还会出现 :ui[toolbar.clone]，见 [仓库管理窗口](/guide/repositories/manager/)。想增减按钮，选 :ui[menu.view > menu.customizeToolbar]。除了上面这些，还可以加上 :ui[toolbar.quickActions]、:ui[toolbar.synchronize]、:ui[sync.merge] 与 :ui[sync.rebaseHead]，以及 :ui[toolbar.pushTo]。

### 三栏 {#columns}

左边一栏是侧边栏。中间一栏是所选视图的列表。在 :ui[workspace.title] 里是提交区与改动的文件，在 :ui[history.title] 里是提交记录。

右边一栏显示中间所选内容的详情。在 :ui[workspace.title] 里，就是所选文件的改动。一个文件既有已暂存、又有未暂存的改动时，用顶部的 :ui[working.staged] 与 :ui[working.unstaged] 切换。什么都没选时，这一栏显示 :ui[detail.empty.title]。

### 快捷操作 {#quick-actions}

选 :ui[menu.file > quickActions.menu] 或按 <kbd>⇧⌘A</kbd>，会打开一个面板。输入文字找到某个视图、分支、文件或提交，再对它执行操作，手不用离开键盘。它能找到什么、用哪些按键，见 [窗口与导航](/guide/repositories/navigation/)。

## 相关页面

- [第一个仓库](/guide/start/first-repository/)
- [仓库管理窗口](/guide/repositories/manager/)
- [窗口与导航](/guide/repositories/navigation/)
