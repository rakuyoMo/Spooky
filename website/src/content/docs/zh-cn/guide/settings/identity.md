---
title: "身份档案与 Git 配置"
description: "管理身份档案与 Git 配置，以及单个仓库的仓库设置。"
---

Git 在每个提交里记下姓名与邮箱，还可以用密钥为它签名。Spooky 有三个地方设置这些：

- :ui[app.name > settings.title] 里的 :ui[settings.profiles] 存着几个可以来回切换的身份。
- :ui[app.name > settings.title] 里的 :ui[settings.gitConfig] 设置 Git 程序，以及全局的身份与签名。
- 单个仓库的设置在这个仓库里覆盖全局的设置。

## 身份档案 {#profiles}

身份档案是一组姓名、邮箱与可选的签名密钥，存在一个标题下，比如 “工作”。档案存在这台 Mac 上，本机仓库与服务器仓库都能用。

添加档案：

1. 选 :ui[app.name > settings.title] › :ui[settings.profiles]。
2. 点列表下方的添加按钮。
3. 填好 :ui[profiles.title]、:ui[profiles.userName] 与 :ui[profiles.email]。也可以从这台 Mac 上找到的密钥里选一个 :ui[profiles.signingKey]。
4. 点 :ui[profiles.create.submit]。

标题、用户名与邮箱都必须填。两个档案的标题不能相同，用户名与邮箱也不能同时相同。

想修改档案，选中它，点 :ui[profiles.edit]。想删除，选中它，点移除按钮。删除档案不会改动任何 Git 设置。

正在用的身份还不是档案时，从它的菜单里选 :ui[profiles.addCurrent]{1="alex@example.com"}，填一个标题，点 :ui[profiles.add.submit]。

### 使用档案 {#use-profile}

点身份旁边的头像，就能看到你的档案，正在用的那个前面有勾。选一个档案改动什么，要看在哪里选：

