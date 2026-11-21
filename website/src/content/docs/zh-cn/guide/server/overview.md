---
title: "服务器仓库怎样工作"
description: "了解哪些事在服务器上发生、哪些在本机发生，Spooky 在服务器上放了什么，以及服务器仓库与本机仓库的差别。"
---

服务器仓库是另一台机器上的 Git 仓库，Spooky 经 SSH 打开它。文件留在服务器上，Git 也在那里执行，不用先克隆到 Mac。这一页讲两边各做什么、Spooky 在服务器上留下了什么，以及它和这台 Mac 上的仓库有哪些不同。

想开始用，先看 [准备 SSH](/guide/server/prepare-ssh/)，再看 [添加服务器仓库](/guide/server/add/)。

## 什么在哪里发生 {#where}

Spooky 用 macOS 自带的 SSH 连接服务器。它用的是 `~/.ssh/config` 文件里的主机别名，登录方式和在终端里执行 `ssh` 一样。

在服务器上：

- Git 执行所有命令，用的是服务器自己的 Git 与环境。
- Spooky 经 SFTP 读写文件。SFTP 是 SSH 里传文件的那一部分。
- 删掉的文件和丢弃的新文件，会移进服务器的废纸篓，前提是服务器上有废纸篓。
- 获取、拉取与推送从服务器连到 GitHub 这类远端，用的是服务器的网络和服务器上的 SSH 密钥。

在 Mac 上：

- 你操作的窗口、列表与差异。
- 到服务器的 SSH 连接。每个打开的仓库有一条自己的连接，所有命令都从这条连接走。
- 服务器上的 Git 提出的询问，比如密码或密钥口令，见 [密码与口令的询问](/guide/server/connection/#prompts)。
- 向 GitHub 与 GitLab 发出的请求，比如登录账号、读取 Pull Request。
- 用快速查看或别的 App 打开的文件副本。

:::note
经 SSH 连接的远端，服务器上要已经有它的主机密钥。还没有的话，先登录服务器，在那里连一次这个远端。
:::

## Spooky 在服务器上放了什么 {#on-server}

Spooky 不需要管理员权限，也不安装常驻服务。它在服务器上只留下两样东西：

- **`~/.spooky/bin/` 里的一个辅助脚本**，在你服务器上的个人文件夹里。它负责把 Git 的询问转回 Mac。Spooky 连接时把它放进去，留给以后的连接用。这个文件夹里以 `-askpass`、`-gpg` 等结尾的其它名字，都是指向同一个文件的链接。
- **`/tmp/spooky-*` 里的临时文件**，仓库打开期间才有。关闭仓库时，Spooky 会删掉它们。

辅助脚本用 `/usr/bin/perl` 运行，大多数 macOS 与 Linux 服务器都自带。完整的要求见 [系统要求](/reference/requirements/#servers)。

`~/.spooky` 随时可以删。Spooky 下次连接时会重新放好辅助脚本。

## 服务器仓库有哪些不同 {#differences}

服务器仓库打开后，窗口和这台 Mac 上的仓库一样，大多数视图与命令的用法也相同。从这几处能看出仓库在服务器上：

::screenshot[一个服务器仓库的窗口。标题是 spooky-test:driftwood，下面是当前视图与分支。工具栏上显示主机别名 spooky-test。中间一栏顶部的横条写着 “spooky-test: 已连接”，下面是提交区与改动的文件列表。右边一栏显示所选文件的改动。]{name="hero" frame="window" markers="45.8,3.3 64.4,7.2 40,8.9"}

1. 窗口标题以主机别名开头，比如 `driftwood-server:driftwood`。仓库管理窗口里的名称也这样写。
2. 工具栏上的 :ui[toolbar.host] 一项显示主机别名。
3. 工作区、历史等列表的顶部显示连接状态，见 [连接状态与重连](/guide/server/connection/)。

有些地方用起来不一样：

| 哪里 | 服务器仓库里 |
|---|---|
| 服务器上的改动 | 仓库窗口在最前面时，Spooky 每 2 秒查一次服务器上的变化，其余时候每 10 秒查一次。 |
| 连接断开 | 仍然可以查看 Spooky 上次读到的内容，但重新连上之前不能做任何改动。 |
| :ui[action.revealFinder] | 访达要在 Mac 上有一个能看到服务器文件的文件夹，见 [本机位置](/guide/server/local-location/)。 |
| :ui[action.openTerminal] | 终端用 `ssh` 登录服务器，进入仓库所在的文件夹。 |
| :ui[action.copyPath] | 复制的路径以主机别名开头，比如 `driftwood-server:/srv/git/driftwood`。 |
| 用别的 App 打开文件 | 大多数 App 拿到的是文件副本。保存后，Spooky 把改动写回服务器，见 [终端与其它 App](/guide/server/local-location/#terminal)。 |
| 丢弃或删除文件 | 丢弃改动会覆盖服务器上的文件，Spooky 会先确认。删掉的文件和丢弃的新文件移进服务器的废纸篓。服务器上没有废纸篓时，Spooky 先确认，再永久删除。 |
| :ui[settings.environment] 设置 | 只对这台 Mac 上的 Git 有效。服务器上的 Git 用服务器自己的环境，见 [环境](/guide/settings/general/#environment)。 |

丢弃改动、永久删除与恢复文件前的确认，可以在 :ui[app.name > settings.title] › :ui[settings.general] 里关掉，见 [确认](/guide/settings/general/#confirmations)。

## 相关页面

- [准备 SSH](/guide/server/prepare-ssh/)
- [添加服务器仓库](/guide/server/add/)
- [系统要求](/reference/requirements/)
