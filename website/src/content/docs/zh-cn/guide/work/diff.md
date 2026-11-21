---
title: "查看与挑选改动"
description: "查看文件里改了什么，调整 Diff 的显示方式，按文件、按块、按行暂存与丢弃改动。"
---

在工作区里选中一个文件，右边一栏就显示它的 Diff，也就是逐行列出改了什么。在这里可以只暂存属于下一个提交的部分，把不要的扔掉。

## 看懂 Diff {#read}

Diff 分成一个个块。块是一组改动的行，前后带几行没改的内容。块的标题行写明这一块在文件里的位置。

- 新增的行是绿色，删掉的行是红色。左边两列行号，分别对应文件的旧版与新版。
- 文件既有已暂存的改动，也有没暂存的改动时，用这一栏顶部的 :ui[working.unstaged] 与 :ui[working.staged] 切换。没有改动的一侧是灰的。
- Diff 下面的底栏显示一共几个块，增加和删除了多少行。
- 图片的 Diff 显示新旧两张图。:ui[diff.twoUp] 把两张并排放，:ui[diff.oneUp] 一次显示一张，在 :ui[diff.old] 与 :ui[diff.new] 之间切换。

特别大的 Diff 会让窗口变慢，所以 Spooky 先问一句：:ui[working.largeDiff]点 :ui[working.showDiff] 就能看到。大小的上限是 :ui[app.name > settings.title] › :ui[settings.general] 里的 :ui[working.diffThreshold]，默认 20,000 kB，见 [历史与 Diff](/guide/settings/general/#history)。

## Diff 的显示选项 {#options}

最常改的几个选项在 Diff 下面的底栏上：

- 左端有两个按钮。把指针停在按钮上，可以看到它的名称。
  - :ui[diff.ignoreWhitespace] 隐藏只动了空格与制表符的改动。文件里没有别的改动时，Diff 显示 :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] 显示整个文件，改动留在原处。它只对正在看的这个 Diff 生效。
- 右端的 :ui[diff.context] 决定每处改动前后显示几行没改的内容，默认 3 行。也可以从 :ui[menu.view > diff.contextMenu] 里选。

空白与上下文这两项到处都生效：所有仓库、工作区和历史里都一样。

更多选项在 :ui[app.name > settings.title] › :ui[settings.text] 里：

| 设置 | 作用 |
|---|---|
| :ui[text.enableSyntaxColoring] | 按代码的语言着色。默认打开 |
| :ui[text.syntaxColoringInDiffs] | Diff 里也用语法着色。默认关闭 |
| :ui[text.showInvisibles] | 用符号显示空格、制表符与换行 |
| :ui[text.tabWidth] | 一个制表符占几个空格宽 |

