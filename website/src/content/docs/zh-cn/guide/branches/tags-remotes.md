---
title: "标签与远端"
description: "新建、发布与删除标签，添加、编辑、重命名与移除远端。"
---

标签列在侧边栏的 :ui[sidebar.tags] 下，远端列在 :ui[remote.group] 下。它们各有自己的菜单：右键点按一个，就能看到可以对它做什么。

## 标签 {#tags}

标签给一个提交起一个固定的名字，通常用来标记版本，比如 `v0.4.0`。和分支不同，提交时它不会跟着移动。

把指针停在标签上，可以看到它指向的提交，有说明的话也会显示出来。连按标签就检出它所在的提交，见 [检出标签或提交](/guide/branches/branches/#checkout-revision)。

和分支一样，名字里带 `/` 的标签会放进文件夹。想只显示最新的几个，或者倒过来排序，见 [过滤与分组](/guide/branches/branches/#filter)。

### 新建标签 {#create-tag}

1. 选 :ui[menu.repository > tag.createMenu]（<kbd>⇧⌘T</kbd>），或者从侧边栏底部的 :ui[reference.addMenu] 按钮里选。想给某个分支或提交打标签，改为右键点按它，选 :ui[tag.createFrom]{1="main"}。
2. 在 :ui[reference.name] 里输入名字。
3. :ui[tag.revision] 是要打标签的提交。一开始是当前所在的分支，或者你右键点按的那一项。
4. 可以写一段 :ui[tag.messageField]。不写的话，标签只是提交的一个名字。写了的话，Git 还会记下是谁、在什么时候打的标签。
5. 想给标签签名，勾选 :ui[tag.sign]，在 :ui[tag.signingKey] 里选一个密钥。:ui[tag.signingKey.configured] 用 Git 里设置好的密钥。签名的标签必须有说明。Spooky 会记住是否签名。
6. 点 :ui[tag.create.submit]。

也可以把提交或本地分支拖到 :ui[sidebar.tags] 或标签文件夹上。

新标签在发布之前只存在于这个仓库里。想去掉它，选 :ui[menu.edit > menu.undo]（<kbd>⌘Z</kbd>）。

### 发布标签 {#publish-tag}

1. 右键点按标签，选 :ui[tag.publishMenu]{1="v0.4.0"}，或者选 :ui[menu.repository > tag.publishMainMenu]。也可以把标签拖到远端上。
2. 核对 :ui[tag.local] 与 :ui[sync.remote]。远端是当前分支跟踪的那个，把标签拖到了别的远端上时就是那个远端。
3. 勾选 :ui[sync.skipHooks]，推送时就不运行仓库的 Git 钩子。
4. 点 :ui[tag.publish]。

发布标签可以撤销，撤销时会把它从远端上删掉。

想一次把全部标签推送到某个远端，右键点按这个远端，选 :ui[tag.pushAll]{1="origin"}。推送对话框也能把全部标签一起推送，见 [推送](/guide/branches/sync/#push)。

### 删除标签 {#delete-tag}

右键点按标签，选 :ui[reference.deleteMenu]{1="v0.1.0"}。也可以在侧边栏里选中一个或几个标签，按 <kbd>⌘⌫</kbd>，这时焦点要在侧边栏上。

Spooky 总会先问一下。想在远端上也删掉这个标签，勾选 :ui[tag.deleteRemote]，在 :ui[sync.remote] 里选好远端。

只在这个仓库里删除标签可以撤销，在远端上删除就撤销不了了。

## 远端 {#remotes}

远端是仓库的另一份副本，你从它那里获取，也推送到它那里，通常放在托管服务上。克隆时的来源一般叫 `origin`。

:ui[remote.group] 下，每个远端列出自己的分支。把指针停在远端上，可以看到它的获取地址与推送地址。

右键点按远端会打开它的菜单：

- :ui[remote.fetchMenu]{1="origin"} 与 :ui[sync.prune] 打开获取这个远端的对话框，见 [获取](/guide/branches/sync/#fetch)。
- :ui[remote.viewInBrowser]{1="origin"} 打开远端的网页。HTTP(S)、SSH 与 `git://` 地址都可以，本机路径不行。
- 其余几项用来添加、编辑、重命名与删除远端，下面分别介绍。

:::note[服务器仓库]
远端是从服务器上访问的，用的是服务器的网络和 SSH 密钥。在 Mac 上能用的地址，在服务器上不一定能用。
:::

### 添加远端 {#add-remote}

1. 选 :ui[menu.repository > remote.addMainMenu]，或者从侧边栏底部的 :ui[reference.addMenu] 按钮里选 :ui[remote.addMenu]。也可以右键点按 :ui[remote.group]。
2. 在 :ui[reference.name] 里输入一个简短的名字，比如 `upstream`。
3. 在 :ui[remote.url] 里粘贴地址。
4. 点 :ui[remote.add.submit]。

添加之前，Spooky 会先检查连接。连上之前对话框一直开着，写错了可以改了再试。远端添加好以后，Spooky 会马上获取一次。

### 远端设置 {#remote-settings}

点侧边栏里的远端，就打开它的设置。顶部的切换按钮有两页：

- :ui[remote.page.general] 显示 Git 怎样和这个远端打交道。
- :ui[remote.page.branches] 列出这个远端的分支，以及每个分支指向的提交。

在 :ui[remote.page.general] 里把指针停在某一行上，会显示这一行的按钮。

| 设置 | 作用 |
|---|---|
| :ui[remote.field.fetchURL] | 从哪里获取。右键点按远端、选 :ui[remote.editConnection] 也能修改它 |
| :ui[remote.skipFetchAll] | 自动获取与 :ui[sync.fetchAll] 时不包括这个远端 |
| :ui[remote.field.fetchRefspecs] | 获取哪些分支，存到哪里 |
| :ui[remote.field.pushURL] | 推送到哪里。没有设置时用获取地址，以灰色显示。:ui[remote.action.unset] 会改回获取地址 |
| :ui[remote.field.pushRefspecs] | 推送哪些分支，推送到哪里 |

Refspec 是一条规则，把一边的分支名对应到另一边的名字。大多数远端只要 Git 默认设好的那一条就够了。想添加一条，点 :ui[remote.group.fetch] 或 :ui[remote.group.push] 旁边的 :ui[remote.action.addRefspec]。

新地址保存之前，Spooky 会先检查一下。对远端设置的修改可以撤销。

### 重命名或移除远端 {#rename-remote}

右键点按远端，选 :ui[reference.renameMenu]{1="origin"} 或 :ui[reference.deleteMenu]{1="origin"}。

移除远端，会把它和它的远端分支从这个仓库里去掉，它指向的那个仓库不受影响。重命名和移除都可以撤销。

## 相关页面

- [分支](/guide/branches/branches/)
- [获取、拉取与推送](/guide/branches/sync/)
- [撤销与找回](/guide/work/undo/)
