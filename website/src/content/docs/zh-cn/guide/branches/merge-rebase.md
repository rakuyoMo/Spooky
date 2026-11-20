---
title: "合并与变基"
description: "合并与变基分支，开始前预览冲突，用父分支更新分支，以及在侧边栏里拖放分支。"
---

合并和变基都会把另一个分支的提交带进当前所在的分支：

- 合并把两段历史接到一起，通常会多一个合并提交。
- 变基把你的提交挪到另一个分支的提交后面。历史保持一条直线，但你的提交会被改写。

工具栏上并排放着 :ui[sync.merge] 与 :ui[sync.rebaseHead]。:ui[workspace.title] 菜单里也能开始这两个操作。

## 合并 {#merge}

1. 点工具栏上的 :ui[sync.merge]，或者选 :ui[workspace.title > sync.mergeMenu]（<kbd>⇧⌘M</kbd>）。也可以在侧边栏里右键点按当前所在的分支，选 :ui[workspace.mergeMenu]，或者把另一个分支拖到它上面。
2. 在 :ui[branch.target] 里选要合并的内容：本地分支、远端分支或标签。一开始是当前分支的上游。
3. 选择怎么提交：
   - :ui[merge.squash]：把全部改动暂存起来，由你自己做成一个提交，不生成合并提交。
   - :ui[merge.alwaysCommit]：即使 Git 只需把你的分支往前移，也生成一个合并提交。
   - :ui[merge.autoCommit]：合并后马上提交。只有勾选了 :ui[merge.alwaysCommit] 时才能取消它。取消后，合并进来的改动留在工作区里，等你提交。
