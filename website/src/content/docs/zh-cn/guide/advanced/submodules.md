---
title: "子模块"
description: "打开、更新、获取、初始化、同步、移动、改名与删除子模块。"
---

子模块是放在你仓库某个文件夹里的另一个 Git 仓库。你的仓库记着要用它的哪个提交。Spooky 把这条记录叫作子模块指针。

## 在侧边栏里 {#sidebar}

子模块列在侧边栏的 :ui[submodule.group] 下，按路径排序。把指针停在一个子模块上，可以看到它的名字和 URL。

- 灰着的一行是还没检出的子模块。
- 警告图标表示它的配置不完整，或者它的 URL 需要同步。
- 数字是它里面改动了多少个文件。
- ↑ 和 ↓ 表示检出的提交比指针领先或落后多少。

点一个子模块可以查看它的详情。连按一个已检出的子模块，会在同一个窗口里把它当作仓库打开。打开期间，点工具栏的 :ui[toolbar.parentRepository] 就能回去。

在 Working Copy 的文件列表里连按已检出的子模块，也会这样打开。想让连按像别的文件一样打开它，在 :ui[app.name > settings.title] › :ui[settings.general] 里关掉 :ui[files.openSubmodules]，见 [文件列表](/guide/settings/general/#file-list)。

## 详情 {#details}

详情有三页，在顶部切换：

- :ui[submodule.page.general]：名字、路径、状态、本地改动、检出的提交、指针，以及生效的设置。子模块还没初始化，或者 `.gitmodules` 里它的 URL 变了时，顶部会有一条提示，带着修好它的按钮。
- :ui[submodule.page.shared]：`.gitmodules` 里的设置。克隆这个仓库的人都会拿到。这里的改动会出现在 Working Copy 里。像别的改动一样提交它们。
- :ui[submodule.page.local]：这个仓库自己配置里的设置。它们只在这里生效，优先于 `.gitmodules`。

在两个配置页上，可以给子模块改名、移动它、改它的 URL，还能设置三个选项。:ui[submodule.useDefault] 会去掉这个选项。之后用 Git 的默认值。

- :ui[submodule.field.fetchMode]：获取上级仓库时要不要也获取这个子模块。可选 :ui[submodule.fetchMode.always]、:ui[submodule.fetchMode.onDemand]（只在获取到的提交改动了它的指针时，默认）或 :ui[submodule.fetchMode.never]。
- :ui[submodule.field.ignoreMode]：上级仓库的 Working Copy 忽略子模块里的哪些改动。可选 :ui[submodule.ignoreMode.none]（默认）、:ui[submodule.ignoreMode.untracked]、:ui[submodule.ignoreMode.dirty]（只看检出的是不是另一个提交）或 :ui[submodule.ignoreMode.all]。
- :ui[submodule.field.updateStrategy]：更新时怎样把子模块带到指针上。可选 :ui[submodule.updateStrategy.checkout]（默认）、在它当前的分支上 :ui[submodule.updateStrategy.rebase] 或 :ui[submodule.updateStrategy.merge]，或者 :ui[submodule.updateStrategy.none]。

## 添加子模块 {#add}

1. 选 :ui[menu.repository > menu.addSubmodule]。也可以点侧边栏底部的添加按钮，或者右键点按 :ui[submodule.group]，在菜单里选 :ui[submodule.add.menu]。
2. 填子模块仓库的 URL。
3. 在 :ui[submodule.path] 一栏点 :ui[submodule.path.select]，选你仓库里的一个空文件夹。
4. 点 :ui[submodule.add.submit]。

仓库里已经有同名子模块的 Git 目录时，比如来自你删掉的子模块，Spooky 会问你怎么处理。:ui[submodule.forceAdd.reuse] 会接着用它。:ui[submodule.forceAdd.overwrite] 会删掉它再重新克隆。

## 获取与更新 {#update}

- **获取** 从子模块的远端下载新的提交，不改变检出的内容。
- **更新** 检出指针记着的提交。还没初始化的子模块会先初始化。

右键点按一个子模块，选 :ui[submodule.fetch.menu]{1="vendor/charts"} 或 :ui[submodule.update.menu]{1="vendor/charts"}。:ui[menu.repository] 菜单里也有这两项，另外还有一次处理全部子模块的项。

对话框里有这些选项：

- 获取时的 :ui[sync.prune]
- 更新时的 :ui[submodule.update.recursive]。它会连子模块里面的子模块一起更新。这些子模块的远端必须用已经设置好的凭据就能访问。Spooky 没法在中途问你要凭据。

在右键菜单里按住 <kbd>⌥</kbd>，会出现 :ui[submodule.quickFetch]{1="vendor/charts"} 和 :ui[submodule.quickUpdate]{1="vendor/charts"}。它们跳过对话框，用上次的选项。菜单栏里的 :ui[menu.fetchAllSubmodules] 和 :ui[menu.updateAllSubmodules] 也是这样。

只有需要更新时才能更新：子模块还没检出，或者检出的是另一个提交。

### 在别的操作之后更新 {#auto-update}

检出、拉取、合并等操作可能改动已检出子模块的指针。操作完成后，Spooky 会问要不要更新这些子模块。勾选 :ui[submodule.autoUpdate.always]，以后就直接更新。想关掉，到 :ui[app.name > settings.title] › :ui[settings.general] 里关掉 :ui[settings.autoUpdateSubmodules]，见 [操作](/guide/settings/general/#operations)。

### 初始化与同步 {#initialize}

- **初始化** 把子模块在 `.gitmodules` 里的设置复制到你仓库的配置里。之后再更新它，才会检出。
- **同步** 用在 `.gitmodules` 里的 URL 变了的时候。它把你仓库配置里的 URL 和子模块自己仓库里的 URL 都换成新的。

这两项都在右键菜单里，需要时 :ui[submodule.page.general] 页的提示里也有。

## 检出别的版本 {#checkout}

右键点按一个已检出的子模块，在 :ui[submodule.checkoutRevision] 里选子模块的一个分支或标签。当前的版本打着勾。

子模块里的改动挡住检出时，检出会失败。Spooky 不会提出储藏它们。你仓库的储藏管不到子模块。

在你提交子模块的新提交之前，你仓库里的指针不会动。

## 移动、改名与删除 {#manage}

这三项都在右键菜单里：

- **移动** 改变子模块的路径。勾选 :ui[submodule.move.rename]，名字也一起改成新路径。
- **改名** 改变它的名字。`.gitmodules` 和你的配置都用这个名字指代它。文件夹留在原处。
- **删除** 把子模块从你的仓库里去掉。勾选 :ui[submodule.delete.keepWorkingTree]，就只去掉它的配置，留下它的文件。它里面有改动时，Spooky 会先问你，再用 :ui[submodule.forceDelete.submit] 照样删除。

这些操作会改动 `.gitmodules` 和你仓库的索引。提交它们，别人才会拿到。

删除之后，子模块的 Git 目录还留在你仓库的 `.git` 文件夹里。再次添加时可以接着用。

### 修复子模块 {#repair}

子模块的配置不完整时，它的详情写着 :ui[submodule.invalid]，并带着两个按钮。:ui[submodule.repair.submit] 会补上缺的部分：`.gitmodules` 里的条目、指针，或者检出的仓库。Spooky 哪里都找不到子模块的 URL 时，就删掉它再重新添加。

## 撤销 {#undo}

添加、移动、改名和删除子模块，在子模块里检出别的版本，以及改它的 URL 或选项，都可以撤销。见 [撤销与找回](/guide/work/undo/)。

初始化、同步和修复不能撤销。做过其中一项之后，在它之前的操作也不能再撤销。

获取和更新跟仓库的获取、拉取一样，不记进撤销记录。在它们之前的操作照样可以撤销。

:::note[服务器仓库]
这些都在服务器上执行。添加子模块时，你选的是服务器上的文件夹。
:::

## 相关页面

- [获取、拉取与推送](/guide/branches/sync/)
- [工作树](/guide/advanced/worktrees/)
- [撤销与找回](/guide/work/undo/)
