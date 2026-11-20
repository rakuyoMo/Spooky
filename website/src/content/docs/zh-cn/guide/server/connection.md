---
title: "连接状态与重连"
description: "了解连接状态、密码与口令的询问、断线与重连，以及连不上时仍能看到什么。"
---

服务器仓库离不开它的 SSH 连接。这一页讲怎样看出连没连上、服务器提出的询问是什么意思，以及断线之后会怎样。

## 连接状态 {#status}

在服务器仓库里，每个列表的顶部都有一个横条，写着主机别名与连接状态。工作区、历史、储藏、Reflog、文件历史，以及提交的文件列表里都有。

| 状态 | 意思 |
|---|---|
| :ui[connection.connecting] | Spooky 正在建立连接。 |
| :ui[connection.connected] | 连接正常。 |
| :ui[connection.reconnecting] | 连接断了，Spooky 正在重试。 |
| :ui[connection.unavailable] | 上一次尝试失败了，5 秒后 Spooky 会再试。 |

没连上的时候，横条变成黄色，还会多出几样：

- 一行说明：正在显示上次成功读取的状态，连接恢复前不能写入。
- 原因，比如 :ui[remoteError.unavailable]。点它可以看到 SSH 的原始输出。
- 状态是 :ui[connection.unavailable] 时，还有一个 :ui[action.reconnect] 按钮。

::screenshot[一个断开连接的服务器仓库，工作区顶部的特写。横条写着 “spooky-test: 不可用”，旁边是 “重新连接” 按钮。下面的说明写着正在显示上次成功读取的状态、连接恢复前禁止写入，再下面是折叠起来的 “服务器连接不可用”。]{name="server-unavailable" frame="closeup"}

## 密码与口令的询问 {#prompts}

Spooky 登录服务器时什么都不问。不过服务器上的 Git 有时要你回答，比如经 HTTPS 推送到远端时要密码。Spooky 把询问转到 Mac 上，用对话框问你：

| 对话框 | 什么时候出现 |
|---|---|
| :ui[callback.username.title]、:ui[callback.password.title] | 远端要知道你是谁，经 HTTPS 连接的远端常会这样。 |
| :ui[callback.privateKey.title] | 服务器连远端用的 SSH 密钥设了口令。 |
| :ui[signing.unlock] | 给提交或标签签名时，Git 要服务器上签名密钥的口令。 |
| :ui[callback.editor] | Git 要你编辑一段文字，比如一条说明。 |

对话框的第一行写着是哪台服务器。问私钥口令时，下一行是私钥在服务器上的路径。

问用户名或密码时，勾选 :ui[callback.saveKeychain] 就能把回答存下来。下次这台服务器上的 Git 再问，Spooky 直接用钥匙串里的回答。添加过 GitHub 或 GitLab 账号的话，Spooky 先用账号来回答，见 [托管账号](/guide/hosting/accounts/)。

还有几点：

- 每个对话框等 2 分钟。到时没回答，Git 拿不到答案，命令就会失败。
- 自动获取从不询问。它只用账号与钥匙串里存过的回答，不够用时就取消。
- 服务器上的 Git 要询问口令，服务器的 OpenSSH 要 8.4 或更高版本。

## 断线与重连 {#reconnect}

连接断了，Spooky 会自己重连。每次尝试失败后，状态显示 :ui[connection.unavailable]，过 5 秒再试。连上之后，Spooky 会重新读取整个仓库。

断线之后，你做过的操作不会被重复执行：

- 仓库队列里还在等待的操作会被取消，重连后不会执行。还需要的话，重新发起。
- 断线时正在执行的操作不会重试。重新连上后，Spooky 会核对分支、改动的数量、暂存区锁，以及有没有进行中的合并或变基。

核对的结果显示在 :ui[recovery.title] 对话框里，写着操作到底有没有开始、当前提交有没有变。看过结果，再决定要不要重试。

## 连不上的时候 {#offline}

Spooky 上次读到的内容仍然可以看：各个列表、选中的文件和它的改动。所有会改动仓库的操作都不能用，等连接恢复才行。

打开仓库时连不上服务器，窗口会显示 :ui[missing.unreachable.title]{1="driftwood-server"}，附上 SSH 的输出。点 :ui[action.refresh] 再试一次，或者点 :ui[action.close] 回到仓库管理窗口。

:::tip
在终端里执行 `ssh -o BatchMode=yes driftwood-server git --version`，主机别名换成你自己的。这条命令失败的话，问题出在 Mac 和服务器之间，不在 Spooky，见 [按 Spooky 的方式测试](/guide/server/prepare-ssh/#test)。
:::

## 相关页面

- [准备 SSH](/guide/server/prepare-ssh/)
- [添加服务器仓库](/guide/server/add/)
- [服务器仓库怎样工作](/guide/server/overview/)