4. 合并会遇到冲突时，下方会有一行提示，见 [预览冲突](#preview)。
5. 设置选项：
   - :ui[merge.verify]：合并进来的提交没有可信签名时停下。
   - :ui[sync.skipHooks]：这一次不运行仓库的 Git 钩子。
6. 点 :ui[sync.merge]。

Spooky 会记住 :ui[merge.alwaysCommit]、:ui[merge.autoCommit] 与 :ui[merge.verify]。

合并遇到冲突时，Spooky 会切到工作区并显示一条横幅，见 [解决冲突](/guide/work/conflicts/#banner)。<kbd>⌘Z</kbd> 可以撤销合并，停在冲突上的合并也可以，撤销就是中止它。

## 变基 {#rebase}

1. 点工具栏上的 :ui[sync.rebaseHead]，或者选 :ui[workspace.title > sync.rebaseMenu]（<kbd>⇧⌘R</kbd>）。也可以右键点按当前所在的分支，选 :ui[workspace.rebaseMenu]。
2. 在 :ui[branch.target] 里选要变基到哪个分支上。一开始是当前分支的上游。
3. 看一下预览，需要的话勾选 :ui[sync.skipHooks]。
4. 点 :ui[sync.rebaseHead]。

完成的变基可以用 <kbd>⌘Z</kbd> 撤销。停在冲突上的变基撤销不了：解决冲突后继续，或者在横幅上中止它。

只想把一部分提交挪到另一个基础上，见 [把提交变基到别处](/guide/history/rewrite/#rebase-onto)。

:::caution
变基会改写你的提交。这些提交已经推送过的话，下一次推送就得用 [安全强推](/guide/branches/sync/#force-push)。
:::

## 本地改动 {#local-changes}

合并时，已跟踪的文件不能有改动。新文件只有在合并会覆盖它们时才会挡路。

变基和用父分支更新分支时，工作区里不能有任何改动，新文件也不行。

本地改动挡住了其中一个操作时，Spooky 会提出先把改动储藏起来，见 [自动储藏](/guide/work/stash/#auto-stash)。

## 预览冲突 {#preview}

开始之前，合并、变基、拉取与同步对话框会检查两边会不会冲突，并在对话框里显示结果：

- Spooky 比对时显示 :ui[merge.checking]。
- 有几个文件冲突。把指针停在这一行上，可以看到是哪些文件。
- :ui[merge.clean] 或 :ui[merge.unchanged]。
- 检查没能完成时显示 :ui[merge.unavailable]。

合并对话框只在有冲突时显示这一行，其它对话框每种结果都会显示。

## 快速版本 {#quick}

按住 <kbd>⌥</kbd>，工具栏上的 :ui[sync.merge] 与 :ui[sync.rebaseHead] 会变成 :ui[sync.quickMerge] 与 :ui[sync.quickRebase]。它们不弹对话框，直接执行：

- :ui[sync.quickMerge] 合并当前分支的上游。
- :ui[sync.quickRebase] 把当前分支变基到它的上游上。

快速合并用你上次在合并对话框里选的提交方式与签名选项。两者和对话框一样，会提出先储藏本地改动。

侧边栏菜单里的项也一样会变，比如 :ui[workspace.mergeMenu] 会变成 :ui[sync.quickMergeInto]{1="origin/main" 2="main"}。

## 用父分支更新分支 {#update}

分支有 [父分支](/guide/branches/branches/#parent) 时，更新会把父分支的新提交带进来。

1. 右键点按分支，选 :ui[branch.updateNamed]{1="feature/units-toggle"}。查看这个分支的历史、而父分支有新提交时，横幅 :ui[history.parentBanner.title] 上也有 :ui[review.updateBranch.menu] 按钮。
2. 核对 :ui[review.update.branch]。下面一行写着会从父分支带进几个提交。
3. 在 :ui[review.update.strategy] 里选 :ui[review.update.merge] 或 :ui[review.update.rebase]。选 :ui[review.update.merge] 时还可以勾选 :ui[merge.alwaysCommit]。
4. 看一下预览：:ui[review.update.conflicts]、:ui[review.update.clean] 或 :ui[review.update.noChanges]。
5. 设置选项：:ui[merge.verify]（只用于合并）与 :ui[sync.skipHooks]。
6. 点 :ui[review.update.button]。

Spooky 会先检出这个分支，再合并或变基。只有父分支有这个分支没有的提交、又没有别的操作在进行时，才能更新。

对当前所在的分支，侧边栏菜单里的 :ui[branch.mergeWith]{1="main"} 与 :ui[branch.rebaseOn]{1="main"} 会打开合并与变基对话框，并且已经选好了父分支。

:::tip
打开菜单后按住 <kbd>⌥</kbd>，:ui[branch.updateNamed]{1="feature/units-toggle"} 会变成 :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}，不弹对话框，直接合并父分支。
:::

## 拖放 {#drag-and-drop}

不少分支操作可以从侧边栏里的拖动开始。拖动时，指针旁的标签会说明松手后做什么。在收起的文件夹或远端上停一会儿，它就会展开。

| 拖动 | 拖到 | 结果 |
|---|---|---|
| 本地分支 | :ui[workspace.title] 或当前所在的分支 | 合并对话框。按住 <kbd>⌥</kbd> 是变基对话框。 |
| 远端分支 | :ui[workspace.title] 或当前所在的分支 | 拉取对话框 |
| 远端分支，按住 <kbd>⌥</kbd> | 当前所在的分支 | 它成为当前分支的上游。 |
| 本地分支、标签或提交 | :ui[branch.group] | 从它新建分支的对话框 |
| 远端分支 | :ui[branch.group] | 跟踪它的对话框 |
| 本地分支 | 远端 | 发布对话框 |
| 本地分支 | 远端分支 | :ui[sync.pushBranch] 对话框 |
| 本地分支或提交 | :ui[sidebar.tags] 或标签文件夹 | 新建标签的对话框 |
| 标签 | 远端 | 发布标签的对话框 |
| 本地分支 | :ui[sidebar.pinned] 或 :ui[sidebar.archived] | 分支被置顶或归档。 |
| 本地分支 | :ui[worktree.group] | 为它新建工作树的对话框 |

想把分支移进文件夹，把它拖到文件夹上。分支会改名为文件夹名加上它名字的最后一段，不弹对话框。远端分支只能移进它自己远端下的文件夹。想把分支移出文件夹，把它拖到列表的顶部或底部边缘。改名可以用 <kbd>⌘Z</kbd> 撤销。

也可以把历史里的提交拖到 :ui[workspace.title] 或当前所在的分支上，摘取这些提交。按住 <kbd>⌥</kbd> 则是反转它们，见 [摘取提交](/guide/history/rewrite/#cherry-pick)。把提交变更集里的单个文件拖过去，只会把这个文件的改动套用到工作区，不会暂存。

## 相关页面

- [解决冲突](/guide/work/conflicts/)
- [改写历史](/guide/history/rewrite/)
- [获取、拉取与推送](/guide/branches/sync/)
- [分支](/guide/branches/branches/)
