---
title: "改写历史"
description: "反转、摘取与重置提交，交互式变基，以及修补更早的提交。"
---

这里的大多数操作都从 [历史](/guide/history/browse/) 列表开始：右键点按一个提交，或者先选中几个。反转与摘取会新增提交，其余的操作则改写已有的提交。

:::caution
改写后的提交会换成新的哈希。如果它们已经推送过，你的分支就会和上游分叉，再推送需要强制推送；已经拿到旧提交的人，也得自己理顺历史。见 [安全强推](/guide/branches/sync/#force-push)。
:::

除了摘取与重置，下面这些操作只在列表只显示你所在的分支时，才会出现在提交的菜单里。要切过去，选 :ui[menu.view > history.showHead]（<kbd>⌘0</kbd>），或者点侧边栏里的这个分支。

::screenshot[列表显示所在分支时，右键点按提交 2daa6982 弹出的菜单。里面有重置、反转与变基到别处，再往下是这个提交的修补、编辑、编辑提交信息与删除。]{name="history-commit-menu" frame="closeup"}

## 反转提交 {#revert}

反转会新增一个提交，抵消之前某个提交的改动。原来的提交还留在历史里，所以想撤回已经推送的内容时，这是稳妥的做法。

1. 右键点按这个提交，在菜单里选 :ui[rewrite.menu.revert]{1="e2dda2bc"}。选中多个提交时，这一项是 :ui[rewrite.menu.revertMany]{1="3"}。
2. :ui[rewrite.revert.commit] 默认打开，每个被反转的提交各得到一个新提交。关掉它，改动就只留在工作区里。Spooky 会记住这个选择。
3. 点 :ui[rewrite.revert.button]。

多个提交按从新到旧的顺序反转。反转合并提交时，要选 :ui[rewrite.mainline]，也就是把哪个父提交那一边当作主线。合并提交只能单独反转。

提交详情与 [多个提交](/guide/history/commit-details/#multiple) 的右边一栏里也有 :ui[rewrite.revert.button] 按钮。

## 摘取提交 {#cherry-pick}

摘取把别的分支上提交的改动复制到你所在的分支上，成为新的提交。

1. 点侧边栏里的另一个分支，看它的历史。
2. 右键点按这个提交，在菜单里选 :ui[rewrite.menu.cherryPick]{1="e2dda2bc"}。选中多个提交时，这一项是 :ui[rewrite.menu.cherryPickMany]{1="3"}，也可以点右边的 :ui[rewrite.cherryPick.button]。
3. 选好选项，Spooky 会记住它们：
   - :ui[rewrite.cherryPick.commit]（默认打开）把每个提交都提交下来。关掉它，改动就只应用到工作区。
   - :ui[rewrite.cherryPick.fastForward]：你的分支正好在这个提交的父提交上时，直接把分支移到这个提交，不再复制。只在第一个选项打开时有效。
4. 点 :ui[rewrite.cherryPick.button]。

提交按从旧到新的顺序应用。和反转一样，合并提交要选 :ui[rewrite.mainline]。

列表显示的是你所在的分支时，只有上游上那些你还没拉取的提交才有这一项。

也可以把提交从列表拖到侧边栏的 :ui[workspace.title] 或你所在的分支上。松手时按住 <kbd>⌥</kbd>，就改成反转。

## 重置到更早的提交 {#reset}

重置会把你所在的分支移到另一个提交上，之后的提交就离开了这个分支。

1. 右键点按这个提交，在菜单里选 :ui[rewrite.menu.reset]{1="e2dda2bc"}。也可以点提交详情里的 :ui[history.rollback]，或者在菜单栏里选 :ui[workspace.title > rewrite.reset.menu]。
2. 核对 :ui[rewrite.revision]。可以选一个分支、远端分支或标签，也可以输入哈希。对话框会列出将要离开这个分支的提交。
3. 选一种 :ui[rewrite.reset.mode]：
   - :ui[rewrite.reset.soft]：暂存区与工作区都不变，离开分支的那些提交的改动留在暂存区里。
   - :ui[rewrite.reset.mixed]：重置暂存区，工作区不变，那些改动变成未暂存的。
   - :ui[rewrite.reset.hard]：两者都重置。未提交的改动，以及离开分支的那些提交的改动，都会被丢掉。
4. 点 :ui[rewrite.reset.button]。

对话框每次都从 :ui[rewrite.reset.soft] 开始。重置不会提出先储藏你的改动。

:::caution
:ui[rewrite.reset.hard] 会丢掉已跟踪文件里未提交的改动，有这样的改动时对话框会提醒你。按 <kbd>⌘Z</kbd> 可以找回它们，但只在你退出 Spooky 之前有效。
:::

## 把提交变基到别处 {#rebase-onto}

:ui[rewrite.rebaseOnto] 把一些提交挪到另一个提交的上面。

- 想挪动分支上的一整段，在菜单栏里选 :ui[workspace.title > rewrite.rebaseOnto.menu]，填好 :ui[rewrite.rebaseOnto.current] 与 :ui[rewrite.rebaseOnto.new]。当前基点之后的提交会在新基点上重放一遍。
- 只想挪动其中几个，选中它们后右键点按，在菜单里选 :ui[rewrite.menu.rebaseOntoMany]{1="3"}（只有一个时是 :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"}），再填好 :ui[rewrite.rebaseOnto.new]。同一段里没选中的提交会从分支上去掉。

两个基点都不能是当前检出的提交。对话框会列出将被改写的提交，其中有已经推送或已经在别的分支里的，会给出警告。:ui[sync.skipHooks] 让这一次跳过仓库的 pre-rebase 钩子。点 :ui[rewrite.rebaseOnto.button] 开始。

想把一个分支变基到另一个分支上，见 [变基](/guide/branches/merge-rebase/#rebase)。

## 压缩、Fixup、删除与移动 {#interactive}

这些操作改写你所在分支上的一段提交。选中这些提交，右键点按，然后选：

- :ui[rewrite.menu.squashMany]{1="3"}，把它们并进其中最旧的一个，提交信息合在一起。完成后，列表会选中新的提交。
- :ui[rewrite.menu.fixupMany]{1="3"}，同样并进最旧的一个，只保留它的提交信息。
- :ui[rewrite.menu.deleteMany]{1="3"}，把它们从分支上删掉。只选中一个提交时，用 :ui[rewrite.menu.delete]{1="e2dda2bc"}。

也可以在列表里拖动提交：

- 放到另一个提交上，就压缩进那个提交。松手时按住 <kbd>⌥</kbd>，就改成 Fixup。落点旁会写着 :ui[rewrite.squash.button] 或 :ui[rewrite.fixup.button]。
- 放到两行之间，就把它们移到那里。落点旁写着 :ui[branch.moveHere]。

这些操作在改写之前，Spooky 都会先问你。对话框列出每个将被改写的提交，以及它会怎样，例如 :ui[rewrite.note.squash] 或 :ui[rewrite.note.drop]。已经推送或已经在别的分支里的提交，行尾有黄色的警告标志，列表上方会说明原因。要删除的提交已经在上游里时，Spooky 还会先多问一句。

::screenshot[把两个提交压缩进 10e44ab8 之前弹出的确认对话框。顶部的两条警告说，有的提交已经在上游分支上，或者已经在别的分支里。下面的列表是会被改写的四个提交，以及每个提交会怎样。已经推送的那个提交，行尾有黄色的警告标志。按钮是 “取消” 与 “压缩提交”。]{name="history-rewrite-confirm" frame="dialog"}

## 编辑提交信息 {#reword}

1. 右键点按这个提交，在菜单里选 :ui[rewrite.menu.reword]{1="e2dda2bc"}。
2. 修改 :ui[working.subject] 与 :ui[working.body]。注释行的处理和 [提交区](/guide/work/commit/#comments) 一样。
3. 点 :ui[rewrite.reword.button]。

它之后的提交也会一起改写，完成后列表会按新的哈希选中这个提交。如果这个提交已经在上游里，Spooky 会在打开对话框之前先问你。

## 编辑提交 {#edit}

编辑会在一个提交处停下，把它的改动放回工作区，方便你把它拆开或者重做。

1. 右键点按这个提交，选 :ui[rewrite.menu.edit]{1="e2dda2bc"}，再点 :ui[rewrite.edit.button] 确认。
2. 横幅上写着 :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}。这个提交的改动出现在工作区里，是未暂存的。
3. 像平常一样暂存与提交，拆成几个提交都可以。
4. 点横幅上的 :ui[working.endEditing]。之后的提交会在上面重放。

想放弃，点横幅上的 :ui[working.abort]。仓库的第一个提交没法编辑。

## 修补更早的提交 {#amend}

修补更早的提交，就是把改动加进那个提交里，和 [修补上一次提交](/guide/work/commit/#amend) 一样。

1. 右键点按这个提交，选 :ui[rewrite.menu.amend]{1="e2dda2bc"}。Spooky 直接开始，不先确认。
2. 变基停在这个提交上。做好改动并暂存。
3. 在提交区里选中 :ui[working.amend]，然后提交。
4. 点横幅上的 :ui[working.endEditing]。之后的提交会在上面重放。

开始时如果有本地改动，Spooky 会先提出把它们储藏起来。它们之后还留在储藏里，你可以在变基停下时应用，也可以以后再说。

## 自动压缩 {#autosquash}

一个提交可以把自己标成对之前某个提交的修正：标题以 `fixup!`、`squash!` 或 `amend!` 开头，后面跟着那个提交的标题。提交区会帮你 [补全这个标题](/guide/work/commit/#autocomplete)。

列表显示的是你所在的分支、没有搜索条件，并且最近 1000 个提交里有这样的提交时，表头下面会出现一条标题为 :ui[rewrite.autosquash] 的横幅。点横幅上的 :ui[rewrite.autosquash.button]，确认以后，每个带标记的提交都会并进它指明的那个提交：

- `fixup!` 保留原来那个提交的信息。
- `squash!` 把两条信息合在一起。
- `amend!` 用自己的信息替换原来那个提交的信息。

点 × 可以暂时隐藏这条横幅。

## 没法开始改写时 {#errors}

改写之前，Spooky 会先检查这些提交。有问题时它会说明原因，什么也不改：

| 提示 | 原因 |
|---|---|
| :ui[rewrite.error.notInHead] | 这些提交都必须在你所在分支的历史里，并且在同一条线上 |
| :ui[rewrite.error.merges] | 中间隔着一个合并提交，改写会把它拍平。请选最后一次合并之后的提交 |
| :ui[rewrite.error.root] | 仓库的第一个提交没有父提交，改动没地方放回去 |
| :ui[rewrite.error.selection] | 压缩至少需要两个提交，目标也不能是要并进去的提交之一 |
| :ui[rewrite.error.autosquash] | 最近的提交里没有标记为之前某个提交的修正的 |
| :ui[rewrite.error.changed] | Spooky 读取之后分支又变了。刷新历史，再试一次 |

## 本地改动与冲突 {#local-changes}

反转、摘取与变基都需要工作区不碍事。本地改动挡住了它们时，Spooky 会提出 [先储藏起来](/guide/work/stash/#auto-stash)。修补更早的提交则在开始之前就问。

途中有提交发生冲突时，Spooky 会停下来，显示 [操作横幅](/guide/work/conflicts/#banner)。解决冲突以后，在横幅上继续或中止。

## 撤销改写 {#undo}

选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>），可以撤回反转、摘取、重置或改写。变基停在中途时，例如在编辑一个提交，要先把它做完或中止。停在冲突上的变基或摘取没法撤销。见 [撤销与找回](/guide/work/undo/)。

旧的提交还会在 [Reflog](/guide/work/undo/#reflog) 里留一段时间。

:::note[服务器仓库]
提交在服务器上改写。会改写历史的对话框都写明了在哪台服务器上执行。
:::

## 相关页面

- [解决冲突](/guide/work/conflicts/)
- [撤销与找回](/guide/work/undo/)
- [合并与变基](/guide/branches/merge-rebase/)
