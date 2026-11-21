---
title: "文件历史与 Blame"
description: "查看一个文件的历史，用 Blame 看每一行由谁改动，查看文件在某个版本的原文，以及从那个版本恢复文件。"
---

这几个视图一次只看一个文件：哪些提交改过它，每一行是谁写的，以及它在过去任何时候的样子。

## 文件历史 {#file-history}

想看改过一个文件的所有提交：

- 在工作区里右键点按这个文件，选 :ui[fileHistory.showHistoryOf]{1="units.ts"}。
- 或者把指针移到右边一栏顶上的文件名上，点 :ui[fileHistory.title]。
- 在 [提交详情](/guide/history/commit-details/#changeset) 里，右键点按变更集或文件树中的文件，选同一项。

在工作区里，也可以选中一个文件夹，点右边一栏顶上的 :ui[fileHistory.title]。这时的历史包括其中所有的文件。

左边一栏按从新到旧列出提交，按月分组。最上面写着文件名与提交的个数。点文件名可以换成别的文件。

选中一个提交，右边就显示它对这个文件改了什么。换到 :ui[showFile.raw] 可以看到这个提交里的完整文件，换回 :ui[fileHistory.diff] 再看改动。把指针移到顶上的短哈希上，还有这几个按钮：

- :ui[blame.title] 显示这个提交时每一行是谁写的，见 [Blame](#blame)。
- :ui[fileHistory.showCommit] 用 [整页详情](/guide/history/commit-details/#full-page) 打开这个提交。
- :ui[externalTool.action.diffTool] 用你的比较工具打开这次改动。

::screenshot[src/units.ts 的文件历史。左栏顶上是文件名与提交数，下面按月列出改过它的提交。右边是所选提交在这个文件里的改动。指针停在短哈希上，右上角 Diff 与 “原文” 切换的旁边露出 Blame、“显示提交” 与 “比较工具” 三个按钮。]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. 文件名与提交的个数
2. :ui[fileHistory.diff] 与 :ui[showFile.raw] 的切换
3. 指针移到短哈希上时出现的按钮

连按一个提交，或者按 <kbd>Return</kbd>，同样会用整页详情打开它。右键点按一个提交，菜单里有同样的操作，还能恢复或导出这个提交里的文件。

### 搜索文件历史 {#file-history-search}

在工具栏的搜索框里输入，列表就只剩符合的提交。点框里的放大镜，选要搜索什么：:ui[fileHistory.scope.message]、:ui[fileHistory.scope.hash]、:ui[fileHistory.scope.author] 或 :ui[fileHistory.scope.committer]。

- 说明、作者与提交人按输入的文字匹配，不分大小写。作者与提交人按名字或邮箱匹配。
- 输入提交哈希、分支或标签时，显示到那里为止最近一个改过这个文件的提交。

## Blame {#blame}

Blame 显示整个文件，右边有一栏写着每一块最后是哪个提交改的。每一块显示作者的头像、提交信息的第一行、作者，以及是多久以前。

- 在工作区里右键点按一个文件，选 :ui[blame.show]{1="units.ts"}。或者把指针移到右边一栏顶上的文件名上，点 :ui[blame.title]。
- 在一个提交的变更集或文件树里，选 :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"}，看文件在那时的样子。

::screenshot[src/units.ts 的 Blame。左边是文件，右边一栏写着每一块最后由哪个提交改动：头像、提交信息、作者和多久以前。Drop trailing zeros from temperatures 的几块亮着。]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. 写着每一块由哪个提交改的那一栏
2. 点中的提交亮起来的几块

点一块，可以看到它的提交的摘要。同一个提交的所有块都会亮起来。连按一块，就用整页详情打开它的提交。想把这一栏调宽或调窄，拖它的左边缘。Spooky 会记住宽度。

Blame 只能看已经提交过的文件。新文件、未跟踪的文件、二进制文件与子模块都没法看。

## 查看文件在某个版本的原文 {#show-file}

想看一个文件在任何一个提交里的样子，又不动工作区：

- 在工作区里右键点按一个文件，选 :ui[showFile.show]{1="units.ts"}。这里显示的是 HEAD 里的版本。
- 在一个提交的变更集或文件树里，选 :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}。

头部像一条路径：版本 › 文件。

- 点版本可以换一个提交：在列表里连按一个提交就换成它。
- 点文件名，可以换成同一个提交里的别的文件。
- :ui[showFile.raw] 与 :ui[blame.title] 在原文与 [Blame](#blame) 之间切换。
- 把指针移到头部上，还有 :ui[fileHistory.title] 与 :ui[fileHistory.showCommit]。

头部下面写着改过这个文件的人数，以及他们的头像。正文用你的主题，以及 :ui[app.name > settings.title] › :ui[settings.text] 里的设置，见 [文本](/guide/settings/appearance/#text)。

这个视图与 Blame 一样，没法看新文件、未跟踪的文件、二进制文件与子模块。

## 从某个版本恢复文件 {#restore}

想把一个文件改回更早的提交里的样子：

1. 在文件历史里右键点按这个提交，在菜单里选 :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"}。在 [提交详情](/guide/history/commit-details/#changeset) 里，这一项是 :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}。
2. Spooky 会先问你。点 :ui[fileHistory.restore.submit]。

文件里已暂存与未暂存的改动都会被换掉。如果那个提交里没有这个文件，它就会被删除。恢复不会提交：恢复后的文件出现在工作区里，是已暂存的改动。

想撤回，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

在变更集或文件树里，可以一次恢复多个文件或文件夹。

:::note[服务器仓库]
服务器上的文件会被覆盖。选中 :ui[dialog.doNotAskAgain]，下次就不再问。想重新被问，在 :ui[app.name > settings.title] › :ui[settings.general] 里打开 :ui[settings.warnRestoringOnServer]，见 [确认](/guide/settings/general/#confirmations)。
:::

## 相关页面

- [提交详情](/guide/history/commit-details/)
- [工作区](/guide/work/working-copy/)
- [撤销与找回](/guide/work/undo/)
