---
title: "分支"
description: "新建、检出、跟踪、改名、删除、置顶与归档分支，设置父分支，在侧边栏里过滤与分组分支。"
---

本地分支列在侧边栏的 :ui[branch.group] 下。对分支做的事大多从这里开始：右键点按它打开菜单，或者把它拖到别处。

::screenshot[侧边栏的下半部分。分支下面，main 带着 HEAD 标记和 ↑3，feature 文件夹里是 dark-mode、station-map 与 units-toggle。已归档分支是空的。标签下列着 v0.1.0 到 v0.4.0。远端下面，origin 里有带房子图标的 main 和收起的 feature 文件夹。底栏左边是过滤输入框，右边是添加与显示设置两个按钮。]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. 当前所在的分支，带着 HEAD 标记和还没推送的提交数
2. 名字以 `feature/` 开头的分支所在的文件夹
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. 添加按钮与显示设置按钮

## 在侧边栏里 {#sidebar}

点一个分支，历史里就显示它的提交。连按它就检出。

跟踪远端分支的分支会显示两边差了多少。↑ 是你有、远端还没有的提交数。↓ 是远端有、你还没有的提交数。把指针停在分支上，可以看到它跟踪的是哪个分支。

很久没有新提交的分支是陈旧的分支。它的名字会变暗，后面跟着一个时钟和多久没更新。`main`、`master`、`trunk`、`dev`、`develop`、`next`，以及做了别的分支父分支的分支，都不会算作陈旧。

:ui[remote.group] 下，房子图标标出每个远端的默认分支。

## 新建分支 {#create}