| 在哪里选 | 改动什么 | 先问吗 |
|---|---|---|
| 提交区，或 [仓库设置](#repository) 里的 :ui[bookmarks.detail.identity] | 这个仓库自己的 Git 设置。见 [选择提交人](/guide/work/commit/#identity)。 | 先问 |
| 设置里的 :ui[settings.gitConfig] | 这台 Mac 上全局的 Git 设置 | 不问 |

档案里的姓名与邮箱写进 `user.name` 与 `user.email`。带签名密钥的档案还会设置 `user.signingkey` 与 `gpg.format`。

[快捷操作](/guide/repositories/navigation/#quick-actions) 里也列出了你的档案。:ui[quickActions.setCommitter] 的效果与提交区相同。:ui[quickActions.setGlobalUser] 先问，再把姓名与邮箱写进仓库所在机器上全局的 Git 设置。

:::note[服务器仓库]
给服务器仓库选档案，改动的是服务器上这个仓库的设置。在那里提交的其它工具也会用这个身份。在服务器仓库里执行 :ui[quickActions.setGlobalUser]，写的是你在服务器上的全局设置。
:::

## Git 配置 {#git-config}

:ui[settings.gitConfig] 页分四部分：Git 程序、身份、签名与外部工具。外部工具见 [集成](/guide/settings/integration/#diff-merge-tools)。

::screenshot[设置窗口的 Git 配置页，有 Git 程序、全局的姓名与邮箱、签名设置，以及比较与合并工具。]{name="settings-git-config" frame="window" markers="20,16.7 20,29.4 20,46 20,83.4"}

1. Git 程序
2. 身份
3. 签名
4. 外部工具

### Git 程序 {#git-program}

:ui[settings.gitProgram] 列出这台 Mac 上版本够新的 Git 程序及其版本。Spooky 会在常见的位置找：`/usr/bin/git`（标为系统的那个，起初用它）、Command Line Tools、Xcode、Homebrew 与 MacPorts。

想用没列出来的 Git，选 :ui[settings.gitProgram.choose]，再选中那个程序。如果它不是 Git，或者版本太旧，Spooky 会说明原因，仍用原来那个。菜单下面一行写着 Spooky 接受的最低版本。

:::note[服务器仓库]
这项设置只作用于本机仓库。服务器仓库用服务器上的 Git，见 [系统要求](/reference/requirements/#servers)。
:::

### 全局身份 {#global-identity}

:ui[gitConfig.userName] 与 :ui[gitConfig.email] 就是 Git 全局的 `user.name` 与 `user.email`。这台 Mac 上的仓库没有自己的身份时，都用它们。

按 <kbd>Return</kbd> 或离开输入框时保存。清空输入框就删掉这项设置。下面一行写着它们存在哪个文件里，通常是 `~/.gitconfig`。

点右边的头像，可以选用 [档案](#use-profile) 或管理档案。

### 签名 {#signing}

这台 Mac 上的仓库没有自己的签名设置时，Git 按这里的设置为提交签名。

| 设置 | 作用 |
|---|---|
| :ui[gitConfig.sshProgram] | 用 SSH 密钥签名的程序。起初用 :ui[gitConfig.sshProgram.system]。装了 1Password 时，也会列出它的签名程序。 |
| :ui[gitConfig.gpgProgram] | 用于 OpenPGP 密钥的 GnuPG 程序。列出这台 Mac 上版本够新的几个。选 :ui[gitConfig.gpgProgram.select] 可以换成别的。 |
| :ui[gitConfig.signingKey] | 用哪把密钥签名：GnuPG 钥匙环里的私钥，或 SSH agent 里加载的密钥。选好密钥后，Git 也就知道该用 OpenPGP 还是 SSH 签名。 |
| :ui[gitConfig.allowedSigners] | 列出你信任哪些 SSH 签名的文件，Git 核对签名时用。可以选 `~/.ssh/allowed_signers`，选别的文件，或者选 :ui[gitConfig.allowedSigners.none]。 |
| :ui[gitConfig.signCommits] | 每个提交都签名 |
| :ui[gitConfig.ensureEmailMatch] | OpenPGP 密钥的邮箱与全局邮箱不同时提示。起初是打开的。 |

有需要留意的问题时，比如签名程序无法运行，设置旁边会出现黄色的警告按钮。点它可以看到问题出在哪里。

签过名的提交与口令的询问，见 [为提交签名](/guide/work/commit/#signing)。

## 仓库设置 {#repository}

每个仓库都有自己的设置。点侧边栏 :ui[workspace.group] 下的 :ui[repositorySettings.title] 就能看到。顶部的按钮在四个部分之间切换。

改动写进这个仓库自己的 Git 设置，与这个仓库的其它操作一起排队执行。仓库没有设置的项，沿用全局的设置。

::screenshot[主窗口里的仓库设置，停在通用分段，有仓库的名称、路径、描述、身份与签名设置。]{name="settings-repository" frame="window" markers="78.4,9.8 60,38.8"}

1. 切换各部分的按钮
2. :ui[bookmarks.detail.identity]

### 通用 {#repository-general}

| 项 | 显示什么 |
|---|---|
| :ui[repositorySettings.name] 与 :ui[repositorySettings.path] | 仓库在哪里 |
| :ui[repositorySettings.localLocation] | 服务器仓库的文件夹在这台 Mac 上的位置。见 [设置位置](/guide/server/local-location/#set)。 |
| :ui[bookmarks.detail.description] | 仓库的描述，[仓库管理窗口](/guide/repositories/manager/) 里也会显示。点 :ui[bookmarks.detail.edit] 修改。 |
| :ui[bookmarks.detail.identity] | 这个仓库提交时用的姓名与邮箱。点头像选用 [档案](#use-profile)，或者点 :ui[bookmarks.detail.edit]，输入只给这个仓库用的姓名与邮箱。 |

:ui[repositorySettings.signing] 一组里的 :ui[repositorySettings.signCommits]、:ui[repositorySettings.signingKey] 与 :ui[repositorySettings.allowedSigners]，作用与 [全局的设置](#signing) 相同，只是只管这个仓库。

### Git LFS、忽略与排除 {#repository-files}

- :ui[repositorySettings.lfs] 显示 Git LFS 的版本与 :ui[repositorySettings.lfs.patterns]。见 [Git LFS](/guide/advanced/lfs/)。
- :ui[repositorySettings.ignores] 列出仓库顶层 `.gitignore` 里的规则。提交这个文件，就能把规则分享给别人。
- :ui[repositorySettings.excludes] 列出 Git 的 `info/exclude` 里的规则。它们只对这一份仓库生效。

想修改规则，点 :ui[repositorySettings.openInEditor]。文件会用这台 Mac 上打开它的默认 App 打开。文件还不存在时，Spooky 先建一个。

:::note[服务器仓库]
这些设置在服务器上读写，只有连着的时候才能修改。:ui[repositorySettings.openInEditor] 打开文件的方式，与工作区打开服务器上的文件相同，见 [终端与其它 App](/guide/server/local-location/#terminal)。
:::

## 相关页面

- [提交改动](/guide/work/commit/)
- [通用、更新与环境](/guide/settings/general/)
- [集成](/guide/settings/integration/)
- [系统要求](/reference/requirements/)
