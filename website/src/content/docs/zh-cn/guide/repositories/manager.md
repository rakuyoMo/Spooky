---
title: "仓库管理窗口"
description: "在仓库管理窗口里收藏、分组、打开、克隆、新建、扫描与删除仓库，还能找回丢失的仓库。"
---

仓库管理窗口保存一份你常用的仓库列表，这台 Mac 上的和服务器上的都在里面。列表里的每一项是一个书签，指向一个仓库。删掉书签时，仓库文件夹留在原处。把文件夹移到废纸篓要单独勾选。这一页讲怎样添加、整理、打开和删除仓库。

在仓库窗口里想回到列表，点工具栏上的 :ui[toolbar.bookmarks]，或选 :ui[menu.view > menu.showRepositories]（<kbd>⌃⌘R</kbd>）。

::screenshot[仓库管理窗口。侧边栏里有 Driftwood Labs 与 Notes 两个分组，里面是各自的仓库，其中一个是服务器仓库，名称以主机别名开头。右边是选中的仓库 driftwood 的详情：位置、上次打开的时间、最近的提交、描述、提交人身份、当前分支、改动文件的数量与远端。]{name="repositories" frame="window"}

## 添加仓库 {#add}

侧边栏底部的添加按钮带有一个菜单，用来往列表里添加：

