---
title: "键盘快捷键"
description: "查阅 Spooky 的全部键盘快捷键。"
---

菜单项旁边都写着它的快捷键。这一页把它们都列了出来，还有只在某些地方起作用的按键，比如提交区、列表与对话框里的。符号的含义见 [键盘快捷键](/guide/#shortcuts)。

菜单项可用时，它的快捷键才起作用。菜单项灰着时，按快捷键没有反应。

## 菜单 {#menus}

### App 与窗口 {#app-windows}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### 仓库 {#repositories}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### 视图 {#views}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### 编辑与查找 {#edit}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- :ui[menu.undo] 能撤销哪些操作，见 [撤销与重做](/guide/work/undo/#undo)。
- 在一些列表里，:ui[menu.delete] 也会删除所选的项，见 [列表](#lists)。
- :ui[action.find] 与 :ui[action.search] 都把光标放进工具栏的搜索框。见 [搜索与筛选](/guide/history/browse/#search) 与 [搜索文件](/guide/work/working-copy/#search)。
- :ui[commit.reformatParagraph] 用在提交信息里，见 [写提交信息](/guide/work/commit/#write)。

### 分支与同步 {#sync}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

带 <kbd>⌥⇧⌘</kbd> 的是快速版本。打开菜单后按住 <kbd>⌥</kbd>，它们就替换上面那一项。它们不开对话框，直接执行。不打开菜单，快捷键也能用。见 [获取、拉取与推送](/guide/branches/sync/#quick) 与 [合并与变基](/guide/branches/merge-rebase/#quick) 里的 “快速版本”。

### 改动与提交 {#changes}

| 快捷键 | 菜单项 |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## 按住 Option {#option}

按住 <kbd>⌥</kbd>，一些按钮与菜单会变样。松开就变回来。

| 在哪里 | 变成什么 |
|---|---|
| 工具栏里获取、拉取、推送、同步、合并与变基的按钮 | 变成快速版本。见 [获取、拉取与推送](/guide/branches/sync/#quick)。 |
| 提交区，前提是没有在编辑任何信息框 | 切换到修补上一次提交。见 [修补上一次提交](/guide/work/commit/#amend)。 |
| 文件列表上方的 :ui[working.stageAll]，前提是只暂存了一部分改动 | 变成 :ui[working.unstageAll]。见 [暂存整个文件](/guide/work/diff/#stage-file)。 |
| 工作区里文件的菜单 | 储藏的几项变成快速版本。见 [储藏部分文件](/guide/work/stash/#partial)。 |
| 子模块的菜单 | 获取与更新变成快速版本。见 [获取与更新](/guide/advanced/submodules/#update)。 |
| 设了父分支的分支的菜单 | 用父分支更新变成快速版本。见 [用父分支更新分支](/guide/branches/merge-rebase/#update)。 |
| 提交的菜单 | 保存补丁变成快速版本。选中两个提交时，比较的方向反过来。见 [保存补丁](/guide/history/commit-details/#patch)。 |
| 选中两个提交时的 :ui[compare.submit] | 比较的方向反过来。见 [多个提交](/guide/history/commit-details/#multiple)。 |
| 拖放 | 见 [按住 Option 拖放](#drag)。 |

## 提交区 {#commit-area}

| 按键 | 作用 |
|---|---|
| 在标题里按 <kbd>↩</kbd> 或 <kbd>Tab</kbd> | 移到正文 |
| 在正文里按 <kbd>Tab</kbd> | 移到文件列表 |
| 在正文里按 <kbd>⇧Tab</kbd> | 回到标题 |
| 输入提交信息时按 <kbd>⌘↩</kbd> | 点提交区的主按钮，比如 :ui[working.commit]。小键盘上的 <kbd>Enter</kbd> 也一样。 |
| 没有在编辑任何信息框时按 <kbd>⌥⌘↩</kbd> | 修补上一次提交。见 [修补上一次提交](/guide/work/commit/#amend)。 |
| 在自动补全列表里按 <kbd>↑</kbd> <kbd>↓</kbd>、<kbd>↩</kbd>、<kbd>Esc</kbd> | 依次是选一个候选、插入它、关闭列表 |

见 [提交改动](/guide/work/commit/)。

## 文件列表 {#file-list}

这些按键在工作区的文件列表里起作用：

| 按键 | 作用 |
|---|---|
| <kbd>空格</kbd> | 暂存或取消暂存所选的文件。:ui[files.spacebar] 设成 :ui[files.spacebar.quickLook] 时，改为用快速查看显示它们。见 [文件列表](/guide/settings/general/#file-list)。 |
| <kbd>⌘⌫</kbd> | 把所选的文件移到废纸篓 |
| <kbd>⇧Tab</kbd> | 回到提交信息的正文 |

## Diff 里的行 {#diff-lines}

在工作区里，按 <kbd>Tab</kbd>，直到某一块的行号得到键盘焦点。之后：

| 按键 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 在能选的行之间移动 |
| <kbd>空格</kbd> | 选中或取消选中这一行 |
| <kbd>Tab</kbd> 或 <kbd>⇧Tab</kbd> | 离开行号 |

用鼠标时，按住 <kbd>⇧</kbd> 再点行号，会选中中间的每一行。见 [暂存行](/guide/work/diff/#lines)。

## 列表 {#lists}

| 在哪里 | 按键 | 作用 |
|---|---|---|
| 历史里的提交列表 | <kbd>⌘C</kbd> | 复制所选提交的完整哈希 |
| 提交的变更集 | <kbd>↑</kbd> <kbd>↓</kbd> | 移动选择 |
| 整页详情里的改动文件 | <kbd>↩</kbd> | 用各自的默认 App 打开所选的文件 |
| 提交的文件树 | <kbd>↩</kbd> | 展开或收起所选的文件夹 |
| 文件历史 | <kbd>↩</kbd> | 在整页详情里打开所选的提交 |
| 侧边栏 | <kbd>⌘⌫</kbd> | 先问，再删除所选的分支、标签、远端或子模块 |
| 侧边栏的筛选框 | <kbd>Esc</kbd> | 清空输入框 |
| 储藏 | <kbd>⌘⌫</kbd> | 先问，再删除所选的储藏 |
| 分支整理 | <kbd>⌘⌫</kbd> | 先问，再删除所选的分支 |
| 仓库管理窗口 | <kbd>↩</kbd> | 给所选的一项改名 |
| 仓库管理窗口 | <kbd>⌫</kbd> 或 <kbd>⌦</kbd> | 删除所选的项。见 [删除仓库](/guide/repositories/manager/#delete)。 |
| 启动时显示的窗口 | <kbd>↩</kbd> | 打开所选的仓库。见 [回到上次离开的地方](/guide/repositories/navigation/#restore)。 |
| Pull Request 的讨论 | <kbd>↩</kbd> | 打开所选的提交 |
| Pull Request 的讨论 | <kbd>⌘S</kbd> | 点 :ui[pullRequests.addComment] |
| 设置里的 :ui[settings.themes] | <kbd>↩</kbd> | 给所选的主题改名 |
| 设置里的 :ui[settings.appIcon.label] | 方向键、<kbd>空格</kbd> | 在图标之间移动，换成所在的那一枚 |

在能多选的列表里，按住 <kbd>⇧</kbd> 再点会选中一段，按住 <kbd>⌘</kbd> 再点会加选或取消选中一项。在侧边栏里，按住 <kbd>⌘</kbd> 再点分支与标签，可以一起看它们的历史。见 [打开历史](/guide/history/browse/#open)。

按住 <kbd>⌘</kbd> 连按一个已在别的工作树里检出的分支，会在新标签页里打开那个工作树。见 [检出分支](/guide/branches/branches/#checkout)。

## 快捷操作 {#quick-actions}

这些按键在 [快捷操作](/guide/repositories/navigation/#quick-actions) 面板里起作用：

| 按键 | 作用 |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | 移动选中的行 |
| <kbd>↩</kbd> | 对选中的项执行默认操作 |
| <kbd>Tab</kbd>，或在文字末尾按 <kbd>→</kbd> | 列出选中项的全部操作 |
| 没有文字时按 <kbd>←</kbd>，或按 <kbd>⇧Tab</kbd> | 从操作列表返回 |
| <kbd>Esc</kbd> | 清空文字。没有文字时，从操作列表返回或关闭面板。 |

## 对话框 {#dialogs}

在对话框里，<kbd>↩</kbd> 点高亮的按钮，<kbd>Esc</kbd> 点取消用的按钮。对话框里没有这样的按钮时，<kbd>Esc</kbd> 也点高亮的按钮。

## 按住 Option 拖放 {#drag}

放下时按住 <kbd>⌥</kbd>，会换成另一个操作：

| 拖什么 | 拖到哪里 | 不按 <kbd>⌥</kbd> | 按住 <kbd>⌥</kbd> |
|---|---|---|---|
| 本地分支 | :ui[workspace.title] 或当前分支 | 合并对话框 | 变基对话框 |
| 远端分支 | 当前分支 | 拉取对话框 | 它成为当前分支的上游 |
| 历史里的提交 | :ui[workspace.title] 或当前分支 | 摘取它们 | 反转它们 |
| 历史里的提交 | 列表里的另一个提交 | 把它们压缩进去 | 改为 Fixup |

见 [拖放](/guide/branches/merge-rebase/#drag-and-drop) 与 [压缩、Fixup、删除与移动](/guide/history/rewrite/#interactive)。

## 相关页面

- [窗口与导航](/guide/repositories/navigation/)
- [提交改动](/guide/work/commit/)
- [查看与挑选改动](/guide/work/diff/)
- [合并与变基](/guide/branches/merge-rebase/)
