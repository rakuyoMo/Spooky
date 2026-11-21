---
title: "外观与主题"
description: "选择外观，使用内置主题或新建、导入、导出自己的主题，设置文本与编辑器，以及选择应用图标。"
---

:ui[app.name > settings.title] 里有四页决定 Spooky 的样子：:ui[settings.appearance] 管整个 App，:ui[settings.themes] 管 Diff 与文件的配色，:ui[settings.text] 管文字怎样显示，:ui[settings.editor] 管提交信息。

## 外观 {#appearance}

在 :ui[settings.appearance.label] 一行点一张图，整个 App 就换成那种外观：

- :ui[appearance.system] 跟随 macOS。这是默认的选择。
- :ui[appearance.light] 与 :ui[appearance.dark] 不随 macOS 变化。

在仓库窗口里，也可以用 [快捷操作](/guide/repositories/navigation/#quick-actions) 切换：找到那种外观，执行 :ui[quickActions.setAppearance]。

## 应用图标 {#app-icon}

外观下面的 :ui[settings.appIcon.label] 一行列出可选的图标，分两个系列：

| 系列 | 图标 |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise]（默认）、:ui[appIcon.front]、:ui[appIcon.hide]、:ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight]、:ui[appIcon.perch]、:ui[appIcon.cherryPick]、:ui[appIcon.armful] |

指针移到一枚图标上，左边就显示它的大图。大图下面是它在程序坞里的四种样子：原样、连着服务器、深色、深色且连着服务器。点一下图标就换成它。图标区有键盘焦点时，方向键在图标之间移动，按 <kbd>空格</kbd> 换成所在的那一枚。

新图标会出现在程序坞、App 切换器（<kbd>⌘Tab</kbd>）与访达里，Spooky 没在运行时也一样。还有几点：

- 有服务器仓库连着时，图标会亮起来。:ui[appIcon.series.hideAndSeek] 系列里服务器的指示灯亮起，:ui[appIcon.series.cherryPick] 系列里幽灵的眼睛变成发光的星星。
- **系统设置 › 外观** 里的图标与小组件样式选深色，或者选自动而 Spooky 正是深色时，显示深色的一版。选透明或色调样式时，图标不会亮起来。
- 换到 :ui[appIcon.rise] 或从它换走时，程序坞会重启一次。不然固定在程序坞里的 Spooky 还是旧图标。
- 其它图标会存进 `Spooky.app`。写不进去时，页面上会写出原因，图标不变。

## 主题 {#themes}

主题决定 Diff 与文件内容用的字体和颜色。Spooky 自带两个：浅色外观用的 Default，深色外观用的 Default (Dark)。

列表里选中的主题，就是当前外观在用的主题。浅色与深色各记各的。想给另一种外观选主题，先换到那种外观。快捷操作里的 :ui[quickActions.applyTheme] 也能切换主题。

::screenshot[设置窗口的主题页。左边的列表里有 Default 与 Default (Dark)，选中的是 Default，列表底部有添加与移除按钮。右边是一个显示 Menlo-Regular 11.0 的字体框，一个按各自颜色列出纯文本、关键字、字符串、注释等文字类别的列表，以及标着字体颜色、背景、选区、新增、删除的几个色块。最下面是一小段 Diff 预览，有未改动、删除与新增的行。]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. 主题列表
2. :ui[themes.add] 与 :ui[themes.remove]
3. 字体
4. 语法着色区分的各类文字
5. 色块
6. 用这个主题显示的 Diff 预览

### 新建与编辑主题 {#edit-theme}

1. 点列表下方的添加按钮。Spooky 按当前外观的内置主题配色添加 :ui[themes.newName]，并选中它的名字。
2. 输入名字，按 <kbd>Return</kbd>。
3. 点字体框，在字体面板里选字体和字号。
4. 在列表里选一类文字，点 :ui[themes.text] 改它的颜色。:ui[themes.background]、:ui[themes.selection]、:ui[themes.added] 与 :ui[themes.deleted] 设置文字周围的颜色。

改动立即保存，预览也跟着变。之后想改名，选中主题按 <kbd>Return</kbd>。

内置的两个主题可以编辑，但不能改名或删除。删除别的主题时，选中它并点移除按钮。Spooky 会先问一下，删除之后不能撤销。用着这个主题的外观会回到它的内置主题。

### 分享主题 {#share-themes}

每个主题是一个 `.spookytheme` 文件。

- **导出**：把主题从列表拖到访达里的文件夹。
- **导入**：把 `.spookytheme` 文件拖到列表上。也可以在访达里打开它们，或者拖到程序坞里 Spooky 的图标上。

已有同名主题时，Spooky 会问要不要替换。不是有效主题的文件会跳过，并给出提示。

主题存放在 `~/Library/Application Support/Spooky/Themes/`。见 [数据与隐私](/reference/data-privacy/#mac)。

## 文本 {#text}

:ui[settings.text] 页设置 Diff 与文件内容里的文字怎样显示。颜色来自主题。

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[text.enableSyntaxColoring] | 打开 | 按代码的语言着色 |
| :ui[text.syntaxColoringInDiffs] | 关闭 | Diff 里也用语法着色。需要先打开语法着色。 |
| :ui[text.showInvisibles] | 关闭 | 用符号标出空格、Tab 与换行 |
| :ui[text.tabWidth] | 4 | 一个 Tab 占几个空格，1 到 100 |

## 编辑器 {#editor}

:ui[settings.editor] 页设置提交信息的输入框。它们怎样起作用，见 [写提交信息](/guide/work/commit/#write)。

| 设置 | 默认 | 作用 |
|---|---|---|
| :ui[editor.showsCounter] | 打开 | 显示标题还能输入几个字 |
| :ui[editor.subjectLimit] | 50 | 标题的字数上限。可以从菜单里选，也可以输入 1 到 1000 之间的数。 |
| :ui[editor.wrapping] | :ui[editor.softWrap] | 也可以选 :ui[editor.hardWrap]：使用等宽字体，不自动折行 |
| :ui[editor.bodyLimit] | 72 | :ui[editor.hardWrap] 时每行的字数上限 |
| :ui[editor.showsGuide] | 打开 | :ui[editor.hardWrap] 时在上限处画一条参考线 |
| :ui[editor.warnsComments] | 打开 | 提示 Git 会当作注释的行。见 [提交信息里的注释](/guide/work/commit/#comments)。 |
| :ui[editor.stripsComments] | 关闭 | 提交时删掉这些行。关闭提示后才能打开。 |
| :ui[editor.completesIssues] | 打开 | 在 `#` 后面补全 Issue 编号。见 [自动补全](/guide/work/commit/#autocomplete)。 |

## 相关页面

- [通用、更新与环境](/guide/settings/general/)
- [查看与挑选改动](/guide/work/diff/)
- [提交改动](/guide/work/commit/)
- [窗口与导航](/guide/repositories/navigation/)
