---
title: "添加服务器仓库"
description: "逐项填写 “添加服务器仓库” 对话框，看懂连接体检的结果，在服务器上克隆与扫描仓库。"
---

添加服务器仓库后，它会加进仓库管理的列表并打开。Spooky 会先检查连接，缺了什么，对话框会告诉你该怎么补。

开始之前，先确认终端能连上服务器，而且什么都不问，见 [准备 SSH](/guide/server/prepare-ssh/)。

打开对话框：在 :ui[menu.file] 菜单里选 :ui[action.addRemote]，或者在仓库管理窗口添加按钮的菜单里选它。

## 填写对话框 {#dialog}

::screenshot[添加服务器仓库对话框。主机别名是 spooky-test。仓库路径是 /srv/git/driftwood，旁边有 “浏览” 按钮。挂载到这台 Mac 选的是 “不挂载”。按钮是 “取消” 与 “打开”。]{name="add-server" frame="dialog"}

| 这一项 | 填什么 |
|---|---|
| :ui[remote.host] | `~/.ssh/config` 里 `Host` 那一行的名称，比如 `driftwood-server`。只填别名，不带用户名和端口。还没有别名的话，见 [添加主机别名](/guide/server/prepare-ssh/#alias)。 |
| :ui[remote.path] | 仓库在服务器上的完整路径，以 `/` 开头，比如 `/srv/git/driftwood` |
| :ui[remote.mount] | 可以不选。选了之后，仓库文件夹在这台 Mac 上也能看到，访达就能显示它，见 [添加时挂载](/guide/server/local-location/#when-adding)。 |

不知道路径的话，填好主机别名后点 :ui[clone.browse]。Spooky 会列出服务器上的文件夹，从你填的路径开始，没填时从你在服务器上的个人文件夹开始。Git 仓库标着 :ui[browse.repository]，读不了的文件夹显示成灰色。连按文件夹进入它，再点 :ui[bookmarks.create.choosePrompt]。

也可以选仓库里面的某个文件夹，Spooky 会打开它所在的仓库。

填好主机别名，路径以 `/` 开头，:ui[action.open] 就可以点了。

## 连接体检 {#check}

点 :ui[action.open] 后，对话框底部显示 :ui[remote.checking]，Spooky 依次检查：

1. SSH 能用这个主机别名登录。
2. 服务器上有 Git，版本不低于 2.41.0。
3. 文件夹存在，你能打开、读取它。
4. 文件夹在一个 Git 仓库里，Git 能读出它的状态。

检查期间，各项都不能改。点 :ui[action.cancel] 会停止检查，关闭对话框。

全部通过后，Spooky 在服务器上放好辅助脚本，把仓库加进仓库管理的列表，然后打开它。

## 体检没通过时 {#results}

对话框不关，填过的内容也都留着。底部先写该怎么改，下面是 SSH 或 Git 的原始输出。改好之后，再点一次 :ui[action.open]。

| 出了什么问题 | 怎么办 |
|---|---|
| 主机别名不对 | 只填 `Host` 那一行的别名，不带空格、`@`、`:` 或 `/`。 |
| 不认识服务器的指纹 | 先在终端里连一次，核对指纹，见 [先连一次](/guide/server/prepare-ssh/#fingerprint)。Spooky 从不替你接受指纹。 |
| 服务器的指纹变了 | 先别连。和服务器管理者确认指纹为什么变了。 |
| SSH 登录不上 | 服务器不接受你的密钥，或者 Mac 解不开它，见 [按 Spooky 的方式测试](/guide/server/prepare-ssh/#test)。 |
| 连不上服务器 | 检查主机别名和网络，再试一次。 |
| 找不到 Git | 在服务器上装 Git 2.41.0 或更高版本。已经装了的话，就是 SSH 登录时找不到它。输出里列着服务器用的 `PATH`，在服务器的 shell 启动文件里把 Git 所在的文件夹加进去。 |
| Git 版本太旧 | 把服务器上的 Git 更新到 2.41.0 或更高版本。 |
| 文件夹不存在 | 检查路径。想在那里新建仓库，点 :ui[bookmarks.noRepository.create]。 |
| 没有文件夹的权限 | 你在服务器上的用户要能打开、读取这个文件夹。 |
| 服务器的 macOS 挡住了这个文件夹 | 服务器是一台 Mac，仓库放在 “文稿” 这类受保护的文件夹里。照 [用一台 Mac 当服务器](/guide/server/prepare-ssh/#mac-server) 打开远程用户的完全磁盘访问，或者把仓库挪个地方。 |
| 文件夹不是 Git 仓库 | 选仓库所在的文件夹，或者点 :ui[bookmarks.noRepository.create] 把这个文件夹变成仓库。Git 的输出提到所有者（ownership）时，说明文件夹属于服务器上的另一个用户。 |
| Git 读不出状态 | 下面 Git 的输出写着原因。 |
| 建不起服务器上的会话 | 服务器的 SSH 要允许 Unix socket 转发。服务器上还要有 `/usr/bin/perl`，你要能写入那里的 `~/.spooky/bin` 与 `/tmp`，见 [系统要求](/reference/requirements/#servers)。 |

::screenshot[添加服务器仓库对话框，主机别名是 spooky-test，路径是 /srv/git/driftwood。输入框下面是一条警告，请你确认这个绝对路径在所选的服务器上存在，下面附着原文 “Directory does not exist”。按钮是 “取消” “新建仓库” 与 “打开”。]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] 会在那个文件夹里执行 `git init`，文件夹不存在时先建好它。然后 Spooky 重新检查连接，打开新仓库。

不添加仓库，也能看服务器用的 `PATH` 与 Git：打开 :ui[app.name > settings.title] › :ui[settings.environment]，在底部填上主机别名，点 :ui[settings.environment.server.check]，见 [检查服务器](/guide/settings/general/#server-check)。

## 服务器上的 Git 环境变量 {#environment}

体检之后，Spooky 可能会显示 :ui[remote.environment.title]。这说明服务器的非交互式 shell 设置了名字以 `GIT_` 开头的变量。Spooky 在那里执行的每条 Git 命令，查找仓库与读取设置的方式都会受它们影响。

点 :ui[action.close]，仓库就会打开。之后 Git 在这个仓库里表现异常的话，从服务器的 shell 启动文件里去掉这些变量。

## 在服务器上克隆与查找 {#clone-scan}

还有两种办法把服务器上的仓库加进列表：

- **克隆**：在克隆对话框的 :ui[clone.to] 里选一台服务器。Git 在服务器上克隆仓库，Spooky 把它作为服务器仓库加进列表，见 [克隆仓库](/guide/repositories/manager/#clone)。
- **查找**：在添加按钮的菜单里选 :ui[scan.menu]，在 :ui[scan.in] 里选一台服务器。Spooky 在服务器上的那个文件夹里查找，列出找到的仓库，见 [查找仓库](/guide/repositories/manager/#scan)。

## 相关页面

- [准备 SSH](/guide/server/prepare-ssh/)
- [连接状态与重连](/guide/server/connection/)
- [在这台 Mac 上的位置](/guide/server/local-location/)
