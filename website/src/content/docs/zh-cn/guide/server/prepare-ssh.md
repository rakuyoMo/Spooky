---
title: "准备 SSH"
description: "准备 SSH 密钥与 ~/.ssh/config 里的主机别名，先在终端里连通，再添加服务器仓库。"
---

Spooky 用 SSH 登录服务器，方式和终端一样。它没法替你输入密码，所以要有一把 SSH 密钥。这一页带你准备密钥和服务器的简短名称，再确认终端能连上、而且什么都不问。终端连得上，Spooky 也就连得上。

如果 `ssh` 已经能不输密码登录服务器，直接跳到 [按 Spooky 的方式测试](#test)。

## 需要准备什么 {#before}

- 服务器上一个能用 SSH 登录的账号。拿不准的话，问问服务器的管理者。
- 服务器上装有 Git 2.41.0 或更高版本。
- Mac 上的 **终端** App。

这一页的命令都在终端里执行。输入或粘贴一条，按 Return 键。

## 看看有没有密钥 {#key-check}

SSH 密钥是一对文件。私钥留在 Mac 上，公钥以 `.pub` 结尾，要放到服务器上。

```sh
ls ~/.ssh
```

列表里有 `id_ed25519` 和 `id_ed25519.pub`，说明已经有密钥了，跳到 [添加主机别名](#alias)。别的密钥对也能用，比如 `id_rsa` 和 `id_rsa.pub`，下面的步骤里把 `id_ed25519` 换成它的名字就行。

看到 “No such file or directory”，或者列表里没有成对的密钥，就新建一把。

## 新建密钥 {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

引号里换成你自己的邮箱。它只是个标签，方便你认出这把密钥。

1. 问保存在哪里时，按 Return 键，用它建议的位置。
2. 输入一个口令，再输入一遍。输入时屏幕上什么都不显示。有人复制了密钥文件时，口令能保护它。

完成后，`~/.ssh` 里会有 `id_ed25519` 和 `id_ed25519.pub`。

## 添加主机别名 {#alias}

主机别名是服务器的简短名称。在终端和 Spooky 里都用它，代替服务器的地址和你的用户名。别名写在 `~/.ssh/config` 这个文件里。

1. 用文本编辑打开这个文件。文件还不存在时，这条命令会先建好它：

   ```sh
   touch ~/.ssh/config && open -e ~/.ssh/config
   ```

2. 在文件末尾加上这几行，换成你自己的信息：

   ```
   Host driftwood-server
       HostName 203.0.113.10
       User alex
       IdentityFile ~/.ssh/id_ed25519
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. 保存文件，关掉文本编辑。

| 这一行 | 填什么 |
|---|---|
| `Host` | 别名。用一个词，不带空格、`@`、`:` 或 `/`，也不要以 `-` 开头。 |
| `HostName` | 服务器的地址或名称，比如 `203.0.113.10` 或 `server.example.com` |
| `User` | 你在服务器上的用户名 |
| `IdentityFile` | 上面新建或找到的私钥 |
| `AddKeysToAgent`、`UseKeychain` | 第一次输入口令后，Mac 会把它存进钥匙串，之后 SSH 解锁密钥时不再询问。Spooky 登录时从不询问口令，所以离不开这两行。 |

服务器的 SSH 用的不是 22 端口时，再加一行，比如 `Port 2222`。

## 先连一次 {#fingerprint}

第一次连接一台服务器时，SSH 会请你确认服务器的指纹。Spooky 从不替你接受指纹，所以这一步要先在终端里做。

```sh
ssh driftwood-server
```

1. SSH 显示服务器的指纹，也就是以 `SHA256:` 开头的一串字符，问你要不要继续。
2. 和服务器管理者给你的指纹对一下。在服务器上，这条命令能印出指纹：

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. 对得上，就输入 `yes`，按 Return 键。Mac 会记住这台服务器，以后不再问。

接下来会怎样，要看服务器：

- SSH 问密钥的口令时，输入它。Mac 会把口令存进钥匙串。
- 已经登录进去了，说明密钥已经在服务器上。输入 `exit` 退出，跳到 [按 Spooky 的方式测试](#test)。
- SSH 问你在服务器上的密码时，先按 <kbd>⌃C</kbd> 退出。下一步会把密钥放到服务器上。

:::caution
SSH 警告远程主机的标识变了（remote host identification has changed）时，不要继续。先问服务器管理者，服务器是不是重装或换过了。
:::

## 把公钥放到服务器上 {#copy-key}

服务器能用密码登录的话，这条命令会把公钥复制过去。问密码时，输入你在服务器上的密码。

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

服务器不接受密码登录时，把公钥发给服务器管理者。这条命令会把公钥复制到剪贴板：

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

请对方把它加进你在服务器上的个人文件夹里的 `~/.ssh/authorized_keys`。公钥可以放心给别人。不带 `.pub` 的那个文件，绝不要发出去。

## 按 Spooky 的方式测试 {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

这条命令的登录方式和 Spooky 一样，什么都不问。马上印出 2.41.0 或更高的版本，比如 `git version 2.47.1`，就算成功了。接着就可以 [添加服务器仓库](/guide/server/add/)。

印出别的内容时：

| 看到什么 | 怎么办 |
|---|---|
| `Permission denied` | 服务器还不接受你的密钥，或者 Mac 解不开它。看看 [把公钥放到服务器上](#copy-key) 与 [重启 Mac 之后](#after-restart)。 |
| `Host key verification failed` | Mac 还不认识这台服务器，见 [先连一次](#fingerprint)。 |
| `Could not resolve hostname`、`Connection refused` 或 `Operation timed out` | 检查 `~/.ssh/config` 里的 `HostName` 与 `Port`，确认服务器开着、连得上。 |
| 含有 `command not found` 的提示 | 服务器上没装 Git，或者 SSH 登录时找不到它。问问服务器管理者。 |
| 版本低于 2.41.0 | 请服务器管理者更新 Git。 |

## 重启 Mac 之后 {#after-restart}

测试原来能通过，重启 Mac 后却报 `Permission denied` 的话，重新加载密钥。口令已经存进钥匙串的密钥，用这条命令加载：

```sh
ssh-add --apple-load-keychain
```

## 改用别的 SSH agent {#agent}

SSH agent 替 SSH 保管已经解锁的密钥。Spooky 用的是系统的 agent，也就是 macOS 替你启动的那一个。密钥放在别的 agent 里时，比如密码管理器带的 agent，把 `SSH_AUTH_SOCK` 设成那个 agent 的 socket。可以在 :ui[app.name > settings.title] › :ui[settings.environment] 里把它加成自定义变量，也可以写在登录 shell 里。之后 Spooky 登录服务器就用这个 agent，见 [SSH agent](/guide/settings/integration/#ssh-agent)。

## 用一台 Mac 当服务器 {#mac-server}

另一台 Mac 也可以当服务器。在那台 Mac 上：

1. 选 **苹果菜单 › 系统设置**，点 **通用**，再点 **共享**。
2. 打开 **远程登录**。
3. 仓库放在 “文稿” “桌面” 这类受保护的文件夹里时，点 **远程登录** 旁边的信息按钮，打开 **允许远程用户对磁盘进行完全访问**。

然后回到你自己的 Mac，照这一页做一遍，`HostName` 填那台 Mac 的地址。

## 相关页面

- [服务器仓库怎样工作](/guide/server/overview/)
- [添加服务器仓库](/guide/server/add/)
- [系统要求](/reference/requirements/#servers)
