---
title: "工作树"
description: "在额外的工作树里检出分支，以及打开、移动、修复与删除工作树。"
---

工作树是从同一个仓库检出的另一个文件夹。每个工作树有自己检出的分支和工作区。它们共用仓库的提交和分支。这样你可以在第二个分支上工作，不用在第一个文件夹里储藏或切换分支。

一个分支同一时间只能在一个工作树里检出。

## 在侧边栏里 {#sidebar}

工作树列在侧边栏的 :ui[worktree.group] 下，按名字排序。名字是工作树路径的最后一段。窗口里打开着的那个工作树不列出。把指针停在一个工作树上，可以看到它检出在哪里。

点一个工作树，可以看到它的名字、路径、当前版本和分支。连按它，会在同一个窗口里打开。

在别的工作树里检出的分支，图标上带着一个小角标。右键点按它，菜单里写着它在哪个工作树里。菜单里还有打开或删除那个工作树的项。见 [检出分支](/guide/branches/branches/#checkout)。

想在仓库管理窗口里也列出工作树，见 [整理列表](/guide/repositories/manager/#organize)。

## 添加工作树 {#add}

任选一种方式开始：

- 选 :ui[menu.repository > menu.addWorktree]。
- 点侧边栏底部的添加按钮，或者右键点按 :ui[worktree.group]，在菜单里选 :ui[worktree.add.menu]。
- 右键点按一个本地分支，选 :ui[worktree.checkoutBranch]{1="feature/units-toggle"}。
- 把一个本地分支拖到 :ui[worktree.group] 上。

在对话框里：

1. 在 :ui[worktree.revision] 一栏选择或输入要检出的分支或版本。从分支开始时，这一栏已经填好。
2. 在 :ui[worktree.destination] 一栏填新文件夹的完整路径。:ui[submodule.path.select] 按钮从仓库文件夹的旁边开始。它会建议一个由仓库名和版本组成的名字。这个文件夹必须还不存在，或者是空的。
3. 勾选 :ui[worktree.detach]，会在这个版本上检出分离的 HEAD，不占用任何分支。
4. 点 :ui[worktree.add.submit]。

分支已经在某个工作树里检出时，对话框会提示。勾选 :ui[worktree.detach]，或者 :ui[dialog.options] 里的 :ui[worktree.force]，就能照样创建。

仓库里至少要有一个提交。工作树建好后，窗口还停在原来打开的仓库上。新的工作树出现在侧边栏里。

## 打开工作树 {#open}

工作树像别的仓库一样打开。在侧边栏右键点按它，从菜单里选：

- :ui[worktree.open.current]、:ui[worktree.open.newTab] 或 :ui[worktree.open.newWindow]
- :ui[worktree.reveal]、:ui[action.copyPath] 或 :ui[action.openTerminal]

## 移动工作树 {#move}

右键点按一个工作树，选 :ui[worktree.move.menu]。填新的路径，或者点 :ui[submodule.path.select]。工作树里的改动会跟着一起移过去。

## 删除工作树 {#remove}

右键点按一个工作树，选 :ui[worktree.remove.menu]。这会删掉工作树的文件夹。它检出过的分支还留在仓库里。

工作树里有改动或未跟踪的文件时，Git 会拒绝删除。勾选 :ui[worktree.remove.force]，就连同它们一起删掉。

仓库的主工作树，也就是放着 `.git` 目录的那个文件夹，不能移动或删除。打开着别的工作树时，它会出现在列表里。

## 修复工作树 {#repair}

工作树的文件夹在 Spooky 之外被移走或删掉后，这个工作树就失效了。它在侧边栏里带着警告图标。你也不能打开它。它的详情写着 :ui[worktree.invalid] 和 Git 给出的原因，下面有两个按钮：

- :ui[worktree.invalid.repair]：文件夹被你移走了时，在 :ui[worktree.location] 菜单里选 :ui[submodule.path.select]，找到它现在的位置。Spooky 核对过这个文件夹确实是这个仓库的这个工作树之后，点 :ui[worktree.relocate.submit]。
- :ui[worktree.invalid.remove]：文件夹已经没有了时，这会把工作树剩下的登记从仓库里去掉。

工作树的右键菜单里也有这两项。

## 撤销 {#undo}

添加、移动、删除和修复工作树都不能用 <kbd>⌘Z</kbd> 撤销。做过其中一项之后，在它之前的操作也不能再撤销。见 [撤销与找回](/guide/work/undo/)。

:::note[服务器仓库]
工作树建在服务器上，路径也是服务器上的路径。:ui[submodule.path.select] 浏览的是服务器上的文件夹。

Spooky 能在你的 Mac 上找到工作树的文件夹时，才能用 :ui[worktree.reveal]。工作树在仓库文件夹里面时，Spooky 经仓库的位置找到它。否则在你的 Mac 挂载的卷里找。见 [在这台 Mac 上的位置](/guide/server/local-location/)。
:::

## 相关页面

- [分支](/guide/branches/branches/)
- [子模块](/guide/advanced/submodules/)
- [仓库管理窗口](/guide/repositories/manager/)
