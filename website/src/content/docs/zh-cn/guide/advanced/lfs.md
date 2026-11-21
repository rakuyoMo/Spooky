---
title: "Git LFS"
description: "启用 Git LFS，按文件或规则跟踪，获取、拉取与推送 LFS 内容。"
---

Git LFS 让大文件不进入仓库的历史。仓库里为每个大文件存一个小小的指针文件，内容放在远端的 LFS 存储里。

Spooky 在仓库所在的机器上执行 Git LFS。

## 需要什么 {#requirements}

Git LFS 2.9.0 或更新的版本，并且在仓库所在机器上 Git 用的 `PATH` 里。

想确认的话，点侧边栏 :ui[workspace.group] 下的 :ui[repositorySettings.title]。:ui[repositorySettings.lfs] 一段写着 Git LFS 的 :ui[lfs.version]。找不到 Git LFS 或者版本太旧时，那里会有一条提示说明怎么解决：

- **在你的 Mac 上**：安装或更新 Git LFS。已经装了却找不到时，打开 :ui[app.name > settings.title] › :ui[settings.environment]，勾选 :ui[settings.environment.loginShell]，或者把 `PATH` 添加为自定义变量。
- **在服务器上**：在那里安装或更新 Git LFS，并把它所在的文件夹加进非交互 SSH 会话的 `PATH`，比如写在 `~/.zshenv` 里。

缺少 Git LFS 时，这一段里需要它的按钮都不可用。

## 启用 Git LFS {#enable}

在仓库设置的 :ui[repositorySettings.lfs] 一段里点 :ui[lfs.enable]。这只为这个仓库设置 Git LFS，不改动你的全局 Git 配置。

Git 设置好了 Git LFS 的过滤器、仓库里也有 Git LFS 的钩子时，Spooky 才认为这个仓库在用 Git LFS。在此之前，这一段只提供 :ui[lfs.enable]，LFS 的菜单项也不可用。

克隆用 Git LFS 的仓库时，勾选 :ui[clone.lfs]。见 [克隆仓库](/guide/repositories/manager/#clone)。

更新 Git LFS 之后，选 :ui[menu.repository > lfs.menu > lfs.menu.update]，更新仓库里 Git LFS 的钩子。

## 跟踪文件 {#track}

匹配跟踪规则的文件交给 Git LFS 存放。规则写在仓库根目录的 `.gitattributes` 里，用这个仓库的人都会拿到。`.gitattributes` 的改动会出现在 Working Copy 里，像别的改动一样提交。

想添加规则，在仓库设置里点 :ui[lfs.createPattern]，或者选 :ui[menu.repository > lfs.menu > lfs.menu.track]。填一条规则，比如 `*.psd`，再点 :ui[files.pattern.save]。

也可以在 Working Copy 里右键点按文件，从 :ui[lfs.menu] 里选：

- :ui[lfs.trackFile]：只跟踪选中的这些文件，按它们确切的路径。选了几个文件时，这一项会写出个数。
- :ui[lfs.trackType.single]{1="psd"}：跟踪扩展名相同的全部文件。选了几个文件时，这一项是 :ui[lfs.trackType]，按它们各自的扩展名跟踪。
- :ui[lfs.createPattern.menu]：自己填规则，一开始是第一个选中文件的路径。

对文件夹，只能用 :ui[lfs.createPattern.menu]。

### 停止跟踪一条规则 {#untrack}

在仓库设置里，点规则旁边的 :ui[lfs.remove] 并确认。这条规则会从 `.gitattributes` 里去掉，已经存进 Git LFS 的文件保持原样。

Git LFS 去不掉某条规则时，Spooky 会写出还剩哪些。用 :ui[repositorySettings.lfs.patterns] 旁边的 :ui[repositorySettings.openInEditor] 手动去掉它们。

## 获取、拉取与推送 LFS 内容 {#transfer}

设置好 Git LFS 之后，Git 通常会在检出文件时下载 LFS 内容，在推送时上传。想自己来做，从菜单栏的 :ui[menu.repository > lfs.menu] 里选：

| 菜单项 | 作用 |
|---|---|
| :ui[lfs.menu.fetch] | 下载当前检出需要的 LFS 内容，Working Copy 不变。 |
| :ui[lfs.menu.pull] | 下载这些内容，并把 Working Copy 里的指针文件换成实际内容。 |
| :ui[lfs.menu.push] | 上传全部本地分支和标签用到的、远端还没有的 LFS 内容。 |

在对话框里选一个远端。一开始是当前分支上游所在的远端，没有上游时是第一个远端。进度显示在侧边栏底部的 [活动区](/guide/advanced/queue-activity/#activity-area)。

## 撤销 {#undo}

启用 Git LFS、添加跟踪规则和去掉跟踪规则，都可以撤销。见 [撤销与找回](/guide/work/undo/)。

更新钩子不能撤销，在它之前的操作也不能再撤销。

获取、拉取和推送 LFS 内容跟仓库的获取、拉取、推送一样，不记进撤销记录。在它们之前的操作照样可以撤销。

:::note[服务器仓库]
Git LFS 在服务器上执行，LFS 内容在服务器和远端之间传输。服务器仓库不需要你的 Mac 装 Git LFS。
:::

## 相关页面

- [系统要求](/reference/requirements/#optional)
- [子模块](/guide/advanced/submodules/)
- [仓库管理窗口](/guide/repositories/manager/)
