---
title: "提交详情"
description: "查看提交的详情、变更集、文件树与签名状态，比较版本，以及导出文件。"
---

在 [历史](/guide/history/browse/) 里选中一个提交，右边一栏就显示它的详情：谁在什么时候提交的、完整的提交信息，以及它改动的文件。

## 头部 {#header}

顶上一条写着提交的短哈希，右边是 :ui[history.changeset] 与 :ui[history.tree] 两个按钮。短哈希可以选中复制。这一条下面的头部列出：

- :ui[history.author] 与 :ui[history.committer]，以及各自的日期。右边的头像是作者的；提交人另有其人时，提交人的头像在它左边。
- :ui[history.refs]：指向这个提交的分支与标签
- :ui[history.hash]：完整哈希
- :ui[history.parentHash]：每个父提交一行
- :ui[history.treeHash]
- 签名，只有带签名的提交才有，见 [签名](#signatures)

点右上角的箭头，头部就收起成作者、日期与引用三行。Spooky 会记住你的选择。头部下面是完整的提交信息。

### 操作按钮 {#actions}

把指针移到详情上，头部与提交信息之间的分隔线上会浮现一排按钮：

- :ui[history.rollback] 打开对话框，把当前分支重置到这个提交，见 [重置到更早的提交](/guide/history/rewrite/#reset)。
- :ui[rewrite.revert.button] 打开对话框，新增一个提交来抵消这个提交，见 [反转提交](/guide/history/rewrite/#revert)。
- :ui[history.diffTool] 用你的比较工具打开这个提交的全部改动，见 [在别的 App 里比较](/guide/work/diff/#external)。

列表显示的是你所在的分支时，才有 :ui[history.rollback] 与 :ui[rewrite.revert.button]。

## 变更集 {#changeset}

:ui[history.changeset] 按路径列出这个提交改动的文件。列表上方一行写着文件数、新增与删除的行数。

- 点文件旁边的箭头，展开它的改动。想展开或收起所有文件的改动，点列表上方那一行开头的 :ui[history.expandAll] 或 :ui[history.collapseAll]，或者按 <kbd>⌃⌘→</kbd> 或 <kbd>⌃⌘←</kbd>。
- 点一个文件就选中它。按住 <kbd>⇧</kbd> 或 <kbd>⌘</kbd> 再点，可以选中多个。<kbd>↑</kbd> <kbd>↓</kbd> 移动选择。

文件一开始都是收起的。想让它们自动展开，在 :ui[menu.view > history.diffs] 里的 :ui[history.autoExpand.title] 下面选一个数。提交改动的文件不超过这个数时，所有改动都会展开。:ui[history.autoExpand.always] 则每次都展开。

合并提交的变更集显示什么，由 :ui[app.name > settings.title] › :ui[settings.general] 里的 :ui[history.mergeDiff] 决定：

- :ui[history.mergeDiff.firstParent]（默认）显示这次合并给分支带来的改动。
- :ui[history.mergeDiff.mergedFilePaths] 只显示与每个父提交都不同的文件。
- :ui[history.mergeDiff.off] 不显示改动。

见 [历史与 Diff](/guide/settings/general/#history)。

右键点按一个文件，可以：

- 复制它的路径，或它在仓库里的路径
- 查看文件在这个提交时的原文、它的 Blame 或它的历史，见 [文件历史与 Blame](/guide/history/file-views/)
- 用比较工具打开它，与这个提交的第一父提交比较
- 在工作区里把它恢复成这个提交里的版本，见 [从某个版本恢复文件](/guide/history/file-views/#restore)
- 把这个提交里的版本存到 Mac 上

选中多个文件时，可以一起用比较工具打开、恢复或导出。

## 文件树 {#tree}

:ui[history.tree] 显示这个提交时仓库里的所有文件，不只是改动过的。点文件夹旁边的箭头打开它。

右键点按一个文件或文件夹，可以：

- 用默认的 App 或你选的 App 打开文件
- 查看文件的原文、Blame 或历史
- 在工作区里把它恢复成这个提交里的版本
- 导出它，或者存成 zip 归档

打开与查看只适用于文件。选中多个项目时，可以一起打开、恢复、导出或归档。导出的项目放进你选的文件夹。那里已有同名项目时，Spooky 会先问你要不要覆盖。

## 整页详情 {#full-page}

在列表里连按一个提交，它的详情就占满整个窗口。左边一栏是这个提交，下面是改动的文件列表。右边一栏显示所选文件的改动。

- 点左上角的短哈希，可以换一个提交：在列表里连按一个提交就换成它。
- 连按一个文件，或者按 <kbd>Return</kbd>，用默认的 App 打开这个提交里的版本。

想回到历史，选 :ui[menu.view > navigation.back]（<kbd>⌘[</kbd>），或者点工具栏上的 :ui[toolbar.previous]。

## 多个提交 {#multiple}

选中不止一个提交时，右边一栏显示选中的个数，下面是这些按钮：

- :ui[rewrite.cherryPick.button] 把这些提交应用到你所在的分支。列表显示的就是这个分支时，按钮换成 :ui[rewrite.revert.button]，见 [改写历史](/guide/history/rewrite/)。
- 恰好选中两个提交时才有 :ui[compare.submit]，显示从较早的提交到较新的提交改了什么。按住 <kbd>⌥</kbd> 就反过来比较。

## 签名 {#signatures}

详情会验证所选提交的签名。展开的头部写着密钥与状态，例如 :ui[signature.good]。

想在列表里也看到签名，在 [视图选项](/guide/history/browse/#view-options) 里打开 :ui[signature.verify]。带签名的提交会在行尾多一个圆点：

- 绿色：签名有效。
- 红色：签名无效。
- 黄色：其它状态，例如密钥已过期，或者 Spooky 没法验证这个签名。

点圆点可以看到密钥与状态。

## 比较两个版本 {#compare}

想看任意两个提交、分支或标签之间改了什么：

1. 在菜单栏里选 :ui[menu.repository > compare.menu]。也可以右键点按一个提交，选 :ui[compare.menuFrom]{1="e2dda2bc"}，从它开始比较。
2. 填好 :ui[compare.base] 与 :ui[compare.target]。菜单里列出本地分支、远端分支与标签，也可以输入哈希。
3. 点 :ui[compare.submit]。

右边一栏显示比较的结果。:ui[compare.commits] 列出第二个版本有、第一个版本没有的提交。:ui[history.changeset] 显示从第一个版本到第二个版本的改动。想关掉它，点右上角的 ×，或者选中别的提交。

选中两个提交时，菜单里直接有 :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"}。

## 导出文件 {#export}

想把一个提交时的所有文件原样存下来：

1. 右键点按一个提交，在菜单里选 :ui[export.menuFrom]{1="e2dda2bc"}。菜单栏里的 :ui[menu.repository > export.menu] 从所选的提交开始。
2. 核对版本。想得到一个 zip 文件，选中 :ui[export.createArchive]。
3. 点 :ui[export.submit]，选好存放的位置。

不存成归档时，得到的是一个以仓库名和短哈希命名的文件夹。

导出会出现在 [活动窗口](/guide/advanced/queue-activity/) 里，可以在那里取消。

## 保存补丁 {#patch}

补丁是一个写着提交改动的文本文件。在别的仓库里可以用 `git am` 应用它。

1. 右键点按一个提交，在菜单里选 :ui[patch.menu]{1="e2dda2bc"}。选中多个提交时，这一项为每个提交各存一个补丁。
2. 选中 :ui[patch.omitPrefixes]，路径前面就不带 `a/` 与 `b/`。
3. 点 :ui[patch.save]，选一个文件夹。

每个提交一个文件，从最早的提交开始编号，例如 `0001-Add-a-theme-toggle-to-the-header.patch`。存好以后，访达会打开并选中这些文件。保存同样会出现在活动窗口里。

在菜单里按住 <kbd>⌥</kbd>，就能选 :ui[patch.quickMenu]{1="e2dda2bc"}。它直接存进仓库的文件夹，沿用你上次的 :ui[patch.omitPrefixes] 选择。

:::note[服务器仓库]
导出的文件和用 :ui[patch.save] 存的补丁都放在你的 Mac 上。快速保存的补丁放在服务器上的仓库文件夹里。
:::

## 复制提交信息 {#copy}

右键点按一个提交，可以复制：

- :ui[history.copyHash]：完整哈希
- :ui[history.copyInfo]：短哈希与提交信息的第一行

选中多个提交时，每个提交一行。

## 相关页面

- [浏览历史](/guide/history/browse/)
- [文件历史与 Blame](/guide/history/file-views/)
- [改写历史](/guide/history/rewrite/)
