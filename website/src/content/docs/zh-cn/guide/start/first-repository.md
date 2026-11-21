---
title: "第一个仓库"
description: "打开一个本机仓库，从改动、暂存、提交到推送，完整地走一遍。"
---

这一页带你完整地走一遍：打开这台 Mac 上的一个仓库，改动一个文件，暂存改动，提交，再把提交推送到远端。

你需要这台 Mac 上的一个 Git 仓库，它要有一个你能推送的远端。还没有的话，[仓库管理窗口](/guide/repositories/manager/) 里讲了怎样克隆或新建一个。

## 打开仓库 {#open}

1. 选 :ui[menu.file > action.openLocal]（<kbd>⌘O</kbd>）。
2. 选中仓库所在的文件夹，点 :ui[repositories.panel.prompt]。

Spooky 打开仓库，显示它的 :ui[workspace.title]。仓库也会加进仓库管理的列表，下次可以直接从那里打开。

选仓库里的任何一个文件夹都可以，Spooky 会打开整个仓库。所选的文件夹不在 Git 仓库里时，Spooky 会提示 :ui[bookmarks.noRepository.title]。点 :ui[bookmarks.noRepository.create] 把这个文件夹变成新仓库，或者点 :ui[action.cancel] 另选一个。

:::note[服务器仓库]
要在服务器上的仓库里工作，改用 :ui[action.addRemote] 添加它，做法见 [添加服务器仓库](/guide/server/add/)。仓库打开以后，这一页其余的步骤都一样。
:::

## 改动文件 {#change}

用任意编辑器改一下仓库里的某个文件，然后存储。Spooky 会发现这处改动，把文件列进 :ui[workspace.title]。改动没有出现的话，点 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

选中这个文件，右边一栏显示改了什么：新增的行是绿色，删掉的行是红色。

## 暂存改动 {#stage}

Git 只提交你暂存的改动，不是你改过的全部内容。暂存就是挑出哪些改动进入下一个提交。其余的改动留在工作区里，以后再说。

暂存一个文件，用下面任一种做法：

- 勾选文件前面的复选框。
- 选中一个或几个文件，按 <kbd>空格</kbd>。
- 点 :ui[working.stageAll]，暂存所有改动的文件。

已暂存的文件保持勾选。只想暂存文件里的某几行，见 [查看与挑选改动](/guide/work/diff/)。

## 提交 {#commit}

提交把已暂存的改动存进仓库的历史。每个提交都附带一段说明，写明改了什么、为什么改。

1. 点 :ui[working.subject]，输入一句简短的概括。输入时提交区会展开。
2. 还想多写几句，写在 :ui[working.body] 里。
3. 点 :ui[working.commit]，或按 <kbd>⌘↩</kbd>。

::screenshot[提交区，提交标题里已输入 “Add gust alerts and a humidity chart”。下面依次是空着的详细说明、“修补最近提交” 与 “署名” 两个复选框、作者的名字与邮箱，以及 “全部暂存” 与 “提交” 按钮。再下面的文件列表里有三个文件已勾选。]{name="start-commit" frame="closeup"}

展开的提交区里还有几样东西：

- 标题框末尾的数字是还能输入的字符数。超过这个数，标题就比建议的长了。
- 标题里没有文字时，:ui[working.commit] 一直是灰的。
- 右边的名字与邮箱会作为作者记进提交。想修改，见 [身份档案与 Git 配置](/guide/settings/identity/)。
- :ui[working.amend] 与 :ui[commit.signOff] 的用法见 [提交改动](/guide/work/commit/)。

提交之后，提交过的文件从列表里消失。侧边栏里当前分支的旁边会显示 ↑1，意思是有一个提交在你的 Mac 上，还没到远端。

## 推送 {#push}

推送把你的提交发到远端。别人能从远端拿到这些提交，远端也多了一份备份。

1. 点工具栏上的 :ui[sync.push]，或选 :ui[menu.repository > sync.pushMenu]（<kbd>⇧⌘U</kbd>）。
2. 确认 :ui[sync.destination] 是你要推送到的远端分支。分支已经跟踪了某个远端分支时，默认选的就是它。
3. 点 :ui[sync.pushHead]。

::screenshot[“推送 HEAD” 对话框：把本地分支 “main” 上的新提交推送到目标 origin/main。下面是收起的 “选项” 一节，以及 “取消” 与 “推送 HEAD” 按钮。]{name="sync" frame="dialog"}

推送完成后，分支旁边的 ↑1 就消失了。:ui[dialog.options] 里的设置见 [推送](/guide/branches/sync/#push)。第一次推送一个分支，见 [发布分支](/guide/branches/sync/#publish)。

:::tip
按住 <kbd>⌥</kbd> 再点 :ui[sync.push] 按钮，它会变成 :ui[sync.quickPush]。这样不弹出对话框，直接把当前分支推送到它的跟踪分支。
:::

## 相关页面

- [工作区](/guide/work/working-copy/)
- [提交改动](/guide/work/commit/)
- [获取、拉取与推送](/guide/branches/sync/)
