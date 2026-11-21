---
title: "浏览历史"
description: "浏览提交列表与提交图，看懂引用徽标，搜索与筛选提交，调整视图选项。"
---

:ui[history.title] 视图按从新到旧列出仓库的提交，旁边的提交图画出它们之间的关系。选中一个提交，右边就显示它的详情。

::screenshot[一个仓库的历史视图。列表上方的表头写着 “全部分支、远端和标签”，最右端是视图选项按钮。提交按月分组，排在 2026 年 11 月的小标题下面。左边的彩色线条把提交连起来，作者名字旁边有 HEAD、main、v0.4.0 等徽标。右边是所选提交的详情，顶上是 “变更集” 与 “文件树” 两个按钮。]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 81,9"}

1. 表头：列表显示的范围，以及视图选项
2. 指向提交的分支与标签的徽标
3. 提交图
4. 所选提交的详情，见 [提交详情](/guide/history/commit-details/)

## 打开历史 {#open}

- 选 :ui[menu.view > menu.showHistory]（<kbd>⌘2</kbd>），或点侧边栏的 :ui[history.title]，就能把所有分支、远端分支与标签放在一起看。表头写着 :ui[history.all]。
- 点侧边栏里的一个分支、标签或远端分支，就只看它的历史。按住 <kbd>⌘</kbd> 再点别的，可以把几个放在一起看。
- 选 :ui[menu.view > history.showHead]（<kbd>⌘0</kbd>），看当前所在分支的历史。

看的是设了上游的本地分支时，表头把两者都写出来，形如 `main › origin/main`。列表里还会有上游上那些你还没拉取的提交。

## 提交列表 {#list}

每一行写着作者的头像与名字、日期、短哈希，以及提交信息的第一行。提交默认按月分组。

列表显示的是设了上游的本地分支时：

- ↑ 标出还没推送的提交。
- ↓ 标出还没拉取的提交，这些行的颜色会变浅。

Spooky 先读出前 100 个提交，滚到底时再读后面的 100 个。想一次多读一些，在 :ui[app.name > settings.title] › :ui[settings.general] 里改 :ui[history.pageSize]。同一页的 :ui[settings.dateFormat] 决定列表里日期的写法，见 [历史与 Diff](/guide/settings/general/#history)。

点一个提交就选中它。按住 <kbd>⇧</kbd> 或 <kbd>⌘</kbd> 再点，可以选中多个。按 <kbd>⌘C</kbd> 复制所选提交的完整哈希。连按一个提交，就整页打开它的详情。

右键点按一个提交，可以看到对它能做的所有操作。如果这个提交没被选中，菜单只作用于它一个，原来的选择保持不变。

## 提交图 {#graph}

左边的提交图把每个提交画成一个圆点，再往下连到它的父提交。往下伸出不止一条线的，是合并提交。

想隐藏它，在 [视图选项](#view-options) 里关掉 :ui[history.showGraph]（<kbd>⌃⌘G</kbd>）。:ui[history.firstParentOnly] 在每个合并处只沿第一父提交往下走，经合并带进来的提交就不显示了。

## 引用徽标 {#badges}

作者名字旁边的徽标表示有什么指向这个提交：

| 徽标 | 指向提交的是 |
|---|---|
| 蓝色的 HEAD | 当前检出的提交 |
| 蓝色 | 本地分支 |
| 灰色 | 远端分支 |
| 黄色 | 标签 |
| 红色 | 储藏 |

当前所在的分支排在最前面。放不下的徽标会收成一个 “…”。

点标签的徽标，可以看到标签的签名：用的是哪把密钥、签名是否有效，或者 :ui[signature.unsigned]。

## 搜索与筛选 {#search}

1. 按 <kbd>⌘F</kbd>，或点工具栏上的搜索框。
2. 点框里的放大镜，选要搜索什么：:ui[history.search.message]、:ui[history.search.author]、:ui[history.search.committer]、:ui[history.search.file]、:ui[history.search.hash]、:ui[history.search.sinceDate] 或 :ui[history.search.untilDate]。
3. 输入内容，列表就只显示符合的提交。

输入时，Spooky 会给出作者、提交人与文件路径的建议。搜索提交信息时，建议里还能换成别的搜索方式。输入的是日期时，第一条建议是搜索这个日期以来的提交。

各种方式怎样匹配：

- 提交信息、作者与提交人按正则表达式匹配，不分大小写。
- 文件匹配改动过它的提交。文件夹匹配改动过其中任何内容的提交。
- 提交哈希至少要写前 4 个字符。

搜索条件会显示在表头下面的一行里。想再加一个条件，点添加按钮，在新的一行开头的菜单里选它的种类。日期条件可以选 :ui[history.search.after]、:ui[history.search.before] 或 :ui[history.search.range]。想删掉一个条件，点它的移除按钮。

有几个条件时：

- 种类不同的条件要全部满足。
- 种类相同的几个条件，满足其中一个就行。日期例外：每个日期条件都要满足。

切换到别的视图时，搜索就结束了。

## 视图选项 {#view-options}

点表头最右端的视图选项按钮，或者选 :ui[menu.view > history.title]：

| 选项 | 作用 |
|---|---|
| :ui[history.showGraph] | 显示提交图。默认打开 |
| :ui[history.firstParentOnly] | 在每个合并处只沿第一父提交往下走 |
| :ui[history.sortBy] | :ui[history.sort.topo] 把同一条开发线上的提交排在一起。:ui[history.sort.date] 按日期排列。显示提交图时 :ui[history.sort.topo] 始终打开。两项都打开时按日期排列 |
| :ui[history.groupBy] | 按天、按周或按月给提交分组并加上小标题，也可以不分组。只在按日期排列时有效 |
| :ui[history.medium] / :ui[history.small] | 每个提交占两行或一行。小号行只在显示提交图时有效 |
| :ui[signature.verify] | 标出带签名的提交，见 [签名](/guide/history/commit-details/#signatures) |
| :ui[history.compareBranches] | 见 [与另一个分支比较](#compare-branches) |

这些选项对所有窗口和所有仓库都有效。Spooky 会记住它们。

## 与另一个分支比较 {#compare-branches}

想看一个本地分支和另一个分支的关系：

1. 点侧边栏里的这个分支。
2. 点表头里的比较按钮。也可以在视图选项里打开 :ui[history.compareBranches]，或者按 <kbd>⌃⌥⌘C</kbd>。
3. 在 :ui[history.compareTo] 旁边的菜单里选另一个分支。这个分支有父分支时，Spooky 先选父分支。

列表里有一行标出两个分支分开的地方。它下面的提交也属于另一个分支，颜色会变浅。如果这个分支还没有自己的提交，列表里写着 :ui[history.noNewCommits]。

表头还可能出现两个徽标。一个是另一个分支上有、这个分支还没有的提交数。另一个在合并另一个分支会产生冲突时出现，点它可以列出这些文件。

## 在历史中找到一个提交 {#reveal}

列表只显示部分分支时，右键点按一个提交，选 :ui[quickActions.revealInHistory]。列表会换成全部分支，并选中这个提交。

如果这个提交排得很靠后，在前 1 万个提交之外，Spooky 会先问你要不要把历史读到那么远。如果历史里没有这个提交，列表上方会有一行说明。

## 相关页面

- [提交详情](/guide/history/commit-details/)
- [改写历史](/guide/history/rewrite/)
- [分支](/guide/branches/branches/)
