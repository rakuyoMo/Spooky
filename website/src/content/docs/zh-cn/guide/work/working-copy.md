---
title: "工作区"
description: "查看改动文件的状态，用平铺或树形显示文件列表，排序与搜索，处理未跟踪与忽略的文件，使用文件操作与快速查看。"
---

工作区显示上次提交以来你改了什么。在这里挑出要提交的改动，查看文件，也把不该让 Git 跟踪的文件挡在外面。

点侧边栏最上面的 :ui[workspace.title]，或选 :ui[menu.view > menu.showWorkingCopy]（<kbd>⌘1</kbd>），就能打开它。中间一栏上方是提交区，下面列出改动的文件。提交区的用法见 [提交改动](/guide/work/commit/)。

## 看懂状态 {#status}

每个改动的文件占一行：一个复选框、两个状态标记，再是文件名。

- 复选框表示改动有没有暂存。显示一条短横时，表示文件只暂存了一部分。
- 左边的标记是已暂存的改动，右边的标记是还没暂存的改动。
- 字母是 Git 的状态代码：M 是修改，A 是新增，D 是删除，R 是改名。Git 还没跟踪的新文件显示 ?，被忽略的文件显示 !。
- 有冲突的文件显示两个冲突代码，例如 U U。见 [解决冲突](/guide/work/conflicts/)。

把指针停在标记上，可以看到状态的文字说明。

列表上方一行是当前分支，后面跟着它跟踪的远端分支。没有跟踪分支时，这一行写着 :ui[branch.noTracking]。

文件有变化时，Spooky 会自己更新列表。想全部重新读一遍，点 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

