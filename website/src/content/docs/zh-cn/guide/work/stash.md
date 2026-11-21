---
title: "储藏"
description: "保存、应用与查看储藏，以及使用自动储藏。"
---

储藏把本地改动先放到一边，不用提交。需要暂时腾出干净的工作区、之后再把改动拿回来时，就用它，比如切换分支或拉取之前。

储藏属于这个仓库，不会推送到远端。

## 保存储藏 {#save}

1. 选 :ui[workspace.title > stash.saveMenu]（<kbd>⇧⌘S</kbd>），或者点工具栏上的 :ui[toolbar.saveStash]。
2. 可以在 :ui[stash.message] 里写几句说明，以后好找。
3. 想把新文件也放到一边，勾选 :ui[stash.includeUntracked]。Spooky 会记住这个选择。
4. 点 :ui[stash.save]。

所有改动都进了储藏，工作区又干净了。没有可保存的改动时，Spooky 会提示 :ui[stash.error.noChanges]。只有勾选了 :ui[stash.includeUntracked]，新文件才算在内。

想存一份改动、但接着改下去，改选 :ui[workspace.title > stash.snapshotMenu]（<kbd>⌃⇧⌘S</kbd>）。对话框一样，工作区保持原样。

## 储藏部分文件 {#partial}

只想把几个文件放到一边，在工作区里选中它们，右键点按，选 :ui[stash.stashFile]{1="README.md"} 或 :ui[stash.stashItems]{1="3"}。下面的快照项会让文件保持原样。

也可以把文件拖到侧边栏的 :ui[stash.title] 上。

选中的新文件总会进储藏，不管有没有勾选 :ui[stash.includeUntracked]。

:::tip
菜单打开时按住 <kbd>⌥</kbd>，这些项会变成快速版本，比如 :ui[stash.quickStashFile]{1="README.md"}。它们不弹对话框，直接保存，说明由 Git 来写。
:::

## 查看储藏 {#view}

点侧边栏里的 :ui[stash.title]，或者选 :ui[menu.view > stash.show]（<kbd>⌘3</kbd>）。

左边的列表把最新的储藏排在最前面。每一行写着 :ui[stash.basedOn] 和保存时所在的分支，还有日期与说明。想筛选列表，在工具栏的搜索框里输入。

::screenshot[储藏视图。左边的列表里有三个储藏，选中的是 Halfway through the units toggle。右边是它的详情，提交信息下面露出 “应用” “删除” 与 “比较工具” 三个按钮。]{name="work-stashes" frame="window" markers="33,36 84,35.5"}

1. 储藏列表
2. :ui[stash.applyButton]、:ui[stash.deleteButton] 与 :ui[history.diffTool]

选中一个储藏，右边就显示它的改动，版式和提交详情一样。把指针停在详情上，会出现 :ui[stash.applyButton]、:ui[stash.deleteButton] 与 :ui[history.diffTool] 三个按钮。:ui[history.diffTool] 在比较工具里打开这个储藏。

## 应用储藏 {#apply}

应用就是把储藏里的改动拿回工作区。

1. 选 :ui[workspace.title > stash.applyMenu]（<kbd>⌥⇧⌘S</kbd>），或者点工具栏上的 :ui[toolbar.applyStash]。也可以把储藏拖到侧边栏的 :ui[workspace.title] 或当前分支上。
2. 在 :ui[stash.picker] 里选储藏。在储藏视图里，选中的那个已经选好了。
3. 设置选项：
   - :ui[stash.deleteAfterApply]：改动拿回来以后删掉这个储藏。
   - :ui[stash.restoreIndex]：保存储藏时已暂存的改动，重新暂存。
4. 点 :ui[stash.apply]。

这两个选项 Spooky 都会记住。

储藏里的改动和工作区现在的内容冲突时，Spooky 会提示 :ui[stash.error.conflicts]。即使勾选了 :ui[stash.deleteAfterApply]，储藏也会留着。冲突的解决方法见 [解决冲突](/guide/work/conflicts/)。

只想拿回一个文件，打开储藏，把这个文件从详情里拖到侧边栏的 :ui[workspace.title] 上。

## 删除储藏 {#delete}

在储藏视图里右键点按一个储藏，选 :ui[stash.deleteNamed]{1="Halfway through the units toggle"}。选中了几个储藏时，这一项是 :ui[stash.deleteMultiple]{1="2"}。也可以按 <kbd>⌘⌫</kbd>。

Spooky 每次都会先问。删掉以后想拿回来，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

## 自动储藏 {#auto-stash}

有些操作在有本地改动时不能进行，比如切换分支、拉取或合并。被挡住时，Spooky 会问要不要先把改动储藏起来。

::screenshot[本地改动挡住了操作，对话框问要不要先把它们储藏起来。里面有一个可以不填的说明框、“操作完成后恢复这些改动” 复选框，以及 “中止” “不储藏” 与 “储藏改动” 三个按钮。]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm]：储藏改动，再进行操作。
- :ui[stash.autoStash.skip]：不储藏，直接进行操作。改动仍然挡着的话，操作照常失败。
- :ui[stash.autoStash.abort]：取消操作。

勾选 :ui[stash.autoStash.reapply]，操作一完成就把改动拿回来。不勾选的话，储藏留在列表里，以后自己应用。Spooky 会记住这个选择。

已跟踪的文件有改动时切换分支，Spooky 会在开始前就问，即使这些改动并不妨碍切换。

中间哪一步出了问题，改动都留在储藏里，Spooky 会告诉你发生了什么。

不想再被问，在 :ui[app.name > settings.title] › :ui[settings.general] 里关掉 :ui[stash.offerAutoStash]，见 [操作](/guide/settings/general/#operations)。

## 相关页面

- [工作区](/guide/work/working-copy/)
- [解决冲突](/guide/work/conflicts/)
- [分支](/guide/branches/branches/)