1. 选 :ui[menu.repository > branch.createMenu]（<kbd>⌘B</kbd>）。也可以点侧边栏底部的添加按钮，或者右键点按 :ui[branch.group]，在菜单里选它。
2. 在 :ui[reference.name] 里输入名字。
3. 在 :ui[branch.start] 里选分支从哪里开始。一开始是当前所在的分支，或者你右键点按的那一项。
4. 设置选项：
   - :ui[branch.trackStart] 让新分支跟踪起点。只有起点是分支时才能勾选。
   - :ui[branch.pin] 把新分支放进 :ui[sidebar.pinned]。
   - :ui[branch.checkoutCreated] 创建后马上切换到新分支。Spooky 会记住这个选择。
   - :ui[branch.parentOption] 把起点设为新分支的 [父分支](#parent)。
5. 点 :ui[branch.create]。

想从某个分支、标签或提交开始，右键点按它，选 :ui[branch.createFromMenu]{1="main"}。也可以把它拖到 :ui[branch.group] 上。

输入时，Spooky 会把名字改成 Git 能用的样子：空格和 Git 不允许的字符换成 `-` 或者去掉。想按原样输入，到 :ui[app.name > settings.title] › :ui[settings.general] 里关掉 :ui[branch.cleanNames]，见 [操作](/guide/settings/general/#operations)。

名字里的 `/` 会把分支放进文件夹，比如 `feature/units-toggle` 在 `feature` 里。右键点按一个文件夹，选 :ui[branch.createMenu]，名字会先填好这个文件夹。

## 检出分支 {#checkout}

连按一个分支，或者右键点按它，选 :ui[branch.checkoutNamed]{1="feature/dark-mode"}。

远端分支也可以连按：

- 已有本地分支跟踪它时，Spooky 检出那个本地分支。
- 有同名的本地分支、但没有跟踪它时，Spooky 先用 :ui[branch.trackExisting.title] 问一下。然后检出那个分支，并让它跟踪这个远端分支。
- 都没有时，Spooky 新建一个跟踪它的同名本地分支，再检出它。

已跟踪的文件有改动时，Spooky 会先问要不要储藏，见 [自动储藏](/guide/work/stash/#auto-stash)。

已在别的工作树里检出的分支，不能在这里再检出。连按它，Spooky 会改为打开那个工作树。按住 <kbd>⌘</kbd> 连按，会在新标签页里打开。

### 检出标签或提交 {#checkout-revision}

连按一个标签，就检出它所在的提交。想检出别的，选 :ui[workspace.title > rewrite.checkout.menu]（<kbd>⇧⌘B</kbd>），选好分支、标签或提交，点 :ui[rewrite.checkout.button]。

选的不是本地分支时，对话框会提示 HEAD 将分离。HEAD 分离时，你在一个提交上，而不在分支上。在这里做的提交想留下来，就从它们新建一个分支。

## 跟踪远端分支 {#track}

本地分支可以跟踪远端上的一个分支，这个分支就是它的上游。拉取和推送默认用上游。↑ 和 ↓ 的数字也是跟上游比出来的。

为远端分支建一个本地分支：

1. 右键点按远端分支，选 :ui[branch.trackMenu]{1="origin/feature/station-map"}，或者把它拖到 :ui[branch.group] 上。
2. :ui[branch.remoteField] 显示这个远端分支。想换个名字，改 :ui[reference.name]。
3. :ui[branch.track.checkout] 每次都是勾选的。想留在当前分支，取消勾选。
4. 点 :ui[branch.track.submit]。

想改已有分支跟踪的对象，右键点按它，在 :ui[branch.tracking] 里选一个分支。:ui[branch.tracking.remove] 让它不再跟踪。对当前所在的分支，也可以按住 <kbd>⌥</kbd> 把远端分支拖到它上面。

不在当前的分支落后于上游、又没有自己的提交时，它的菜单里有 :ui[branch.fastForward]{1="main"}。这一项不用检出，就能把分支前移到上游的位置。

## 重命名分支 {#rename}

右键点按分支，选 :ui[reference.renameMenu]{1="feature/dark-mode"}。输入新名字，点 :ui[reference.rename]。

置顶、归档与父分支的设置会跟着分支走。重命名远端分支时，远端上的分支也会改名。

想把分支移进文件夹，把它拖到文件夹上，见 [拖放](/guide/branches/merge-rebase/#drag-and-drop)。

## 删除分支 {#delete}

右键点按分支，选 :ui[reference.deleteMenu]{1="feature/dark-mode"}。也可以在侧边栏里选中一个或几个分支，按 <kbd>⌘⌫</kbd>，这时焦点要在侧边栏上。

Spooky 总会先问一下。对话框里有两个选项：

- :ui[branch.forceDelete]：分支没有完全合并也删除。不勾选时，Spooky 会列出没有完全合并的分支，再问一次。
- :ui[branch.deleteUpstream]：把它跟踪的远端分支也删掉。只删一个分支、它跟踪的远端分支也还在时，才有这一项。

当前所在的分支不能删除，先检出别的分支。

删除远端分支，就是在远端上删掉它。

想找回删掉的本地分支，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。勾选了 :ui[branch.deleteUpstream] 也能撤销。只删除远端分支时不能撤销，见 [撤销与找回](/guide/work/undo/)。

## 置顶分支 {#pin}

置顶的分支会从 :ui[branch.group] 移到列表最上面的 :ui[sidebar.pinned] 里。常回去的分支可以置顶。

右键点按分支，选 :ui[branch.pinNamed]{1="feature/station-map"}，或者把它拖到 :ui[sidebar.pinned] 上。选中了几个分支时，这一项是 :ui[branch.pinMultiple]{1="2"}。想放回去，改选 :ui[branch.unpinNamed]{1="feature/station-map"}。

## 归档分支 {#archive}

归档把分支放到一边，但不删除它。分支会从 :ui[branch.group] 移到 :ui[sidebar.archived]。用起来和之前一样。

右键点按分支，选 :ui[branch.archiveNamed]{1="feature/dark-mode"}，或者把它拖到 :ui[sidebar.archived] 上。想拿回来，改选 :ui[branch.unarchiveNamed]{1="feature/dark-mode"}。

Spooky 也能找出值得归档的分支，还能替你归档，见 [分支整理](/guide/branches/review/#archive-suggestions)。

:::note[服务器仓库]
置顶、归档与父分支都保存在仓库的 Git 配置里。服务器仓库的这些设置保存在服务器上。
:::

## 父分支 {#parent}

父分支是你的分支所基于、需要跟上的那个分支，比如 `feature/units-toggle` 的父分支是 `main`。

设置时，右键点按分支，在 :ui[branch.parent] 里选一个建议的分支。想选别的分支，选 :ui[branch.parent.setMenu]，在 :ui[branch.parent.field] 里选好，点 :ui[branch.parent.set]。新建分支时也可以设置。:ui[branch.parent.remove] 会去掉父分支。

分支有了父分支之后：

- 在历史里比较分支时，先拿父分支来比，见 [与另一个分支比较](/guide/history/browse/#compare-branches)。
- 父分支有你的分支没有的提交时，这个分支的历史上方会显示 :ui[history.parentBanner.title]。分支菜单里的 :ui[branch.updateNamed]{1="feature/units-toggle"} 可以把这些提交并进来，见 [用父分支更新分支](/guide/branches/merge-rebase/#update)。
- 对当前所在的分支，菜单里的 :ui[branch.mergeWith]{1="main"} 与 :ui[branch.rebaseOn]{1="main"} 会打开合并与变基对话框，并选好父分支。
- 父分支本身不会算作陈旧。

## 过滤与分组 {#filter}

在侧边栏底部的 :ui[sidebar.filter] 里输入，就只显示匹配的分支、标签、远端分支、子模块与工作树。字母不用挨着：输入 `stm` 能找到 `station-map`。不区分大小写和变音符号。过滤时文件夹会展开，按 <kbd>Esc</kbd> 清空输入框。

点右下角的显示设置按钮，或者选 :ui[menu.view > sidebar.menu]，设置侧边栏显示什么。这些设置对所有窗口都有效。

- :ui[sidebar.groupRefs] 把带 `/` 的名字放进文件夹，一开始是打开的。:ui[sidebar.groupedRefsOnTop] 把文件夹排在其它分支前面。
- :ui[sidebar.showStaleInfo] 标出陈旧的分支。:ui[sidebar.staleInterval] 设置多久没有提交算陈旧，一开始是 6 个月。
- :ui[sidebar.remoteFilter] 与 :ui[sidebar.tagsFilter] 用 :ui[sidebar.showNewest] 只列出最新的几个。远端分支按每个远端分别计数。标签还能用 :ui[sidebar.sortBy] 排序。过滤时会列出全部匹配项。
- :ui[sidebar.autoArchive] 见 [分支整理](/guide/branches/review/#auto-archive)。

## 相关页面

- [获取、拉取与推送](/guide/branches/sync/)
- [合并与变基](/guide/branches/merge-rebase/)
- [分支整理](/guide/branches/review/)
- [工作树](/guide/advanced/worktrees/)
