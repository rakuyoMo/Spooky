---
title: "Pull Request 与 Merge Request"
description: "列出、新建、讨论、检出、合并与关闭 GitHub 的 Pull Request 和 GitLab 的 Merge Request。"
---

Spooky 会列出仓库远端上的 GitHub Pull Request 和 GitLab Merge Request。阅读、讨论、看 CI/CD 状态、检出、合并和新建，都不用离开仓库窗口。

这需要为远端添加 [托管账号](/guide/hosting/accounts/)。远端在 GitLab 上时，侧边栏、菜单和对话框里的叫法都换成 Merge Request。

::screenshot[远端在 GitLab 上的仓库的 Merge Request 视图。列表里有打开着的、草稿、已合并和已关闭的请求。每一行的标题前有状态图标，下面是编号、作者、日期、分支和标签，右边是 CI/CD 状态的图标。Add a units toggle 已选中，右边是它的讨论：带 “添加” 按钮的标签、描述、一个提交和三条评论。]{name="hosting-requests" frame="window" markers="30.1,9 39,9 20.3,46.8 43.5,40 77.3,9"}

1. 列出哪个远端的请求
2. 筛选按钮，在 :ui[pullRequests.filter.open] 和 :ui[pullRequests.filter.all] 之间切换
3. 请求的状态图标
4. 它的 CI/CD 状态图标
5. 所选请求的几个视图，见 [查看请求](#details)

## 打开列表 {#list}

点侧边栏的 :ui[pr.title]，或者选 :ui[menu.view > pr.show.menu]（<kbd>⌘4</kbd>）。

在列表顶部的菜单里选远端。每一行写着：

- 状态图标和标题。打开着的请求图标是绿色，草稿是灰色，已关闭是红色，已合并是紫色。把指针停在图标上，可以看到状态的名称。
- 编号、作者和打开的时间
- 源分支和要并入的分支。来自 Fork 的请求，源分支前会写出它所在的项目。
- 标签，底色是标签自己的颜色。把指针停在标签上，可以看到它的说明。一行放不下的标签不显示。
- 有 [CI/CD 状态](#checks) 时，右边有一个表示状态的图标

滚到底部会接着读取更多。想把列表重新读一遍，点 :ui[action.refresh] 或按 <kbd>⌘R</kbd>。

列表一开始只列打开着的请求。想连已关闭和已合并的一起看，点列表顶部的筛选按钮，选 :ui[pullRequests.filter.all]。已关闭和已合并的请求不能再合并或关闭。下次打开窗口时，列表回到 :ui[pullRequests.filter.open]。

列表读取失败时会说明原因，已经读到的请求留在下面。账号的令牌被拒绝或缺少权限范围时，可以直接在那里点 :ui[accounts.reauthenticate]。

列表不知道该用哪个账号时，见 [远端用哪个账号](/guide/hosting/accounts/#remotes)。

## 查看请求 {#details}

选中一个请求，右边会显示它。顶部可以在四个视图间切换：

- :ui[pullRequests.conversation]：标题和状态、标签、描述、评论，以及按天分组的提交，按时间从早到晚排列。
- :ui[pullRequests.commits]：请求里的提交。上方一栏列出参与者和提交的数量。
- :ui[pullRequests.changeset]：请求改了什么，比较的是源分支分出来的位置。
- :ui[pullRequests.checks]：请求的各项检查或流水线里的作业，见 [CI/CD 状态](#checks)。

在讨论里连按一个提交，或者按 <kbd>Return</kbd>，可以打开它。右键点按提交可以复制它的哈希。点正文里的链接可以打开它。

:ui[pullRequests.commits] 和 :ui[pullRequests.changeset] 需要请求的提交已经在你的仓库里。还没有时，点 :ui[pullRequests.fetch]。Spooky 会从远端取回这些提交，不改动你的分支。

GitLab 在 Merge Request 关闭或合并 14 天后不再保留它的提交。这之后 :ui[pullRequests.fetch] 取不回来，Spooky 会说明提交已无法取回。只有你的仓库里还没有这些提交时才受影响。

## CI/CD 状态 {#checks}

:ui[pullRequests.checks] 显示请求最新的提交跑得怎么样：

- **GitHub**：这个提交上的检查和提交状态
- **GitLab**：请求最新一条流水线里的作业

顶部是整体状态，下面逐项列出每个检查或作业和它的状态。还有等待中或运行中的项时，Spooky 会自己更新这个视图。

列表里，请求那一行的图标是它的整体状态，把指针停在上面，可以看到状态的名称。没有检查或流水线的请求没有图标。

有日志的检查或作业，那一行左边有一个展开三角。点它，日志显示在这一行下面。再点一次收起。

- **GitHub**：GitHub Actions 的作业结束后有日志。被跳过的作业、提交状态和其它应用写的检查没有。
- **GitLab**：流水线里的每个作业都能展开。作业还在运行时，日志跟着状态一起更新。

日志里不显示时间戳和颜色码。文字可以选中复制。

::screenshot[一个流水线失败的 Merge Request 的 CI/CD 视图。install、typecheck 和 lint 三个作业已通过。unit tests 作业失败，它的日志显示在这一行下面，最后是没通过的测试和让作业结束的错误。preview 作业已跳过。]{name="hosting-checks" frame="closeup"}

## 新建请求 {#create}

源分支必须已经在远端上，要先推送它。然后任选一种方式：

- 点列表顶部的添加按钮。
- 选 :ui[menu.repository > pr.create.menu]（<kbd>⌃⌘P</kbd>）。
- 在侧边栏右键点按一个分支，选 :ui[pr.forBranch.create]{1="feature/units-toggle"}。这个分支已经有打开着的请求时，这一项换成 :ui[pr.forBranch.show]{1="feature/units-toggle"}。

在对话框里：

1. 在 :ui[pullRequests.source] 和 :ui[pullRequests.target] 两行各选一个远端和它上面的分支。源一开始是你右键点按的分支或当前分支，目标是远端的默认分支。只列出和账号在同一个实例上的远端。源选了另一个项目，就是来自 Fork 的请求。
2. 标题一开始是源分支的名字。描述可以不填。
3. 点 :ui[pr.create.submit]。

源和目标不能是同一个分支。

## 讨论 {#discuss}

想发表评论，点讨论末尾的 :ui[pullRequests.addComment]，或者按 <kbd>⌘S</kbd>。

想在评论里提及某个人，输入 `@`。Spooky 会列出参与这个请求的人和项目的成员，并随着你继续输入用户名或名字缩小范围。按 <kbd>↑</kbd> 或 <kbd>↓</kbd> 选一项，按 <kbd>Return</kbd> 插入用户名，按 <kbd>Esc</kbd> 关掉列表。

::screenshot[一条以 @ 开头的新评论。下面的列表列出 sam、jonas、alex、mina、priya 和 leo，每一项写着名字的首字母和全名，sam 已选中。]{name="hosting-mention" frame="closeup"}

自己的评论，可以用评论上的 :ui[pullRequests.comment.edit] 和 :ui[pullRequests.comment.delete]，也可以右键点按它。连按自己的评论同样会打开编辑。删除评论不能撤销。

在 GitLab 上，还可以用 :ui[pullRequests.comment.reply] 回复任何一条评论。回复会放进 GitLab 上的同一个讨论里。

自己的请求，还可以：

- 修改描述：点描述旁边的 :ui[pullRequests.edit]，或者右键点按它，选 :ui[pullRequests.editDescription.menu]。
- 修改标题、描述和目标分支：在列表里连按这个请求，或者右键点按它，选 :ui[pr.edit.menu]{1="#12"}。源和目标项目不能改。

## 编辑标签 {#labels}

请求的标签在 :ui[pullRequests.conversation] 里，标题下面。

- 想移除一个标签，点它名称后面的 ×。
- 想添加标签，点 :ui[pullRequests.labels.add]，在项目的标签里选一个。在顶部的输入框里打字可以筛选。
- 想新建标签，点 :ui[pullRequests.labels.add]，再点 :ui[pullRequests.labels.new]。填名称、选颜色，点 :ui[pullRequests.createLabel.title]。Spooky 会在项目里建好这个标签，并加到请求上。

::screenshot[一个请求的标签 enhancement 和 ui，名称后面各有一个 ×，再后面是 “添加” 按钮。下面打开了项目里其它标签的列表，顶部是 “筛选标签” 输入框，底部是 “新建标签…”。]{name="hosting-labels" frame="closeup"}

改完后列表随即更新。账号没有权限改标签时，Spooky 会显示服务给出的原因，标签保持不变。

## 检出请求 {#checkout}

想在本地处理请求的代码，点详情底部的 :ui[pullRequests.checkout]，或者右键点按请求，选 :ui[pr.checkout.menu]{1="#12"}。

填本地分支的名字，点 :ui[pullRequests.checkout]。名字一开始是源分支的名字。来自 Fork 的请求是 `pullrequests/<author>/<branch>`。

Spooky 先取回请求的提交，再检出分支：

- 已有同名的本地分支、又指向这些提交时，直接检出它。
- 同名分支指向别处时，对话框会提示。换个名字即可。
- 否则新建这个分支。同一个项目里的请求，只要远端上的源分支在同一个提交上，新分支就跟踪它。

已跟踪的文件有改动时，Spooky 会先问要不要储藏，见 [自动储藏](/guide/work/stash/#auto-stash)。

跟踪源分支的本地分支有还没推送的提交时，不能检出。这个分支就是当前分支、而且已经在请求的提交上时，也不能检出。

GitLab 不再保留提交的 Merge Request，只有你的仓库里已经有这些提交时才能检出。

## 合并请求 {#merge}

点详情底部的 :ui[pullRequests.merge]。合并在托管服务上进行，不能撤销。

- **GitHub**：在仓库允许的方式里选 :ui[pullRequests.mergeType]：:ui[pullRequests.method.merge]、:ui[pullRequests.method.rebase] 或 :ui[pullRequests.method.squash]。Spooky 会预选你上次用的方式。
- **GitLab**：对话框写出项目的 :ui[pullRequests.mergeStrategy]。想压缩就勾选 :ui[pullRequests.squash]。项目不允许压缩时，没有这一项。项目要求压缩时，这一项一直勾着。

:ui[pullRequests.deleteBranch] 会删除服务上的源分支。一开始按项目的设置勾选。

请求不能合并时，对话框会说明原因，比如它是草稿、有冲突、你的账号没有合并权限，或者服务还在检查。

合并之后，Spooky 会从这个远端获取一次，让它的分支跟上合并的结果。

## 关闭请求 {#close}

点详情底部的 :ui[pullRequests.close] 并确认。想重新打开，到托管服务上操作。

:::note[服务器仓库]
列表、CI/CD 状态和在服务上做的操作都从你的 Mac 发出。取回请求的提交、检出请求和合并后的获取在服务器上执行。:ui[pullRequests.commits] 和 :ui[pullRequests.changeset] 的比较也在服务器上进行。
:::

对服务的每一次请求都会出现在 :ui[activity.title] 窗口的 :ui[activity.service] 页里。CI/CD 状态的自动更新不记在里面。

## 相关页面

- [托管账号](/guide/hosting/accounts/)
- [分支](/guide/branches/branches/)
- [分支整理](/guide/branches/review/)