| 菜单项 | 作用 |
|---|---|
| :ui[bookmarks.newGroup] | 在所选项的下方新建一个分组，接着输入名称 |
| :ui[bookmarks.add] | 添加已经在这台 Mac 上的仓库，可以一次选好几个文件夹 |
| :ui[action.addRemote] | 添加服务器上的仓库，见 [添加服务器仓库](/guide/server/add/) |
| :ui[bookmarks.create] | 新建一个空仓库，见 [新建仓库](#create) |
| :ui[clone.menu] | 从远端复制一个仓库，见 [克隆仓库](#clone) |
| :ui[scan.menu] | 找出某个文件夹里的仓库，见 [查找仓库](#scan) |

新添加的项放进所选的分组。也可以直接从访达把仓库文件夹拖进列表。用 :ui[menu.file > action.openLocal] 打开的仓库，如果还不在列表里，会被加到列表末尾。

### 新建仓库 {#create}

1. 在添加按钮的菜单里选 :ui[bookmarks.create]。
2. 在 :ui[bookmarks.create.name] 里输入新仓库的名称，它也是仓库文件夹的名称。
3. 点 :ui[bookmarks.create.location] 旁边的 :ui[bookmarks.create.choose]，选择在哪个文件夹里新建。默认是你的个人文件夹。
4. 点 :ui[bookmarks.create.submit]。

Spooky 新建这个文件夹，把它初始化为一个空的 Git 仓库，加进所选的分组，然后打开它。

### 克隆仓库 {#clone}

克隆就是把远端的仓库连同历史，复制到一个新文件夹里。

1. 在添加按钮的菜单里选 :ui[clone.menu]，或按 <kbd>⌃⌘C</kbd>。
2. 在 :ui[clone.url] 里填写仓库的地址，例如以 `https://` 或 `git@` 开头的地址。
3. 在 :ui[clone.to] 里选 :ui[clone.machine.local] 或一台服务器。已经在用的服务器会列在里面。要用别的服务器，选 :ui[clone.machine.other]，填上它的 :ui[remote.host]。
4. 在 :ui[clone.directory] 里选择克隆到哪个文件夹。Spooky 会在里面新建一个以仓库名命名的文件夹。
5. 保持勾选 :ui[clone.submodules]，仓库的子模块会一起检出。仓库用 Git LFS 存放大文件时，勾选 :ui[clone.lfs]。
6. 点 :ui[clone.submit]。

Spooky 先检查能不能连上远端。连不上时，对话框不关，会写出原因，改好地址再试就行。连上后对话框关闭，克隆在后台进行。进度显示在列表里这个仓库的那一行。克隆完成后，Spooky 会发出一条 :ui[clone.notification.title] 通知。

克隆到这台 Mac 时，文件夹默认是你的个人文件夹，或者是 :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory] 里设定的文件夹，见 [克隆与终端](/guide/settings/general/#cloning)。

有最近的克隆时，工具栏上会出现 :ui[toolbar.clone]。点它会显示 :ui[clone.recent.title]。在那里可以停止正在进行的克隆，用 :ui[clone.retry] 重新开始失败或取消的克隆，或者把它 :ui[clone.remove]。连按完成的克隆就能打开它。:ui[clone.recent.clear] 清空这份列表。

:::note[服务器仓库]
克隆到服务器时，Spooky 在服务器上检查连接、执行克隆。新仓库作为服务器仓库加进列表。文件夹要填服务器上的绝对路径，也可以点 :ui[clone.browse] 挑选。Spooky 会记住每台服务器上次用的文件夹。
:::

也可以把仓库的地址拖进列表，或者用链接发起克隆，见 [窗口与导航](/guide/repositories/navigation/)。

### 查找仓库 {#scan}

1. 在添加按钮的菜单里选 :ui[scan.menu]。
2. 在 :ui[scan.in] 里选 :ui[clone.machine.local] 或一台服务器，再选要查找的文件夹。
3. 点 :ui[scan.start]。找到的仓库会陆续列出来。想停下，点 :ui[scan.stop]。
4. 找到的仓库都默认勾选。取消勾选不想要的，再点 :ui[scan.add]。

已经在列表里的仓库不会再列出。可以接连查找几个文件夹或几台服务器，结果会累加起来。

## 整理列表 {#organize}

- 新建分组：在添加按钮的菜单里选 :ui[bookmarks.newGroup]，再输入名称。
- 调整顺序或移进别的分组：直接拖动。
- 改名：右键点按这一项，选 :ui[bookmarks.rename]。在列表里给仓库改名，不会改动它的文件夹名。
- 按名称排序：右键点按，选 :ui[bookmarks.sortChildren] 给一个分组里的项排序，或选 :ui[bookmarks.sortParent] 给这一项所在的分组排序。

:ui[app.name > settings.title] › :ui[settings.general] 里有两个选项决定列表显示什么：

- :ui[settings.showWorktreesInRepositoryList]：有其它工作树的仓库可以展开，列出这些工作树。打开工作树的方式和打开仓库一样。默认关闭。
- :ui[settings.showHostAliasesInRepositoryList]：服务器仓库的名称以主机别名开头。默认打开。

见 [窗口与仓库管理](/guide/settings/general/#windows)。

## 打开仓库 {#open}

连按一个仓库，或选中后按 <kbd>↩</kbd>。仓库在同一个窗口里打开，取代列表。仓库已经在另一个窗口里打开时，Spooky 会切换到那个窗口。

右键点按一个仓库还有更多选择：

- :ui[bookmarks.open]{1="driftwood"} 与 :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder]、:ui[action.copyPath] 与 :ui[action.openTerminal]

右边的详情里也有 :ui[action.open] 与 :ui[bookmarks.multiple.delete] 按钮。点那里的 :ui[bookmarks.detail.edit]，可以修改 :ui[bookmarks.detail.description] 与 :ui[bookmarks.detail.identity]。:ui[bookmarks.detail.unset] 去掉给这个仓库单独设定的身份。每个远端旁边的 :ui[bookmarks.detail.viewInBrowser] 会打开它的网页。这里的描述与身份，和 [仓库设置](/guide/settings/identity/#repository) 里的是同一份。

:::note[服务器仓库]
:ui[action.copyPath] 复制的路径前面带着主机别名，形如 `alias:/path/to/repository`。服务器仓库的详情在选中时才读取。选中它时，Spooky 可能会去连接服务器。
:::

## 丢失的仓库 {#missing}

仓库的文件夹被移动、改名或删除后，它在列表里的名称会变灰，带一个警告标记。详情里写着 :ui[bookmarks.detail.missing]每次显示列表时，Spooky 都会检查这台 Mac 上的仓库。

打开一个丢失的仓库时，窗口显示 :ui[missing.title]。点 :ui[action.refresh] 重新检查，例如重新接上磁盘之后。点 :ui[action.close] 回到列表。

要修好这一项，把它删掉，再从仓库现在的位置重新添加。

:::note[服务器仓库]
服务器仓库只在选中或打开时检查。连不上服务器时，窗口显示 :ui[missing.unreachable.title]{1="alias"}，下面是 SSH 报告的内容，见 [连接状态与重连](/guide/server/connection/)。
:::

## 删除仓库 {#delete}

选中一项或几项，然后用下面任一种做法：

- 按 <kbd>⌫</kbd>。
- 右键点按，选 :ui[bookmarks.delete]{1="driftwood"}。分组选 :ui[bookmarks.deleteFolder]，选了几项时选 :ui[bookmarks.deleteMultiple]{1="2"}。
- 点详情里的 :ui[bookmarks.multiple.delete]。

仓库文件夹还在时，Spooky 会先问 :ui[bookmarks.delete.title]{1="driftwood"}只有书签会被移除，文件夹留在原处。想把文件夹也移到废纸篓，勾选 :ui[bookmarks.delete.trash]。点 :ui[bookmarks.delete.submit] 确认。

空的分组和文件夹已经不在的项会直接删除，不再询问。

:::caution
移到废纸篓的是整个仓库文件夹，包括还没提交的改动。清倒废纸篓之前，还可以从废纸篓里找回。每次打开对话框时，移到废纸篓的复选框都是不勾选的。
:::

有文件夹移不动时，Spooky 显示 :ui[bookmarks.trashFailed.title]，列出留下的文件夹。你的个人文件夹、包含它的文件夹和磁盘的最上层，Spooky 都不会移到废纸篓。

:::note[服务器仓库]
删除服务器仓库时，Spooky 总会先问一句。它的文件夹会移进那台服务器上的废纸篓，不是你 Mac 上的。
:::

## 相关页面

- [窗口与导航](/guide/repositories/navigation/)
- [添加服务器仓库](/guide/server/add/)
- [工作树](/guide/advanced/worktrees/)
