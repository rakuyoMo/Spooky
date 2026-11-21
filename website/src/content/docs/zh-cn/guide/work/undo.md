---
title: "撤销与找回"
description: "了解 ⌘Z 能撤销什么、有些操作为什么撤销不了，以及用 Reflog 找回丢失的提交。"
---

在 Spooky 里对仓库做的大多数事，都能用 <kbd>⌘Z</kbd> 收回。其余的，Git 的 Reflog 记着分支去过哪里，所以提交很少会真的丢掉。

## 撤销与重做 {#undo}

选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）收回上一个操作，菜单项里会写出操作的名称。选 :ui[menu.edit > menu.redo]（<kbd>⇧⌘Z</kbd>）再做一次。可以一步步往回撤好几个操作，从最近的开始。

能撤销的，比如：

- 暂存、提交与修补
- 丢弃改动，把文件移到废纸篓
- 保存、应用与删除储藏
- 检出、新建、重命名与删除分支，新建标签
- 置顶与归档分支，设置上游，快进
- 合并、变基、摘取、反转与重置
- 添加、重命名与删除远端，修改远端的设置
- 发布分支与标签，重命名远端分支
- 标记 assume-unchanged，启用 Git LFS，改动子模块

移到废纸篓的文件，会从废纸篓放回原处。撤销重置时，如果已跟踪的文件有改动，Spooky 会先问要不要把它们储藏起来。新的储藏会留在列表里。

在提交信息这类文本框里输入时，<kbd>⌘Z</kbd> 撤销的是输入的文字。

每个仓库有一份撤销记录，这个仓库的所有窗口共用。Spooky 退出之前它一直都在。撤销要用的快照存在仓库自己的 Git 数据库里，不会推送到任何地方。

:::note[服务器仓库]
快照存在服务器上的仓库里。移到服务器废纸篓的文件，也从那里放回去。
:::

## 撤销不了的操作 {#cant-undo}

撤销是把仓库恢复成原来的样子。有些改动超出了 Spooky 能恢复的范围：

- 删除远端上的分支与标签。连同远端分支一起删除本地分支是个例外：撤销会把两个都建回来。
- 修改提交人身份、忽略规则或其它 Git 设置。
- 合并、变基等操作进行期间做的任何事，包括继续或中止这个操作。
- 停在冲突上的变基或摘取。停在冲突上的合并或反转可以撤销，效果就是中止它。
- 被彻底删掉的新文件，比如在没有废纸篓的服务器上。
- 子模块的初始化、同步与修复，工作树的各种操作，更新 Git LFS 的钩子，以及把仓库发布到托管服务。见 [子模块](/guide/advanced/submodules/#undo)、[工作树](/guide/advanced/worktrees/#undo)、[Git LFS](/guide/advanced/lfs/#undo) 与 [发布仓库](/guide/hosting/accounts/#publish)。

做了这类操作以后，菜单项会写明这个操作撤销不了。在它之前的操作也都撤销不了了。

获取、拉取、推送与同步不会记进撤销记录，也就撤销不了。子模块的获取与更新，以及获取、拉取、推送 LFS 内容，也是这样。

## 暂时撤销不了 {#blocked}

只有仓库还保持着操作结束时的样子，才能撤销。不是这样时，菜单项会变灰，并在括号里写明原因：

| 原因 | 怎么办 |
|---|---|
| :ui[undo.reason.busy] | 等正在执行的操作结束，或者先完成进行中的合并、变基等操作 |
| :ui[undo.reason.disconnected] | 重新连上服务器 |
| :ui[undo.reason.changed] | 仓库在那之后又变了：拉取或同步带来了新提交，或者终端、别的 App 改动了它。把它改回去，就又能撤销了 |

真正撤销之前，Spooky 会再检查一遍仓库。有东西挡着的话，它会停下来说明原因，什么都不会改动。

| 提示 | 原因 |
|---|---|
| :ui[undo.error.changed] | 仓库已经和 Spooky 记下的状态对不上 |
| :ui[undo.error.untracked] | 恢复会覆盖或删掉未跟踪的文件 |
| :ui[undo.error.hidden] | 标记了 assume-unchanged 的文件有本地改动，或者仓库用了 skip-worktree |
| :ui[undo.error.inProgress] | 先完成或中止合并、变基、摘取或反转 |
| :ui[undo.error.conflicts] | 先解决冲突。见 [解决冲突](/guide/work/conflicts/) |
| :ui[undo.error.trash] | 有些文件已经不在废纸篓里，或者原来的位置上有了别的文件 |

## 用 Reflog 找回提交 {#reflog}

Git 会记下 HEAD 和每个本地分支指向过哪些提交。因为重置、变基或删除分支而丢掉的提交，通常还能在这里找到。从来没提交过的改动不在其中。

1. 选 :ui[menu.view > reflog.show]（<kbd>⌘6</kbd>）。
2. 在顶部的 :ui[reflog.ref] 里选 HEAD 或一个本地分支。
3. 找到那一条记录。每一条写着短哈希、发生了什么和时间，下面是 Git 记的说明。想筛选列表，在工具栏的搜索框里输入。
4. 选中这条记录，就能看到这个提交的详情。

::screenshot[HEAD 的 Reflog 视图。每条记录写着短哈希、commit、checkout、reset 这类动作和日期，下面是说明。右边是选中那条记录的提交详情。]{name="work-reflog" frame="window" markers="33.5,9 44.1,37.1 84.4,21.3"}

1. :ui[reflog.ref] 菜单
2. 选中的记录
3. 这个提交的详情

右键点按这条记录，把提交找回来：

- :ui[reflog.createBranch]{1="9e0d36a7"} 在那里新建一个分支，现有的分支都不动。
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} 把正在看的分支移回那个提交，工作区和暂存区不变。Spooky 会先问，做完也能撤销。
- :ui[reflog.cherryPick]{1="9e0d36a7"} 把这个提交复制到当前分支上。也可以把记录拖到侧边栏的 :ui[workspace.title] 或当前分支上。
- :ui[reflog.reset]{1="9e0d36a7"} 打开重置对话框，把当前分支移到那个提交。
- :ui[patch.menu]{1="9e0d36a7"} 把这个提交存成补丁文件。

想在侧边栏里显示 :ui[reflog.title]，在 :ui[sidebar.viewSettings] 里打开 :ui[sidebar.showReflog]。

:::caution
Git 会慢慢清理旧的 Reflog 记录。默认情况下，记录保留 90 天；提交已经不在分支上的，保留 30 天。丢了提交要尽早找回。
:::

:::note[服务器仓库]
Reflog 在服务器上的仓库里，Spooky 从那里读取。
:::

## 相关页面

- [提交改动](/guide/work/commit/)
- [解决冲突](/guide/work/conflicts/)
- [改写历史](/guide/history/rewrite/)