:::note[服务器仓库]
仓库窗口在最前面时，Spooky 每 2 秒查一次服务器上的变化，其余时候每 10 秒查一次。所以在服务器上做的改动，可能要过这么久才显示出来。见 [服务器仓库有哪些不同](/guide/server/overview/#differences)。
:::

## 平铺或树形显示 {#view}

:ui[menu.view > files.statusMenu] 菜单决定列表显示什么。分支那一行右端的按钮里也是这几项。

| 菜单项 | 作用 |
|---|---|
| :ui[working.list]（<kbd>⌃⌘L</kbd>） | 每个文件一行，显示完整路径 |
| :ui[working.tree]（<kbd>⌃⌘T</kbd>） | 文件按所在的文件夹分组。连按文件夹可以展开或收起 |
| :ui[files.showNonModified]（<kbd>⌃⌘M</kbd>） | 列出仓库里的所有文件，不只是改动过的。树形显示时可用 |
| :ui[files.showIgnored]（<kbd>⌃⌘I</kbd>） | 列出 Git 忽略的文件 |
| :ui[files.showAssumeUnchanged] | 列出标记为 assume-unchanged 的文件，见 [未跟踪与忽略的文件](#untracked-ignored) |

平铺还是树形，每个仓库各记各的，新打开的仓库默认平铺。其余几项对所有仓库都生效。

## 排序 {#sort}

点 :ui[status.filename] 或 :ui[status.column] 的列标题，按这一列排序。再点一次，顺序反过来。排序方式在所有仓库与窗口里都一样。

第一次点 :ui[status.column]，已暂存的文件排在最前面。接着是其余的改动，然后是新文件，最后是未改动与被忽略的文件。

## 搜索文件 {#search}

1. 按 <kbd>⌘F</kbd>，或点工具栏上的搜索框。框里写着 :ui[history.search.forFile]。
2. 输入文件路径的一部分。Spooky 会列出按顺序包含这些字母的文件。
3. 选一个文件，列表就只显示这个路径。列出的最后一项会显示路径里含有你输入内容的所有文件。

清空搜索框，所有文件就又显示出来了。

## 未跟踪与忽略的文件 {#untracked-ignored}

新文件在暂存并提交之前是未跟踪的。未跟踪的文件显示 ?，和其余改动列在一起。想把它加进下一个提交，像别的改动一样暂存它就行。

有些文件永远不该提交，比如构建产物或自己的笔记。不想让 Git 列出它们，右键点按文件，选一种规则：

- :ui[files.ignore] 把规则加到仓库根目录的 `.gitignore` 文件里。提交 `.gitignore` 以后，规则对所有使用这个仓库的人都生效。
- :ui[files.exclude] 把规则加到 Git 文件夹里的 `info/exclude`。规则只对这一份仓库生效，不会被提交。

两个子菜单都可以只忽略这一项，忽略所有同名的项目，忽略所有同一扩展名的项目，或者自己输入一条规则。

忽略规则对 Git 已经跟踪的文件不起作用。忽略一个已跟踪的文件时，Spooky 会问要不要同时停止跟踪它。点 :ui[files.untrack] 停止跟踪，点 :ui[files.untrackIgnored.skip] 继续跟踪。两种情况下，文件都留在你的文件夹里。

不加忽略规则、只想停止跟踪某个文件，右键点按它，选 :ui[files.untrack]。下一个提交会把它从仓库里删掉，文件仍留在你的文件夹里。

:ui[files.mark > files.assumeUnchanged.set] 让 Git 不理会你对某个已跟踪文件的本地改动，比如只在这台 Mac 上改的配置文件。文件会从列表里消失。想再看到它，打开 :ui[files.showAssumeUnchanged]，再选 :ui[files.mark > files.assumeUnchanged.unset]。

## 文件操作 {#file-actions}

右键点按文件，就能看到它的各种操作。右键点按的这一行在所选范围之内时，操作作用于所有选中的文件；在所选范围之外时，只作用于点的这一行。

::screenshot[在工作区里右键点按 src/readings.ts 弹出的菜单。从上往下依次是打开文件与拷贝路径、快速查看、暂存与移到废纸篓、冲突、丢弃与储藏、Blame 与文件历史、忽略，以及比较。]{name="work-file-menu" frame="closeup"}

| 想要 | 选 |
|---|---|
| 打开文件 | :ui[files.open]，或从 :ui[files.openWith] 里选一个 App。也可以直接连按文件 |
| 拷贝路径 | :ui[workspace.copyPathMenu] 或 :ui[working.copyRelative] |
| 在访达或终端里查看 | :ui[action.revealFinder] 或 :ui[action.openTerminal] |
| 移动或改名 | :ui[files.move.menu] |
| 移到废纸篓 | :ui[files.trash]，或按 <kbd>⌘⌫</kbd> |
| 扔掉改动 | :ui[working.discard.menu]（见 [丢弃改动](/guide/work/diff/#discard)） |
| 放进储藏 | 见 [储藏部分文件](/guide/work/stash/#partial) |
| 恢复成以前的版本 | :ui[files.revert.menu] |
| 查看它的历史 | :ui[quickActions.showFileHistory] 或 :ui[quickActions.showBlame]（见 [文件历史与 Blame](/guide/history/file-views/)） |
| 在别的 App 里比较 | :ui[externalTool.compare]（见 [在别的 App 里比较](/guide/work/diff/#external)） |

:ui[files.trash] 不会先问。移到废纸篓的已跟踪文件会显示成一个已暂存的删除。想把它拿回来，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

:::note[服务器仓库]
:ui[files.trash] 把文件移到服务器的废纸篓。服务器没有废纸篓时，这一项写作 :ui[files.delete]，Spooky 会先问你，再永久删除文件。大多数 App 拿到的是文件的副本，保存后 Spooky 把改动写回服务器。见 [终端与其它 App](/guide/server/local-location/#terminal)。
:::

## 快速查看 {#quick-look}

不打开 App 也想看看文件的内容，右键点按它，选 :ui[files.quickLook.single]{1="README.md"}。

常用快速查看的话，可以让空格键打开它：选 :ui[app.name > settings.title] › :ui[settings.general]，把 :ui[files.spacebar] 设为 :ui[files.spacebar.quickLook]。默认情况下，空格键暂存或取消暂存所选的文件。

:::note[服务器仓库]
Spooky 先把文件下载到这台 Mac 上的一个临时文件夹里。关掉仓库时，这个文件夹会被删掉。
:::

## 文件列表的设置 {#settings}

这几项在 :ui[app.name > settings.title] › :ui[settings.general] 里：

| 设置 | 可选的值 |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile]（默认）或 :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging]（默认）或 :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] 或 :ui[files.fontSize.medium]（默认） |
| :ui[files.truncation] | :ui[files.truncation.beginning]（默认）或 :ui[files.truncation.middle] |

## 相关页面

- [查看与挑选改动](/guide/work/diff/)
- [提交改动](/guide/work/commit/)
- [文件历史与 Blame](/guide/history/file-views/)