这几项的详细说明见 [文本](/guide/settings/appearance/#text)。颜色来自主题，见 [主题](/guide/settings/appearance/#themes)。

## 暂存整个文件 {#stage-file}

暂存就是挑出哪些改动进入下一个提交。暂存整个文件，用下面任一种做法：

- 勾选文件前面的复选框。这个文件在选中的范围里时，所有选中的文件一起暂存。
- 选中文件，按 <kbd>空格</kbd>。所选的文件有没暂存的改动时，空格键暂存它；否则取消暂存。
- 点列表上方的 :ui[working.stageAll]，或选 :ui[workspace.title > working.stageAllMenu]（<kbd>⇧⌘E</kbd>）。

取消暂存：取消勾选复选框，再按一次 <kbd>空格</kbd>，或选 :ui[workspace.title > working.unstageAllMenu]（<kbd>⌥⇧⌘E</kbd>）。全部暂存以后，:ui[working.stageAll] 按钮会变成 :ui[working.unstageAll]。只暂存了一部分时，按住 <kbd>⌥</kbd> 也能让它变过来。

## 暂存块 {#chunks}

每个块的标题行右端都有按钮：

- :ui[working.unstaged] 一侧：:ui[working.discardChunk] 与 :ui[working.stageChunk]
- :ui[working.staged] 一侧：:ui[working.unstageChunk]

点了以后，这一块马上移到另一侧，文件里其余的改动不动。

## 暂存行 {#lines}

一个块里混着属于不同提交的改动时，可以只暂存其中几行。

1. 点一行改动的行号，选中这一行。再点一次就取消选中。
2. 想多选几行，接着点它们的行号。在行号上拖过去，可以选中连续的几行；按住 <kbd>⇧</kbd> 再点，会选中中间的每一行。
3. 点块标题行上的 :ui[working.stageLines]。

::screenshot[src/readings.ts 的 Diff 里的一个块。用行号选中了五行，块的标题行上是 “丢弃所选行” 与 “暂存所选行” 两个按钮。]{name="staging" frame="closeup"}

只有改动的行能选中。每个块各有各的选择，块上的按钮只对这一块里选中的行起作用。在 :ui[working.staged] 一侧，按钮是 :ui[working.unstageLines]。

## 丢弃改动 {#discard}

丢弃就是扔掉不想要的改动。

- **一个文件**：右键点按它，选 :ui[working.discard.menu]；或者选 :ui[workspace.title > working.discardMenu]（<kbd>⇧⌘⌫</kbd>）。
- **全部改动**：选 :ui[workspace.title > working.discardAllMenu]。
- **一个块或几行**：点块标题行上的 :ui[working.discardChunk] 或 :ui[working.discardLines]。

丢弃文件时，Spooky 会先问你。已跟踪的文件回到最后一次提交时的样子，已暂存的改动也一起扔掉。新文件移到废纸篓。点 :ui[working.discard] 或 :ui[working.discardAll.submit] 继续。

丢弃块或行时，Spooky 会问 :ui[working.discardContent.title]勾选 :ui[dialog.doNotAskAgain]，下次就不再问。想恢复这个提问，在 :ui[app.name > settings.title] › :ui[settings.general] 里打开 :ui[settings.warnDiscardingChunks]，见 [确认](/guide/settings/general/#confirmations)。

:::caution
丢弃的改动不在任何提交里。唯一的回头路是 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>），而且只在仓库还没有再变化之前有效。新文件只要还在废纸篓里，就能拿回来。
:::

:::note[服务器仓库]
丢弃会覆盖服务器上的文件。新文件移到服务器的废纸篓；服务器没有废纸篓时，直接永久删除。提问的对话框里有 :ui[dialog.doNotAskAgain]。想恢复这个提问，在 :ui[settings.general] 里打开 :ui[settings.warnDiscardingOnServer]。
:::

## 在别的 App 里比较 {#external}

想用 FileMerge、Kaleidoscope 这类比较工具看改动：

- 把指针停在右边一栏顶部的文件名上，点 :ui[externalTool.action.diffTool]。比较的是你正在看的那一侧。
- 或者右键点按文件，从 :ui[externalTool.compare] 子菜单里选：:ui[externalTool.compare.workingTreeToBase]、:ui[externalTool.compare.workingTreeToIndex] 或 :ui[externalTool.compare.indexToBase]。

第一次用时，Spooky 会问你用哪个 App。以后想换，改 :ui[app.name > settings.title] › :ui[settings.gitConfig] 里的 :ui[externalTool.diffTool]。Spooky 支持 Araxis Merge、BBEdit、Beyond Compare、DeltaWalker、FileMerge、Kaleidoscope、P4Merge、TextMate 与 Visual Studio Code，见 [比较与合并工具](/guide/settings/integration/#diff-merge-tools)。

:::note[服务器仓库]
比较工具拿到的是文件的副本，放在这台 Mac 上的一个临时文件夹里。关掉仓库时，这个文件夹会被删掉。
:::

## 相关页面

- [工作区](/guide/work/working-copy/)
- [提交改动](/guide/work/commit/)
- [撤销与找回](/guide/work/undo/)
