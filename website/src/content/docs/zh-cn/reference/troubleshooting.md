---
title: "常见问题与排查"
description: "排查常见问题：连不上、Git 版本太旧、权限、服务器上的 PATH，以及怎样反馈问题。"
---

下面每个问题先写你会看到什么，再写原因与做法。Spooky 的很多错误还附着 Git 或 SSH 的原始输出，往往直接写明了问题出在哪里。

## 连不上服务器 {#connect}

连接出问题时，会出现在这几个地方之一：

- :ui[remote.form.title] 对话框不关，并写着该怎么改。各种情况见 [体检没通过时](/guide/server/add/#results)。
- 打开服务器仓库时显示 :ui[missing.unreachable.title]{1="driftwood-server"}，见 [连不上的时候](/guide/server/connection/#offline)。
- 已经打开的服务器仓库里，列表顶部的横条变成黄色，并写出原因，见 [连接状态](/guide/server/connection/#status)。

先在 Spooky 之外用同样的方式登录一次。在终端里执行这条命令，主机别名换成你自己的：

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

这条命令失败的话，问题出在 Mac 和服务器之间。各种输出的含义见 [按 Spooky 的方式测试](/guide/server/prepare-ssh/#test)。终端里能通过，Spooky 却还是登录不上的话，可能是 Spooky 用的 SSH agent 与终端不同，见 [SSH agent](/guide/settings/integration/#ssh-agent)。

Spooky 写出的原因能告诉你该往哪里查：

| 原因 | 怎么办 |
|---|---|
| :ui[remoteError.authentication] | 服务器不接受你的密钥，或者 Mac 解不开它。重启 Mac 之后，照 [重启 Mac 之后](/guide/server/prepare-ssh/#after-restart) 重新加载密钥。只能用密码登录的账户用不了。 |
| :ui[remoteError.unknownHostKey] | Mac 还不认识这台服务器。先在终端里连一次，核对指纹，见 [先连一次](/guide/server/prepare-ssh/#fingerprint)。Spooky 从不替你接受指纹。 |
| :ui[remoteError.changedHostKey] | 先别连。和服务器管理者确认指纹为什么变了。 |
| :ui[remoteError.unavailable] | 检查主机别名和网络。每次尝试失败后，Spooky 过 5 秒会再试。想马上重试，点横条里的 :ui[action.reconnect]。见 [断线与重连](/guide/server/connection/#reconnect)。 |
| :ui[remoteError.deployment] | 服务器上缺了 Spooky 需要的东西：Unix socket 转发、`/usr/bin/perl`，或者 `~/.spooky/bin` 与 `/tmp` 的写入权限。见 [服务器](/reference/requirements/#servers)。 |

服务器上的 Git 找不到或者太旧时，接着往下看。

## Git 版本太旧 {#git-version}

Spooky 需要 Git 2.41.0 或更高版本，Mac 上和服务器上都一样。

### 在 Mac 上 {#mac-git}

打开本机仓库时，Spooky 可能显示下面两种错误之一：

- :ui[error.version]，下面附着 Git 的输出。Spooky 用的 Git 程序低于 2.41.0。在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 的 :ui[settings.gitProgram] 旁边换一个新一些的，或者更新 Xcode 或命令行工具。
- :ui[error.gitProgram]，下面附着路径。你选的 Git 程序已经不在了，比如被卸载了。在同一个地方换一个。

菜单里只列出版本够新的 Git 程序，见 [Git 程序](/guide/settings/identity/#git-program)。

### 在服务器上 {#server-git}

连接失败，显示 :ui[remoteError.gitVersion]。把服务器上的 Git 更新到 2.41.0 或更高版本。

服务器上已经装了新版本的话，就是 SSH 登录时先找到了旧的那个。照 [服务器上找不到 Git](#server-path) 里的做法，把新版本 Git 所在的文件夹放到 `PATH` 的最前面。

## 服务器上找不到 Git {#server-path}

连接失败，显示 :ui[remoteError.gitUnavailable]。或者在 :ui[app.name > settings.title] › :ui[settings.environment] 里检查这台服务器时，结果是 :ui[settings.environment.server.noGit]。

服务器上没装 Git 的话，装上 Git 2.41.0 或更高版本。已经装了的话，原因通常在 `PATH`。Spooky 经 SSH 在服务器上执行命令，用的不是交互式 shell。这种 shell 读的启动文件少一些，你在 `~/.zshrc` 或 `~/.bash_profile` 里设置的 `PATH` 可能不起作用。

解决办法：

1. 在终端里登录服务器，执行 `command -v git`。它会印出 Git 在哪里，比如 `/opt/homebrew/bin/git`。
2. 与 Spooky 拿到的 `PATH` 对照一下。错误的输出里列着它，[检查服务器](/guide/settings/general/#server-check) 的结果里也有。
3. 在非交互式 shell 会读的启动文件里，把 Git 所在的文件夹加进 `PATH`。在服务器上执行 `echo $SHELL`，就能看到你用的是哪种 shell。
   - zsh：`~/.zshenv`
   - bash：`~/.bashrc`，写在 “不是交互式 shell 就提前返回” 的那一行之前

   比如：

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. 再点一次 :ui[settings.environment.server.check]，或者执行 [连不上服务器](#connect) 里的测试命令。然后重新连接。

服务器上的 Git LFS，以及钩子调用的程序，也是按同一个 `PATH` 找的。它们在终端里能用、经 Spooky 却不行的话，用同样的办法把它们的文件夹加进去。

## 权限问题 {#permissions}

| 看到什么 | 原因与做法 |
|---|---|
| :ui[remoteError.pathPermission] | 你在服务器上的用户打不开、读不了仓库的文件夹。请服务器管理者给你权限，或者换一个你自己的文件夹。 |
| :ui[remoteError.diskAccess] | 服务器是一台 Mac，仓库放在 “文稿” 这类受 macOS 保护的文件夹里。照 [用一台 Mac 当服务器](/guide/server/prepare-ssh/#mac-server) 打开远程用户的完全磁盘访问，或者把仓库挪个地方。 |
| :ui[error.ownership] | 这台 Mac 上的仓库文件夹属于另一个用户，Git 拒绝在里面工作。把文件夹的所有者改成你自己。信任它的所有者的话，也可以执行 Git 输出里建议的 `git config --global --add safe.directory` 命令。 |
| :ui[error.terminal] | 标题下面的详情写着出了什么问题。常见的是 :ui[settings.terminal] 里选的终端已经卸载了，或者你没有允许 Spooky 控制 Terminal 或 iTerm。见 [终端](/guide/settings/integration/#terminal)。 |
| :ui[appIcon.writeFailed] | Spooky 把图标存进 `Spooky.app`，你的用户要能写入它。在访达里选中 Spooky，选 **文件 › 显示简介**，看看 **共享与权限** 里你是不是 **读与写**。 |

:::note[服务器仓库]
在服务器上，文件夹属于另一个用户时，连接会失败并显示 :ui[remoteError.notWorkingTree]，Git 的输出里提到所有者（ownership）。请服务器管理者处理，或者在服务器上执行 `safe.directory` 那条命令。
:::

## 反馈问题 {#report}

选 :ui[menu.help > help.support]，打开 Spooky 在 GitHub 上的问题列表。先在那里找找有没有同样的问题，没有就新建一个。写清楚你做了什么、想要什么结果、实际发生了什么。Spooky 显示过错误的话，附上它的标题与原始输出。

附一份诊断报告能帮忙看清发生了什么。选 :ui[menu.help > help.diagnosticReport]，再选一个存放位置。Spooky 存下一个文本文件，并在访达里显示它。报告不会被发送到任何地方。分享之前，先打开文件看一遍。报告里有什么，见 [诊断报告](/reference/data-privacy/#diagnostic-reports)。

Spooky 上次意外退出的话，下次启动时会问你：:ui[crash.title]。点 :ui[crash.report] 会在浏览器里打开 GitHub 的新问题页，里面填好了崩溃的摘要。要等你在浏览器里提交，问题才会建出来。见 [崩溃报告](/reference/data-privacy/#crash-reports)。

## 相关页面

- [准备 SSH](/guide/server/prepare-ssh/)
- [连接状态与重连](/guide/server/connection/)
- [系统要求](/reference/requirements/)
- [数据与隐私](/reference/data-privacy/)
