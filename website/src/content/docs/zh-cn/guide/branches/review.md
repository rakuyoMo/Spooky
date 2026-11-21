---
title: "分支整理"
description: "把本地分支和一个基准分支比较，找出可以清理的分支，参考归档建议，以及自动归档分支。"
---

分支整理列出你的本地分支，把每一个都和一个基准分支比较。哪些分支可以合并、哪些会冲突、哪些已经陈旧、哪些的远端分支已经不在了，一眼就能看到。这样你就能决定合并、归档还是删除。

想打开它，点侧边栏顶部的 :ui[review.title]，或者选 :ui[menu.view > review.show]（<kbd>⌘5</kbd>）。

::screenshot[分支整理窗口。基准分支是 main。列表里是从 feature/csv-export 到 spike/radar-overlay 的六个分支，各自带着合并状态、领先与落后的提交数和跟踪的分支。选中的是 feature/units-toggle，右边的详情列出它的提交，头部有一个冲突按钮。]{name="branches-review" frame="window" markers="35.4,9 47.3,9 22,52 76,9"}

1. 基准分支
2. 筛选按钮
3. 能否顺利合并
4. 冲突按钮

## 列表 {#list}

在列表顶部的 :ui[review.compareTo] 里选基准分支。一开始是仓库里有的 `next`、`develop`、`dev`、`main`、`master` 中排在最前的一个，都没有时是当前所在的分支。

每个分支一行：

- 左边的图标说明这个分支能不能干净地并入基准，还是会产生冲突。把指针停在上面可以看到说明。
- 右边是这个分支比基准领先、落后几个提交。Spooky 比较时显示 :ui[review.comparing]。
- 第二行是它跟踪的远端分支，没有时写 :ui[review.noTracking]。远端分支已经不在时，名字会变红。
- 分支最后更新的时间，以及这个分支最近的 Pull Request 或 Merge Request，带着编号和表示状态的颜色。

## 筛选与排序 {#filter}

右上角的筛选按钮只显示一部分分支：

- :ui[review.filter.stale] 与 :ui[review.filter.active] 按是否陈旧分开。陈旧是指多久没有新提交，时长在侧边栏的 [显示设置](/guide/branches/branches/#filter) 里设置，一开始是 6 个月。
- :ui[review.filter.trackingError] 显示远端分支已经不在的分支。
- :ui[review.filter.mergeable] 与 :ui[review.filter.conflicts] 按并入基准的结果来分。
- :ui[pr.filter.with] 与 :ui[pr.filter.without] 按有没有打开着的 Pull Request 或 Merge Request 来分。这需要为远端添加 [托管账号](/guide/hosting/accounts/)。没有账号时，列表会提示。
- :ui[review.filter.none] 重新显示全部分支。

旁边的视图设置按钮可以按 :ui[review.sort.name] 或 :ui[review.sort.date] 排序，按 :ui[review.sort.ascending] 或 :ui[review.sort.descending] 排列。筛选和排序 Spooky 都会记住。

想按名字找分支，在工具栏的搜索框里输入。

## 详情 {#details}

选中一个分支，右边会显示它和基准的比较。顶部写着分支和基准。并入会冲突时，那里有一个按钮列出冲突的文件。

:ui[compare.commits] 列出这个分支从基准分出来之后的提交。:ui[history.changeset] 显示这些提交改了什么。两者上方的摘要写着 :ui[review.summary.contributors]、:ui[review.summary.updated]、:ui[review.summary.tracking] 与 :ui[review.summary.mergeStatus]。

可以一次选中几个分支，比如一起归档或删除。

## 处理分支 {#actions}

右键点按一个分支，菜单和侧边栏里的一样。选中了几个分支时，菜单作用于全部所选。

分支和基准会冲突时，菜单里还有 :ui[review.resolveConflicts]。Spooky 会检出这个分支，把基准合并进来。然后你在分支上解决冲突，见 [解决冲突](/guide/work/conflicts/)。

想删除分支，选中后按 <kbd>⌘⌫</kbd>，或者在一行上向左轻扫，点 :ui[review.delete]。和在侧边栏里一样，Spooky 会先问一下。

## 归档建议 {#archive-suggestions}

满足下面任一条件的本地分支，Spooky 会建议 [归档](/guide/branches/branches/#archive)：

- 它已经陈旧。
- 它的 Pull Request 或 Merge Request 已经合并，之后分支上没有新提交。

置顶和已归档的分支不会被建议。`main`、`master`、`trunk`、`dev`、`develop`、`next`，以及做了别的分支父分支的分支，也不会。

有建议、又没有打开自动归档时，侧边栏底部会出现一个带着分支数的按钮。点它打开 :ui[review.archive.title]：

1. 勾选要归档的分支，或者勾选 :ui[menu.selectAll]。一开始一个都没勾。每个分支后面写着建议的原因：:ui[pr.archive.merged] 或 :ui[review.filter.stale]。
2. 点 :ui[review.archive.submit]。

::screenshot[归档分支对话框列出三个分支，每个后面都标着陈旧，勾选了其中一个。底部是自动归档分支的开关。]{name="branches-archive" frame="dialog"}

归档之后，侧边栏底部会有一行说明归档了几个分支，旁边是 :ui[review.archived.undo] 按钮。<kbd>⌘Z</kbd> 也可以。:ui[activity.title] 里记着每个分支为什么被归档。

## 自动归档 {#auto-archive}

Spooky 可以每天检查一次有没有要归档的分支。下面几处都能打开它，它们是同一个设置：

- :ui[review.archive.title] 对话框里的 :ui[review.archive.auto]
- 侧边栏显示设置里的 :ui[sidebar.autoArchive]
- :ui[app.name > settings.title] › :ui[settings.general] 里的 :ui[settings.autoArchive]，见 [操作](/guide/settings/general/#operations)

一开始是关闭的。

每个仓库每天一次，在你使用它的窗口时，Spooky 会找一遍归档建议。有的话，它会打开同一个对话框。你在里面勾选要归档的分支。不论这次归档了没有，都要等一天后再检查。

想让某个分支不参与，右键点按它，勾选菜单里归档项下面的 :ui[review.skipAutoArchive]。

这样归档了分支之后：

- 系统通知会显示 :ui[review.archived.notification]。:ui[activity.title] 里的记录叫 :ui[review.autoArchive]。
- 侧边栏 :ui[sidebar.archived] 旁的圆点表示有你还没看过的分支。点其中一个，过一会儿它的标记就会消失。想一次清掉，右键点按 :ui[sidebar.archived]，选 :ui[sidebar.markAllReviewed]。

## 相关页面

- [分支](/guide/branches/branches/)
- [合并与变基](/guide/branches/merge-rebase/)
- [Pull Request 与 Merge Request](/guide/hosting/pull-requests/)
- [托管账号](/guide/hosting/accounts/)
