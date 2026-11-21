---
title: "获取、拉取与推送"
description: "获取、拉取与推送，首次发布分支，同步、安全强推与自动获取。"
---

这几个操作在你的仓库和 [远端](/guide/branches/tags-remotes/#remotes) 之间交换提交：

- 获取：从远端下载新提交。你的分支和工作区保持原样。
- 拉取：获取一个远端分支，再把它的提交并进当前所在的分支。
- 推送：把你的提交发到远端分支上。

工具栏上并排放着 :ui[sync.fetch]、:ui[sync.pull] 与 :ui[sync.push]，旁边是 :ui[sync.sync]。:ui[menu.repository] 菜单里也有这些操作。

获取、拉取、推送与同步不会记进撤销记录，所以撤销不了。发布分支可以撤销。

:::note[服务器仓库]
远端是从服务器上访问的，用的是服务器的网络和 SSH 密钥。远端要密码时，Spooky 会来问你，见 [密码与口令的询问](/guide/server/connection/#prompts)。
:::

## 获取 {#fetch}

1. 点工具栏上的 :ui[sync.fetch]，或者选 :ui[menu.repository > sync.fetchMenu]（<kbd>⇧⌘F</kbd>）。只想获取一个远端，在侧边栏里右键点按它，选 :ui[remote.fetchMenu]{1="origin"}。
2. 在 :ui[sync.remote] 里选远端，或者勾选 :ui[sync.allRemotes]。
3. 设置选项：
   - :ui[sync.prune]：去掉远端上已经删除的远端分支。一开始是勾选的。
   - :ui[sync.fetchSubmodules]：同时获取已检出子模块的新提交。
   - :ui[sync.allTags]：同时获取远端上的全部标签。
4. 点 :ui[sync.fetch]。

除了 :ui[sync.allTags]，Spooky 会记住这些选项。

获取之后，侧边栏里的远端分支就是最新的了，本地分支上的 ↓ 是可以拉取的提交数。

:ui[menu.repository > sync.fetchAll] 不弹对话框，直接获取全部远端。在 [远端设置](/guide/branches/tags-remotes/#remote-settings) 里勾选了 :ui[remote.skipFetchAll] 的远端会跳过。

## 拉取 {#pull}

1. 点工具栏上的 :ui[sync.pull]，或者选 :ui[menu.repository > sync.pullMenu]（<kbd>⇧⌘P</kbd>）。想拉取某个远端分支，右键点按它，选 :ui[branch.pullMenu]{1="origin/main"}。
2. 在 :ui[sync.remoteBranch] 里选分支。一开始是当前分支的 [上游](/guide/branches/branches/#track)。
3. 勾选 :ui[sync.rebase]，你的提交会接在拉下来的提交后面，不再用一个合并提交把两边接起来。Spooky 会记住这个选择。
4. 选项上方的预览会告诉你拉取会不会遇到冲突，见 [预览冲突](/guide/branches/merge-rebase/#preview)。
5. 设置选项：
   - :ui[merge.verify]：拉下来的提交没有可信签名时停下。Spooky 会记住它。
   - :ui[sync.skipHooks]：这一次不运行仓库的 Git 钩子。
6. 点 :ui[sync.pull]。

拉取时，已跟踪的文件不能有改动。有改动的话，Spooky 会提出先把改动储藏起来，见 [自动储藏](/guide/work/stash/#auto-stash)。新文件只有在拉取会覆盖它们时才会挡路。

拉取遇到冲突时，Spooky 会切到工作区并显示一条横幅，见 [解决冲突](/guide/work/conflicts/#banner)。

## 推送 {#push}

1. 点工具栏上的 :ui[sync.push]，或者选 :ui[menu.repository > sync.pushMenu]（<kbd>⇧⌘U</kbd>）。
2. 在 :ui[sync.destination] 里选远端分支。一开始是当前分支的上游。
3. 设置选项：
   - :ui[sync.pushAllTags]：把全部本地标签也推送上去。
   - :ui[sync.forcePush]：普通推送推不上去时覆盖远端分支，见 [安全强推](#force-push)。
   - :ui[sync.pushSubmodules]：处理这次推送引用到的子模块提交，可以选 :ui[sync.pushSubmodules.onDemand] 或 :ui[sync.pushSubmodules.check]。
   - :ui[sync.skipHooks]：这一次不运行仓库的 Git 钩子。
4. 点 :ui[sync.pushHead]。

Spooky 会记住标签与子模块这两个选项。

当前分支还没有跟踪远端分支时，点 :ui[sync.push] 会改为打开发布对话框，见 [发布分支](#publish)。仓库连一个远端都没有时，打开的是发布仓库的对话框，见 [发布仓库](/guide/hosting/accounts/#publish)。

别人先推送到了这个远端分支时，远端会拒绝你的推送。先拉取他们的提交，再推送一次。

想推送不在当前的分支，在侧边栏里把它拖到一个远端分支上。:ui[sync.pushBranch] 对话框会把它推送到那里。这是一次普通推送，没有选项，也不会改变这个分支跟踪的对象。

## 发布分支 {#publish}

新分支在发布之前只存在于你的仓库里。发布就是在远端上创建这个分支。

1. 选 :ui[menu.repository > sync.publishMenu]，或者右键点按分支，选 :ui[branch.publishMenu]{1="feature/station-map"}。也可以在侧边栏里把分支拖到一个远端上。
2. 核对 :ui[branch.local] 与 :ui[sync.remote]。:ui[branch.name] 是远端上的名字，一开始和本地的名字一样。
3. :ui[sync.setUpstream] 让你的分支跟踪新的远端分支，以后拉取和推送都对着它。一开始是勾选的。
4. 勾选 :ui[sync.skipHooks]，就不运行仓库的 Git 钩子。
5. 点 :ui[sync.publish]。

想收回，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

## 同步 {#sync}

同步会对当前分支依次获取、拉取、推送。

1. 点工具栏上的 :ui[sync.sync]，或者选 :ui[menu.repository > sync.syncMenu]（<kbd>⇧⌘Y</kbd>）。
2. 在 :ui[sync.remoteBranch] 里选分支。一开始是当前分支的上游。
3. 需要的话勾选 :ui[sync.rebase]。下方的预览会告诉你拉取会不会遇到冲突。
4. 设置选项：:ui[merge.verify]、:ui[sync.pushAllTags]、:ui[sync.pushSubmodules] 与 :ui[sync.skipHooks] 的作用和拉取、推送时一样。
5. 点 :ui[sync.syncHead]。

和拉取一样，已跟踪的文件有改动时，Spooky 会先提出储藏。

某一步失败时，Spooky 会停在那里，告诉你停在了哪一步、哪些步骤已经完成。在 :ui[activity.title] 里，拉取和推送各有一条记录。

## 推送到别处 {#push-to}

想把分支、标签或提交推送到远端上任意的分支或引用：

1. 选 :ui[menu.repository > sync.pushToMenu]，或者右键点按一个分支，选 :ui[branch.pushToMenu]{1="main"}；标签的菜单里是 :ui[tag.pushToMenu]{1="v0.4.0"}。
2. 在 :ui[sync.revision] 里选要推送的内容，在 :ui[sync.remote] 里选远端。
3. 在 :ui[sync.refSpec] 里填推送到哪里：新的或已有的分支名，或者 `refs/tags/v0.4.0` 这样的完整引用。
4. 点 :ui[sync.pushRevision]。

推送的是分支时，对话框一开始填的是它跟踪的远端分支。推送的是标签时，一开始填的是 `refs/tags/` 加上标签名。

## 安全强推 {#force-push}

改写了已经推送过的提交之后，比如修补或变基之后，普通推送会被拒绝：远端分支上有你的分支已经没有的提交。强推会用你的分支替换远端分支。

Spooky 只做安全强推：只有远端分支还停在你上次获取时的位置，推送才会成功。这期间有人推送过的话，Git 会拒绝，什么都不会被覆盖。Spooky 不会退回到没有保护的强推。

1. 选 :ui[menu.repository > sync.forcePushMenu]（<kbd>⌃⌘U</kbd>），或者右键点按一个本地分支，在菜单里选这一项。
2. 在 :ui[branch.target] 里选本地分支，在 :ui[sync.destination] 里选远端分支。
3. 看一下下方的比对。它会说明推送后远端分支新增几个提交、有几个提交被覆盖。接着：
   - 绿色的一行表示远端分支正是你的分支改写前的版本。通常都是这样。
   - 黄色的一行表示远端分支在别的位置，或者有你的分支从未有过的提交。确认一下是不是真的要覆盖它们。
   - 两边是同一个提交时，没有可推送的内容。
4. 点 :ui[sync.forcePush]。

::screenshot[安全强推对话框。本地分支是 feature/units-toggle，远端分支是 origin/feature/units-toggle。下方带绿色对勾的一行说明远端分支正是这个分支改写前的版本。]{name="branches-force-push" frame="dialog" markers="16.4,67.5"}

1. 比对

推送对话框里的 :ui[sync.forcePush] 选项用的是同样的保护。

:::tip
可以用 :ui[menu.view > menu.customizeToolbar] 把 :ui[toolbar.forcePush] 与 :ui[toolbar.pushTo] 加到工具栏上。
:::

## 快速版本 {#quick}

按住 <kbd>⌥</kbd>，工具栏上的 :ui[sync.fetch]、:ui[sync.pull]、:ui[sync.push] 与 :ui[sync.sync] 会变成 :ui[sync.quickFetch]、:ui[sync.quickPull]、:ui[sync.quickPush] 与 :ui[sync.quickSync]。菜单项也一样会变，比如 :ui[sync.quickPushMenu]。

快速版本不弹对话框，直接执行：

- 它对着当前分支的上游。
- 它用你上次在对话框里选的选项。:ui[sync.skipHooks] 不会沿用。
- :ui[sync.quickFetch] 获取当前分支跟踪的那个远端。上次勾选了 :ui[sync.allRemotes]，或者当前分支没有跟踪任何分支时，获取全部远端。
- 当前分支没有跟踪远端分支时，:ui[sync.quickPush] 与 :ui[sync.quickSync] 会告诉你这一点。

右键菜单里也有快速版本，比如远端的 :ui[sync.quickFetchNamed]{1="origin"}、远端分支的 :ui[sync.quickPullNamed]{1="origin/main"}。

## 自动获取 {#auto-fetch}

Spooky 可以在后台获取，让远端分支和 ↓ 的数字保持最新。到 :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.autoFetch] 里选多久一次：:ui[settings.autoFetch.never]、每 5、10 或 30 分钟，或者 :ui[settings.autoFetch.hour]。一开始是每 30 分钟，见 [操作](/guide/settings/general/#operations)。

- 仓库打开约 10 秒后，Spooky 会看一遍哪些远端到期了，之后每隔几分钟看一次。从没获取过的远端，或者距上次获取已经过了设定间隔的远端，就算到期。
- 只有窗口显示着这个仓库、又没有打开对话框时才获取。Spooky 在后台时照常进行。
- 只有仓库里没有别的操作在执行时才开始。它正在获取时你发起了别的操作，它会停下，让你的操作先执行。:ui[activity.title] 里会写明它为哪个操作停下。
- 它从不询问密码。失败时，错误只出现在 :ui[activity.title] 里。
- 它用你上次在获取对话框里选的清理与子模块选项，并跳过勾选了 :ui[remote.skipFetchAll] 的远端。
- 本机仓库里，它会跳过指向 Mac 上路径的远端，Mac 没联网时也不获取。

## 相关页面

- [合并与变基](/guide/branches/merge-rebase/)
- [分支](/guide/branches/branches/)
- [操作排队与活动](/guide/advanced/queue-activity/)
- [储藏](/guide/work/stash/)
