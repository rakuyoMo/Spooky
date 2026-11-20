---
title: "系统要求"
description: "查看 Spooky 对 macOS、Git 与服务器的要求。"
---

这一页列出 Spooky 对你的 Mac 与要连接的服务器有哪些要求。

## Mac {#mac}

| 项目 | 要求 |
|---|---|
| macOS | macOS 26 或更高版本 |
| Git | Git 2.41.0 或更高版本。Spooky 默认用 `/usr/bin/git`，想换的话，在 :ui[app.name > settings.title] › :ui[settings.gitConfig] 的 :ui[settings.gitProgram] 里选。 |
| SSH | macOS 自带的 SSH。服务器仓库用它来连接。 |

Spooky 用到了 Git 2.41.0 才有的功能，更旧的版本用不了。

## 服务器 {#servers}

服务器可以是一台 Linux 机器，也可以是一台 Mac。Spooky 在那里不需要管理员权限，也不安装常驻服务。

| 项目 | 要求 |
|---|---|
| 登录 | 经 Mac 上 `~/.ssh/config` 里的主机别名，用密钥登录 SSH。只能用密码登录的账号连不上，见 [准备 SSH](/guide/server/prepare-ssh/)。 |
| Git | Git 2.41.0 或更高版本，在非交互 SSH 登录用的 `PATH` 里能找到 |
| SSH 服务 | OpenSSH，打开 SFTP，允许 Unix socket 转发，这两项默认都是打开的。`MaxSessions` 不能少于 10，默认就是 10。 |
| 口令询问 | 服务器上的 Git 要询问 SSH 密钥的口令时，需要 OpenSSH 8.4 或更高版本 |
| Perl | `/usr/bin/perl`，带有标准模块 `IO::Socket::UNIX`、`JSON::PP`、`POSIX` 与 `Fcntl` |
| 文件 | 能写入服务器上个人文件夹里的 `~/.spooky/bin`，以及 `/tmp` |
| 废纸篓 | 可以没有。服务器是 Mac 时，Spooky 用 `/usr/bin/trash`，macOS 15 起自带。Linux 上用 `gio` 或 `trash-put`。都没有的话，Spooky 先确认，再永久删除文件。 |

添加仓库之前，想知道服务器满足不满足，可以跑一遍 [准备 SSH](/guide/server/prepare-ssh/#test) 里的测试，也可以在 :ui[app.name > settings.title] › :ui[settings.environment] 里检查一台服务器。

## 可选 {#optional}

| 想用 | 需要 |
|---|---|
| Git LFS | 仓库所在的机器上装有 Git LFS 2.9.0 或更高版本，在那里 Git 用的 `PATH` 里能找到 |
| sshfs 挂载 | Mac 上装有 sshfs，以及 macFUSE 或 FUSE-T |
| SMB 挂载 | 服务器打开了 SMB 文件共享 |
| Pull Request 与 Merge Request | github.com、GitLab.com 的账号，或 9.0 及更高版本的私有部署 GitLab 的账号 |

## 相关页面

- [安装 Spooky](/guide/start/install/)
- [服务器仓库怎样工作](/guide/server/overview/)
- [数据与隐私](/reference/data-privacy/)
